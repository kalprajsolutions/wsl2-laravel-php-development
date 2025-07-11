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

### 5. Done
echo
echo "✓ Installation complete."
echo "  ➜ Restart your shell or run:  source ${RC_FILE}"
echo "  ➜ Then, try:  php-toolkit --help"
