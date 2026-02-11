#!/bin/bash
#
# totp-vault installer
# Builds from source and installs to /usr/local/bin (or ~/bin if no sudo)
#

set -e

echo "🔐 totp-vault installer"
echo ""

# Check for Swift
if ! command -v swift &> /dev/null; then
    echo "❌ Swift not found. Please install Xcode or Swift toolchain."
    exit 1
fi

# Determine install location
INSTALL_DIR="/usr/local/bin"
if [ ! -w "$INSTALL_DIR" ] && [ ! -w "$(dirname "$INSTALL_DIR")" ]; then
    INSTALL_DIR="$HOME/bin"
    echo "ℹ️  Installing to $INSTALL_DIR (no sudo access)"
    mkdir -p "$INSTALL_DIR"
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📦 Building totp-vault..."
cd "$SCRIPT_DIR"
swift build -c release

echo "📋 Installing to $INSTALL_DIR..."
cp ".build/release/totp-vault" "$INSTALL_DIR/"

# Check if install dir is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo "⚠️  $INSTALL_DIR is not in your PATH"
    echo "   Add this to your ~/.zshrc or ~/.bashrc:"
    echo "   export PATH=\"\$PATH:$INSTALL_DIR\""
fi

echo ""
echo "✅ totp-vault installed successfully!"
echo ""
echo "Usage:"
echo "  totp-vault add <name>      # Add a TOTP secret (human only)"
echo "  totp-vault get <name>      # Get current code (agent safe)"
echo "  totp-vault list            # List stored names"
echo "  totp-vault verify <n> <c>  # Verify a code"
echo ""
echo "Example:"
echo "  totp-vault add my-2fa"
echo "  totp-vault get my-2fa"
