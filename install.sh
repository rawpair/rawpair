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
sudo mv rawpair "$INSTALL_DIR"

echo "✅ Installed: $(which rawpair)"
rawpair --version

# Clean up
rm "$FILENAME"
