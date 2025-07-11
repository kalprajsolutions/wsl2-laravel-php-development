#!/usr/bin/env bash
# Install the PHP helper toolkit into the current user’s HOME.
# Works whether run from a clone *or* piped via curl|sh.

set -euo pipefail

shopt -s expand_aliases

# 1. Install prerequisites and add the PPA
echo "Installing prerequisites and adding Ondřej Surý’s PPA…"
apt update
DEBIAN_FRONTEND=noninteractive apt install -y \
    software-properties-common \
    ca-certificates \
    lsb-release \
    apt-transport-https

add-apt-repository -y ppa:ondrej/php
apt update


### Configuration #############################################################
PKG_DIR="${HOME}/.local/lib/wsl2-php-toolkit"         # where helpers live
RC_FILE="${HOME}/.bashrc"                             # change to ~/.zshrc if needed
RAW_BASE="https://raw.githubusercontent.com/kalprajsolutions/wsl2-laravel-php-development/main"
SOURCE_LINE="source \"${PKG_DIR}/functions.sh\""
###############################################################################

echo "▶ Installing toolkit into ${PKG_DIR}"
mkdir -p "${PKG_DIR}"

echo "⬇  Downloading functions.sh …"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "${RAW_BASE}/functions.sh" -o "${PKG_DIR}/functions.sh"
else
  wget -qO "${PKG_DIR}/functions.sh" "${RAW_BASE}/functions.sh"
fi
chmod 644 "${PKG_DIR}/functions.sh"

# Ensure functions are sourced in every new shell (idempotent)
if ! grep -Fxq "${SOURCE_LINE}" "${RC_FILE}"; then
  echo "${SOURCE_LINE}" >> "${RC_FILE}"
  echo "✓ Added toolkit source line to ${RC_FILE}"
else
  echo "✓ ${RC_FILE} already sources the toolkit"
fi

echo "✓ Installation complete — restart your shell or run:"
echo "   source ${RC_FILE}"
