#!/bin/bash

set -e # Exit on error

# Load existing environment variables if available
if [ -f "$HOME/.razon_env" ]; then
    source "$HOME/.razon_env"
fi

# Determine OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Map architecture to our naming convention
case "$ARCH" in
    "x86_64")
        ARCH="amd64"
        ;;
    "aarch64" | "arm64")
        ARCH="arm64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Set installation directory to ~/.razon
INSTALL_DIR="$HOME/.razon"
mkdir -p "$INSTALL_DIR"

BINARY_NAME="razon"
DOWNLOAD_URL="https://github.com/cli-packages/razon-mailer/releases/latest/download/razon-${OS}-${ARCH}"

echo -e "\033[36mInstalling Razon Email Client...\033[0m"
echo "OS: $OS"
echo "Architecture: $ARCH"

# Detect available download tool
if command -v curl &> /dev/null; then
    echo "Downloading using curl..."
    curl -L "$DOWNLOAD_URL" -o "$INSTALL_DIR/$BINARY_NAME"
elif command -v wget &> /dev/null; then
    echo "Downloading using wget..."
    wget -q "$DOWNLOAD_URL" -O "$INSTALL_DIR/$BINARY_NAME"
else
    echo "Error: Neither curl nor wget found. Please install either one."
    exit 1
fi

# Make binary executable
chmod +x "$INSTALL_DIR/$BINARY_NAME"

# Function to get latest Chromium version
get_latest_chromium_version() {
    local api_url="https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions.json"
    local version=""
    
    if command -v curl &> /dev/null; then
        version=$(curl -s "$api_url" | grep -o '"version":"[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null)
    elif command -v wget &> /dev/null; then
        version=$(wget -qO- "$api_url" | grep -o '"version":"[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null)
    fi
    
    # Fallback to known stable version if API fails
    if [ -z "$version" ]; then
        version="121.0.6167.85"
    fi
    
    echo "$version"
}

# Function to get current installed Chromium version
get_installed_chromium_version() {
    if [ -n "$JM_BROWSER_PATH" ] && [ -f "$JM_BROWSER_PATH" ]; then
        # Try to get version from Chrome executable
        local version=$("$JM_BROWSER_PATH" --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
        echo "$version"
    fi
}

# Check if Chromium download is needed
echo -e "\033[36mChecking Chromium browser for email automation...\033[0m"

# Create chromium subdirectory
CHROMIUM_DIR="$INSTALL_DIR/chromium"
mkdir -p "$CHROMIUM_DIR"

# Check if we need to download Chromium
LATEST_VERSION=$(get_latest_chromium_version)
INSTALLED_VERSION=$(get_installed_chromium_version)

if [ -n "$JM_BROWSER_PATH" ] && [ -f "$JM_BROWSER_PATH" ] && [ -n "$INSTALLED_VERSION" ]; then
    echo "Found existing Chromium installation: $JM_BROWSER_PATH"
    echo "Installed version: $INSTALLED_VERSION"
    echo "Latest version: $LATEST_VERSION"
    
    if [ "$INSTALLED_VERSION" = "$LATEST_VERSION" ]; then
        echo -e "\033[32mChromium is already up-to-date! Skipping download.\033[0m"
        SKIP_CHROMIUM_DOWNLOAD=true
    else
        echo -e "\033[33mChromium version mismatch. Updating to latest version...\033[0m"
        SKIP_CHROMIUM_DOWNLOAD=false
    fi
else
    echo -e "\033[36mNo existing Chromium found. Downloading latest version...\033[0m"
    SKIP_CHROMIUM_DOWNLOAD=false
fi

# Function to download and extract Chromium
download_chromium() {
    local platform="$1"
    local version="$2"
    
    local download_url=""
    local extract_cmd=""
    
    echo "Using Chromium version: $version"
    
    case "$platform" in
        "linux-amd64")
            download_url="https://storage.googleapis.com/chrome-for-testing-public/$version/linux64/chrome-linux64.zip"
            extract_cmd="unzip -q"
            ;;
        "linux-arm64")
            # Use ARM64 build if available, fallback to AMD64
            download_url="https://storage.googleapis.com/chrome-for-testing-public/$version/linux64/chrome-linux64.zip"
            extract_cmd="unzip -q"
            ;;
        "darwin-amd64")
            download_url="https://storage.googleapis.com/chrome-for-testing-public/$version/mac-x64/chrome-mac-x64.zip"
            extract_cmd="unzip -q"
            ;;
        "darwin-arm64")
            download_url="https://storage.googleapis.com/chrome-for-testing-public/$version/mac-arm64/chrome-mac-arm64.zip"
            extract_cmd="unzip -q"
            ;;
        *)
            echo "Warning: No Chromium download available for $platform"
            return 1
            ;;
    esac
    
    local chromium_zip="$CHROMIUM_DIR/chromium.zip"
    
    # Download Chromium
    echo "Downloading from: $download_url"
    if command -v curl &> /dev/null; then
        curl -L "$download_url" -o "$chromium_zip"
    elif command -v wget &> /dev/null; then
        wget -q "$download_url" -O "$chromium_zip"
    else
        echo "Warning: Cannot download Chromium - no curl or wget available"
        return 1
    fi
    
    # Extract Chromium
    if command -v unzip &> /dev/null; then
        cd "$CHROMIUM_DIR"
        $extract_cmd "$chromium_zip"
        rm "$chromium_zip"
        
        # Find the Chrome executable and create a symlink
        if [ "$OS" = "darwin" ]; then
            # macOS: Chrome is in .app bundle
            find . -name "Google Chrome for Testing" -type f -executable | head -1 | xargs -I {} ln -sf "{}" "$CHROMIUM_DIR/chrome"
        else
            # Linux: Chrome is a direct executable
            find . -name "chrome" -type f -executable | head -1 | xargs -I {} ln -sf "{}" "$CHROMIUM_DIR/chrome"
        fi
        
        echo -e "\033[32mChromium downloaded successfully!\033[0m"
    else
        echo "Warning: unzip not found - Chromium archive downloaded but not extracted"
        echo "Please manually extract $chromium_zip to $CHROMIUM_DIR"
    fi
}

# Download Chromium for the current platform only if needed
if [ "$SKIP_CHROMIUM_DOWNLOAD" = false ]; then
    download_chromium "${OS}-${ARCH}" "$LATEST_VERSION"
fi

# Set environment variable for Chromium path
CHROMIUM_PATH="$CHROMIUM_DIR/chrome"
if [ -f "$CHROMIUM_PATH" ]; then
    # Update or create the environment file
    if [ ! -f "$HOME/.razon_env" ] || ! grep -q "JM_BROWSER_PATH" "$HOME/.razon_env"; then
        echo "export JM_BROWSER_PATH=\"$CHROMIUM_PATH\"" >> "$HOME/.razon_env"
    else
        # Update existing entry
        sed -i.bak "s|export JM_BROWSER_PATH=.*|export JM_BROWSER_PATH=\"$CHROMIUM_PATH\"|" "$HOME/.razon_env"
    fi
    echo -e "\033[32mChromium path configured: $CHROMIUM_PATH\033[0m"
    echo -e "\033[33mNote: Source ~/.razon_env in your shell profile for persistent browser path\033[0m"
elif [ -n "$JM_BROWSER_PATH" ] && [ -f "$JM_BROWSER_PATH" ]; then
    echo -e "\033[32mUsing existing Chromium installation: $JM_BROWSER_PATH\033[0m"
fi

# Add to PATH if needed
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "Adding $INSTALL_DIR to PATH..."
    if [ -f "$HOME/.zshrc" ]; then
        echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$HOME/.zshrc"
        echo "Please run: source ~/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$HOME/.bashrc"
        echo "Please run: source ~/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
        echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$HOME/.bash_profile"
        echo "Please run: source ~/.bash_profile"
    fi
fi

# Verify installation
if command -v razon &> /dev/null; then
    echo -e "\033[32mInstallation successful!\033[0m"
    echo -e "\033[32mYou can now use 'razon' from any terminal\033[0m"
    echo -e "\033[33mExample: razon send\033[0m"
    echo -e "\033[33mExample: razon init\033[0m"
else
    echo -e "\033[33mBinary installed to: $INSTALL_DIR/$BINARY_NAME\033[0m"
    echo -e "\033[33mPlease restart your terminal or refresh your PATH\033[0m"
fi