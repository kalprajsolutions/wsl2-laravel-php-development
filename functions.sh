# php-toolkit/functions.sh
# shellcheck shell=bash

# Detect if running under WSL
IS_WSL=false
if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
  IS_WSL=true
fi

# Choose service manager: systemctl when available and not WSL, else service
if command -v systemctl &>/dev/null && [[ "$IS_WSL" == false ]]; then
  SVC="systemctl"
else
  SVC="service"
fi

phpinstall() {
    local ver=$1

    # Install PHP and common extensions
    sudo apt update
    sudo apt install -y php${ver} php${ver}-{bcmath,bz2,redis,cgi,cli,common,curl,dba,dev,enchant,fpm,gd,gmp,imap,interbase,intl,ldap,mbstring,mysql,odbc,opcache,pgsql,phpdbg,pspell,readline,snmp,soap,sqlite3,sybase,tidy,xml,xsl,zip}

    # Enable/start FPM
    sudo $SVC enable php${ver}-fpm || true
    sudo $SVC start  php${ver}-fpm || true

    echo "PHP ${ver} installed, and FPM started using $SVC."

    # Configure CLI php.ini
    local cli_ini="/etc/php/${ver}/cli/php.ini"
    sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" "$cli_ini"
    sudo sed -i "s/display_errors = .*/display_errors = On/" "$cli_ini"
    sudo sed -i "s/memory_limit = .*/memory_limit = 512M/" "$cli_ini"
    sudo sed -i "s@;date.timezone =.*@date.timezone = UTC@" "$cli_ini"

    # Configure FPM php.ini
    local fpm_ini="/etc/php/${ver}/fpm/php.ini"
    sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" "$fpm_ini"
    sudo sed -i "s/display_errors = .*/display_errors = On/" "$fpm_ini"
    sudo sed -i "s@;cgi.fix_pathinfo=1@cgi.fix_pathinfo=0@" "$fpm_ini"
    sudo sed -i "s/memory_limit = .*/memory_limit = 512M/" "$fpm_ini"
    sudo sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" "$fpm_ini"
    sudo sed -i "s/post_max_size = .*/post_max_size = 100M/" "$fpm_ini"
    sudo sed -i "s@;date.timezone =.*@date.timezone = UTC@" "$fpm_ini"

    # CA‑bundle section (idempotent)
    sudo bash -c "grep -q '\[openssl\]' $fpm_ini || printf '\n[openssl]\nopenssl.cainfo = /etc/ssl/certs/ca-certificates.crt\n' >> $fpm_ini"
    sudo bash -c "grep -q '\[curl\]'   $fpm_ini || printf '\n[curl]\ncurl.cainfo = /etc/ssl/certs/ca-certificates.crt\n' >> $fpm_ini"

    # Configure Xdebug
    local xdebug_ini="/etc/php/${ver}/mods-available/xdebug.ini"
    if [[ -f "$xdebug_ini" ]]; then
        sudo bash -c "cat >> $xdebug_ini <<EOL
xdebug.mode = debug
xdebug.discover_client_host = true
xdebug.client_port = 9003
xdebug.max_nesting_level = 512
EOL"
    fi

    # Tweak Opcache
    local opcache_ini="/etc/php/${ver}/mods-available/opcache.ini"
    if [[ -f "$opcache_ini" ]]; then
        sudo bash -c "grep -q 'opcache.revalidate_freq' $opcache_ini || echo 'opcache.revalidate_freq = 0' >> $opcache_ini"
    fi

    # Ensure PHP‑FPM pool runs as the current user
    local pool_conf="/etc/php/${ver}/fpm/pool.d/www.conf"
    local current_user; current_user=$(id -un)
    local current_group; current_group=$(id -gn)
    # sudo sed -i "s/^user = .*/user = $current_user/" "$pool_conf"
    # sudo sed -i "s/^group = .*/group = $current_group/" "$pool_conf"

    # Restart FPM
    sudo $SVC restart php${ver}-fpm || true
    echo "PHP ${ver} CLI and FPM configured for development under $current_user:$current_group."
}

phpswitch() {
    local ver=$1
    sudo $SVC enable php${ver}-fpm || true
    sudo $SVC start  php${ver}-fpm || true
    sudo update-alternatives --set php /usr/bin/php${ver}

    # Update default socket symlink
    if [[ "$IS_WSL" == false ]]; then
        sudo ln -sfn /run/php/php${ver}-fpm.sock /run/php/php-fpm.sock
    fi

    sudo $SVC reload php${ver}-fpm nginx || { sudo nginx -s reload || true; }
    echo "PHP switched to ${ver} via $SVC."
}

### Tear‑down a dev v‑host
unserve() {
  local domain="${1:-$(basename "$PWD").test}"
  sudo rm -f /etc/nginx/sites-enabled/$domain
  sudo rm -f /etc/nginx/sites-available/$domain
  sudo nginx -s reload || true
  echo "🗑️  Removed $domain"

  if [[ "$IS_WSL" == false ]]; then
      # Remove domain from /etc/hosts if present
    if grep -q "127.0.0.1\s\+$domain" /etc/hosts; then
      sudo sed -i.bak "/127.0.0.1\s\+$domain/d" /etc/hosts
      echo "➖ Removed $domain from /etc/hosts"
    else
      echo "ℹ️  $domain was not present in /etc/hosts"
    fi
  fi

}

fix_laravel_permissions() {
  local dir="${1:-$PWD}"
  local user="${SUDO_USER:-$USER}"

  echo "🔧 Fixing Laravel permissions in: $dir"

  # Ensure group access for www-data
  sudo usermod -aG www-data "$user"
  sudo chown -R "$user":www-data "$dir"

  # Set correct directory permissions (2755 or 2775 with setgid)
  sudo find "$dir" -type d -exec chmod 2775 {} \;

  # Set correct file permissions
  sudo find "$dir" -type f -exec chmod 664 {} \;

  # Laravel-specific: make sure storage and cache dirs are writable
  for target in "$dir/storage" "$dir/bootstrap/cache"; do
    if [[ -d "$target" ]]; then
      echo "⚙️  Setting write permissions on $target"
      sudo chown -R "$user":www-data "$target"
      sudo chmod -R ug+rwX "$target"
      sudo find "$target" -type d -exec chmod g+s {} \;
    fi
  done

  # Ensure Nginx can traverse the full path (execute permissions)
  local path="$dir"
  while [[ "$path" != "/" ]]; do
    sudo chmod o+x "$path"
    path=$(dirname "$path")
  done

  echo "✅ Permissions fixed for Laravel project in $dir"
}

### On‑the‑fly Nginx site creator
serve() {
  local domain="${1:-$(basename "$PWD").test}"
  local root="$PWD/public"
  local phpver; phpver=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')

  sudo tee /etc/nginx/sites-available/$domain >/dev/null <<EOF
server {
    listen 80;
    server_name .$domain;
    root "$root";

    index index.php index.html;
    client_max_body_size 100M;

    location ~* \.(jpg|jpeg|png|gif|ico|css|pdf|txt|tar|woff|woff2|ttf|svg|eot|otf|mp4|webm|ogg)\$ {
        expires off;
        add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${phpver}-fpm.sock;
    }

    location ~ /\.ht { deny all; }
    gzip off;
    add_header X-Dev-Environment "Laravel Dev Server";
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
}
EOF

  if [[ "$IS_WSL" == false ]]; then
    fix_laravel_permissions
  fi

  # now enable & reload
  sudo ln -sf /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/$domain
  sudo nginx -s reload || true
  echo "🌐 http://$domain ⇢ $root"

  if [[ "$IS_WSL" == false ]]; then
    # add to hosts if needed
    if ! grep -q "127.0.0.1\s\+$domain" /etc/hosts; then
      echo "127.0.0.1 $domain" | sudo tee -a /etc/hosts >/dev/null
      echo "➕ Added $domain to /etc/hosts"
    else
      echo "✅ $domain already in /etc/hosts"
    fi
  fi
}
