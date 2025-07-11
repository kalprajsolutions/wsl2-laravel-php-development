#!/usr/bin/env bash
# Refactored PHP Toolkit Installer
set -euo pipefail
shopt -s expand_aliases

# Use sudo if not root
SUDO=""
(( EUID != 0 )) && SUDO="sudo"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Global Variables
PKG_DIR="$HOME/.local/lib/php-toolkit"
RC_FILE="$HOME/$([[ "${SHELL##*/}" == "zsh" ]] && echo .zshrc || echo .bashrc)"
RAW_BASE="https://raw.githubusercontent.com/kalprajsolutions/wsl2-laravel-php-development/main"
SOURCE_LINE="source \"${PKG_DIR}/functions.sh\""

function detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO_ID=${ID,,}
        DISTRO_VER=${VERSION_ID%%.*}
    else
        DISTRO_ID="unknown"
        DISTRO_VER=0
    fi

    if grep -qi microsoft /proc/version 2>/dev/null; then
        IS_WSL=true
    else
        IS_WSL=false
    fi

    if [[ "$DISTRO_ID" == "ubuntu" && "$DISTRO_VER" -ge 20 ]]; then
        echo "Detected Ubuntu ${VERSION_ID}${IS_WSL:+ on WSL}, OK to add Ondrej Sury's PPA."
        DO_PPA=true
    else
        echo "Warning: Unsupported OS. Skipping PPA setup."
        DO_PPA=false
    fi
}

function install_prerequisites() {
    echo -e "\n▶ Installing prerequisites…"
    $SUDO apt update
    DEBIAN_FRONTEND=noninteractive $SUDO apt install -y \
        software-properties-common \
        ca-certificates \
        lsb-release \
        apt-transport-https \
        curl \
        wget

    if $DO_PPA; then
        echo "▶ Adding Ondrej Sury’s PPA…"
        $SUDO add-apt-repository -y ppa:ondrej/php
        $SUDO apt update
    fi
}

function install_toolkit() {
    echo -e "\n▶ Installing toolkit into ${PKG_DIR}"
    mkdir -p "$PKG_DIR"

    echo "▶ Downloading functions.sh…"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$RAW_BASE/functions.sh" -o "$PKG_DIR/functions.sh"
    else
        wget -qO "$PKG_DIR/functions.sh" "$RAW_BASE/functions.sh"
    fi
    chmod 644 "$PKG_DIR/functions.sh"
}

function configure_shell_rc() {
    if ! grep -Fxq "$SOURCE_LINE" "$RC_FILE"; then
        echo -e "\n# PHP toolkit helpers" >> "$RC_FILE"
        echo "$SOURCE_LINE" >> "$RC_FILE"
        echo "✓ Added source line to $RC_FILE"
    else
        echo "✓ $RC_FILE already sources the toolkit"
    fi
}

function install_composer() {
    if ! command -v composer &> /dev/null; then
        echo "Composer not found. Installing..."
        EXPECTED_SIG=$(wget -q -O - https://composer.github.io/installer.sig)
        php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
        ACTUAL_SIG=$(php -r "echo hash_file('sha384', 'composer-setup.php');")

        if [[ "$EXPECTED_SIG" != "$ACTUAL_SIG" ]]; then
            echo -e "${RED}ERROR: Invalid Composer installer signature${NC}"
            rm composer-setup.php
            exit 1
        fi

        php composer-setup.php --install-dir=/usr/local/bin --filename=composer
        rm composer-setup.php
        echo "Composer installed."
    else
        echo "Composer already installed."
    fi
}

function install_laravel_installer() {
    echo -e "${GREEN}Installing Laravel Installer...${NC}"
    composer global require laravel/installer

    COMPOSER_BIN_DIR="$(composer global config bin-dir --absolute)"
    if [[ ":$PATH:" != *":$COMPOSER_BIN_DIR:"* ]]; then
        echo -e "${GREEN}Adding Composer bin dir to PATH...${NC}"
        echo "export PATH=\"$COMPOSER_BIN_DIR:\$PATH\"" >> "$RC_FILE"
        export PATH="$COMPOSER_BIN_DIR:$PATH"
        echo "Updated PATH in $RC_FILE"
    else
        echo "Composer bin dir already in PATH."
    fi

    if command -v laravel &> /dev/null; then
        echo -e "${GREEN}Laravel installer installed successfully!${NC}"
        laravel --version
    else
        echo -e "${RED}Laravel command not found. Check PATH settings manually.${NC}"
        exit 1
    fi
}

function validate_php_installed() {
    echo -e "${GREEN}🔍 Checking PHP installation...${NC}"
    if ! command -v php >/dev/null 2>&1; then
        echo -e "${RED}❌ PHP is not installed. Please install PHP first.${NC}"
        exit 1
    fi
}

function main() {
    detect_os
    install_prerequisites
    install_toolkit
    configure_shell_rc
    validate_php_installed
    install_composer
    install_laravel_installer

    echo -e "\n✓ Installation complete."
    echo "  ➜ Restart your shell or run:  source ${RC_FILE}"
    echo "  ➜ Then, try:  php-toolkit --help"
}

main "$@"
