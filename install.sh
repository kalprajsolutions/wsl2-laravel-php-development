#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

PKG_DIR="${HOME}/.local/lib/php-toolkit"
RC_FILE="${HOME}/.bashrc"          # change to ~/.zshrc for Z‑shell users
SOURCE_LINE="source \"${PKG_DIR}/functions.sh\""

echo "▶ Installing PHP‑toolkit into ${PKG_DIR}"

# 1. create target dir, copy scripts there
mkdir -p "${PKG_DIR}"
cp "$(dirname "$0")/functions.sh" "${PKG_DIR}/functions.sh"

# 2. add 'source' line to rc‑file (only if absent)
if ! grep -Fxq "${SOURCE_LINE}" "${RC_FILE}"; then
    echo "${SOURCE_LINE}" >> "${RC_FILE}"
    echo "✓ Added toolkit source line to ${RC_FILE}"
else
    echo "✓ ${RC_FILE} already sources the toolkit"
fi

echo "✓ Installation complete.  Restart your shell or run:"
echo "   source ${RC_FILE}"
