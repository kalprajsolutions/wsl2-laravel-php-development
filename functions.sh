# php‑toolkit/functions.sh
# shellcheck shell=bash

phpinstall () {
    local ver=$1

    # Install PHP and common extensions
    sudo apt update
    sudo apt install php${ver} php${ver}-{bcmath,bz2,redis,cgi,cli,common,curl,dba,dev,enchant,fpm,gd,gmp,imap,interbase,intl,ldap,mbstring,mysql,odbc,opcache,pgsql,phpdbg,pspell,readline,snmp,soap,sqlite3,sybase,tidy,xml,xsl,zip} -y

    # Enable and start PHP-FPM
    sudo systemctl enable --now php${ver}-fpm

    echo "PHP ${ver} installed and PHP-FPM started."

    # Configure CLI php.ini
    cli_ini="/etc/php/${ver}/cli/php.ini"
    sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" $cli_ini
    sudo sed -i "s/display_errors = .*/display_errors = On/" $cli_ini
    sudo sed -i "s/memory_limit = .*/memory_limit = 512M/" $cli_ini
    sudo sed -i "s@;date.timezone =.*@date.timezone = UTC@" $cli_ini

    # Configure FPM php.ini
    fpm_ini="/etc/php/${ver}/fpm/php.ini"
    sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" $fpm_ini
    sudo sed -i "s/display_errors = .*/display_errors = On/" $fpm_ini
    sudo sed -i "s@;cgi.fix_pathinfo=1@cgi.fix_pathinfo=0@" $fpm_ini
    sudo sed -i "s/memory_limit = .*/memory_limit = 512M/" $fpm_ini
    sudo sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" $fpm_ini
    sudo sed -i "s/post_max_size = .*/post_max_size = 100M/" $fpm_ini
    sudo sed -i "s@;date.timezone =.*@date.timezone = UTC@" $fpm_ini

    # Configure Xdebug (if installed)
    xdebug_ini="/etc/php/${ver}/mods-available/xdebug.ini"
    if [ -f "$xdebug_ini" ]; then
        sudo bash -c "cat >> $xdebug_ini" <<EOL
xdebug.mode = debug
xdebug.discover_client_host = true
xdebug.client_port = 9003
xdebug.max_nesting_level = 512
EOL
    fi

    # Tweak Opcache
    opcache_ini="/etc/php/${ver}/mods-available/opcache.ini"
    if [ -f "$opcache_ini" ]; then
        echo "opcache.revalidate_freq = 0" | sudo tee -a $opcache_ini > /dev/null
    fi

    # Restart FPM to apply changes
    sudo systemctl restart php${ver}-fpm

    echo "PHP ${ver} CLI and FPM configured for development."
}

phpswitch () {
    local ver=$1
    sudo systemctl enable --now php${ver}-fpm
    sudo update-alternatives --set php /usr/bin/php${ver}
    sudo ln -sfn /run/php/php${ver}-fpm.sock /run/php/php-fpm.sock
    sudo systemctl reload php${ver}-fpm nginx
    echo "PHP switched to ${ver}"
}

###  Tear‑down a dev v‑host  ###
unserve () {
  # default to "<folder>.test" if no arg
  local domain="${1:-$(basename "$PWD").test}"

  # 1. Remove Nginx files (both the live symlink and the source)
  sudo rm -f /etc/nginx/sites-enabled/$domain
  sudo rm -f /etc/nginx/sites-available/$domain

  # 2. Reload Nginx gracefully
  sudo nginx -s reload
  
  echo "🗑️  Removed $domain"
}

###  On‑the‑fly Nginx site creator  ###
serve () {
  # domain defaults to "<folder>.test"
  local domain="${1:-$(basename "$PWD").test}"
  local root="$PWD/public"
  local phpver=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')

  sudo tee /etc/nginx/sites-available/$domain >/dev/null <<EOF
server {
    listen 80;
    server_name .$domain;
    root $root;

    index index.php index.html;

    client_max_body_size 100M;

    # No caching for development
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|txt|tar|woff|woff2|ttf|svg|eot|otf|mp4|webm|ogg)$ {
        expires off;
        add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${phpver}-fpm.sock;
    }

    location ~ /\.ht { deny all; }

    # Gzip (optional for local dev)
    gzip off;

    # Optional headers for local dev
    add_header X-Dev-Environment "Laravel Dev Server";
}
EOF

  sudo ln -sf /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/$domain
  sudo nginx -s reload

  echo "🌐 http://$domain ⇢ $root"
}

# add more helpers below …
