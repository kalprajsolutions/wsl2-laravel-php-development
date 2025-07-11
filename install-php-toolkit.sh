#!/usr/bin/env bash
# install-php-toolkit.sh
# Ubuntu/WSL (20.04+) PHP helper toolkit installer

set -euo pipefail
shopt -s expand_aliases

### Helper: run apt commands with sudo if needed
if (( EUID != 0 )); then
  SUDO='sudo'
else
  SUDO=''
fi

### 1. Detect OS, release, and WSL
# Load /etc/os-release if present
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  DISTRO_ID=${ID,,}
  DISTRO_VER=${VERSION_ID%%.*}
else
  DISTRO_ID="unknown"
  DISTRO_VER=0
fi

# Check for WSL
if grep -qi microsoft /proc/version 2>/dev/null; then
  IS_WSL=true
else
  IS_WSL=false
fi

# Only Ubuntu 20.04+ (including WSL Ubuntu) is supported for the PPA approach
if [[ "$DISTRO_ID" == "ubuntu" && "$DISTRO_VER" -ge 20 ]]; then
  echo "Detected Ubuntu ${VERSION_ID}${IS_WSL:+ on WSL}, OK to add Ondřej Surý’s PPA."
  DO_PPA=true
else
  echo "Warning: Detected ${PRETTY_NAME:-$DISTRO_ID $VERSION_ID}, PPA step will be skipped."
  DO_PPA=false
fi

### 2. Install prerequisites and add the PPA (if supported)
echo
echo "▶ Installing prerequisites…"
$SUDO apt update
DEBIAN_FRONTEND=noninteractive $SUDO apt install -y \
    software-properties-common \
    ca-certificates \
    lsb-release \
    apt-transport-https \
    curl \
    wget

if $DO_PPA; then
  echo "▶ Adding Ondřej Surý’s PPA…"
  $SUDO add-apt-repository -y ppa:ondrej/php
  $SUDO apt update
fi

### 3. Configuration
PKG_DIR="${HOME}/.local/lib/php-toolkit"
# auto‑detect your login shell RC file
RC_FILE="$HOME/$([[ "${SHELL##*/}" == "zsh" ]] && echo .zshrc || echo .bashrc)"
RAW_BASE="https://raw.githubusercontent.com/kalprajsolutions/wsl2-laravel-php-development/main"
SOURCE_LINE="source \"${PKG_DIR}/functions.sh\""

echo
echo "▶ Installing toolkit into ${PKG_DIR}"
mkdir -p "${PKG_DIR}"

echo "▶ Downloading functions.sh…"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "${RAW_BASE}/functions.sh" -o "${PKG_DIR}/functions.sh"
else
  wget -qO "${PKG_DIR}/functions.sh" "${RAW_BASE}/functions.sh"
fi
chmod 644 "${PKG_DIR}/functions.sh"

### 4. Ensure your RC file sources it
if ! grep -Fxq "${SOURCE_LINE}" "${RC_FILE}"; then
  echo >> "${RC_FILE}"
  echo "# PHP toolkit helpers" >> "${RC_FILE}"
  echo "${SOURCE_LINE}" >> "${RC_FILE}"
  echo "✓ Added source line to ${RC_FILE}"
else
  echo "✓ ${RC_FILE} already sources the toolkit"
fi

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔍 Checking PHP installation...${NC}"
if ! command -v php >/dev/null 2>&1; then
    echo "❌ PHP is not installed. Please install PHP first."
    exit 1
fi

echo -e "${GREEN}Installing Laravel Installer...${NC}"

# Step 1: Ensure Composer is installed
if ! command -v composer &> /dev/null; then
    echo "Composer is not installed. Installing Composer..."
    EXPECTED_SIGNATURE=$(wget -q -O - https://composer.github.io/installer.sig)
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    ACTUAL_SIGNATURE=$(php -r "echo hash_file('sha384', 'composer-setup.php');")

    if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then
        >&2 echo 'ERROR: Invalid Composer installer signature'
        rm composer-setup.php
        exit 1
    fi

    php composer-setup.php --install-dir=/usr/local/bin --filename=composer
    rm composer-setup.php
else
    echo "Composer already installed."
fi

# Step 2: Install Laravel installer globally
composer global require laravel/installer

# Step 3: Add Composer global bin to PATH
COMPOSER_BIN_DIR="$(composer global config bin-dir --absolute)"

if [[ ":$PATH:" != *":$COMPOSER_BIN_DIR:"* ]]; then
    echo -e "${GREEN}Adding Composer bin dir to PATH...${NC}"

    SHELL_RC=""
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        SHELL_RC="$HOME/.bashrc"
    else
        SHELL_RC="$HOME/.profile"
    fi

    echo "export PATH=\"$COMPOSER_BIN_DIR:\$PATH\"" >> "$SHELL_RC"
    export PATH="$COMPOSER_BIN_DIR:$PATH"
    echo "Updated PATH in $SHELL_RC"
else
    echo "Composer bin dir already in PATH."
fi

# Step 4: Verify Laravel is installed
if command -v laravel &> /dev/null; then
    echo -e "${GREEN}Laravel installer installed successfully!${NC}"
    laravel --version
else
    echo -e "${RED}Laravel command not found. Check PATH settings manually.${NC}"
    exit 1
fi

### 5. Done
echo
echo "✓ Installation complete."
echo "  ➜ Restart your shell or run:  source ${RC_FILE}"
echo "  ➜ Then, try:  php-toolkit --help"
