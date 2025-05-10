# php‑toolkit/functions.sh
# shellcheck shell=bash

phpinstall () {
    local ver=$1
    sudo apt install php${ver} php${ver}-{bcmath,bz2,redis,cgi,cli,common,curl,dba,dev,enchant,fpm,gd,gmp,imap,interbase,intl,ldap,mbstring,mysql,odbc,opcache,pgsql,phpdbg,pspell,readline,snmp,soap,sqlite3,sybase,tidy,xml,xsl,zip} -y
    sudo systemctl enable --now php${ver}-fpm
    echo "PHP installed to ${ver}"
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

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${phpver}-fpm.sock;
    }

    location ~ /\.ht { deny all; }
}
EOF

  sudo ln -sf /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/$domain
  sudo nginx -s reload

  echo "🌐 http://$domain ⇢ $root"
}

# add more helpers below …
