#!/usr/bin/env bash
set -e

REPO="rawpair/rawpair"
VERSION="latest"
INSTALL_DIR="/usr/local/bin"

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Linux)   os="linux" ;;
    Darwin)  os="darwin" ;;
    *) echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

case "$ARCH" in
    x86_64)   arch="amd64" ;;
    arm64)    arch="arm64" ;;
    aarch64)  arch="arm64" ;;
    riscv64)  arch="riscv64" ;;
    *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Get latest version tag if not pinned
if [ "$VERSION" = "latest" ]; then
    VERSION=$(curl -sSfL "https://api.github.com/repos/$REPO/releases/latest" | grep -oP '"tag_name": "\K(.*)(?=")')
fi


# Construct binary name and URL
FILENAME="rawpair_${VERSION#v}_${os}_${arch}.tar.gz"
URL="https://github.com/${REPO}/releases/download/${VERSION}/${FILENAME}"

echo "⬇️  Downloading RawPair ${VERSION} for ${os}/${arch} ${URL}..."
curl -sSfL "$URL" -o "$FILENAME"

echo "📦 Extracting..."
tar -xzf "$FILENAME"
chmod +x rawpair

echo "🚀 Installing to $INSTALL_DIR..."

if [ "$(id -u)" -eq 0 ]; then
    # Already root
    mv rawpair "$INSTALL_DIR"
elif command -v sudo >/dev/null 2>&1; then
    sudo mv rawpair "$INSTALL_DIR"
else
    echo "⚠️  Neither root nor sudo detected. Installing to \$HOME/.local/bin..."
    mkdir -p "$HOME/.local/bin"
    mv rawpair "$HOME/.local/bin"

    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo "⚠️  \$HOME/.local/bin is not in your PATH. You may want to add:"
        echo '  export PATH="$HOME/.local/bin:$PATH"'
    fi
fi

if ! command -v rawpair >/dev/null; then
    echo "❌ Installation failed or rawpair not in PATH"
    exit 1
fi

echo "✅ Installed: $(which rawpair)"
rawpair --version

# Clean up
rm "$FILENAME"
