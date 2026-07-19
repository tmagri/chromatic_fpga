#!/bin/bash
cd "$(dirname "$0")"
echo "==================================================="
echo "      ModRetro Chromatic Firmware Updater"
echo "==================================================="
echo ""

# 1. Check if openFPGALoader is installed
if ! command -v openFPGALoader &> /dev/null; then
    echo "[INFO] openFPGALoader not found. Attempting automatic installation..."
    
    # Detect macOS (Homebrew)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            echo "Installing via Homebrew..."
            brew install openfpgaloader
        else
            echo "[ERROR] Homebrew is not installed. Please install Homebrew first (https://brew.sh/) or install openFPGALoader manually."
            exit 1
        fi
        
    # Detect Linux (apt, pacman, dnf)
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            echo "Ubuntu/Debian detected. Installing via apt..."
            sudo apt-get update && sudo apt-get install -y openfpgaloader
        elif command -v pacman &> /dev/null; then
            echo "Arch Linux detected. Installing via pacman..."
            sudo pacman -Sy --noconfirm openfpgaloader
        elif command -v dnf &> /dev/null; then
            echo "Fedora detected. Installing via dnf..."
            sudo dnf copr enable -y mobicarte/openFPGALoader
            sudo dnf install -y openFPGALoader
        else
            echo "[ERROR] Unsupported Linux package manager. Please install openFPGALoader manually."
            exit 1
        fi
    else
        echo "[ERROR] Unsupported operating system. Please install openFPGALoader manually."
        exit 1
    fi
    
    # Verify installation succeeded
    if ! command -v openFPGALoader &> /dev/null; then
        echo "[ERROR] Automatic installation failed. Please install openFPGALoader manually."
        exit 1
    fi
    echo "[SUCCESS] openFPGALoader installed successfully!"
    echo ""
fi

echo "IMPORTANT:"
echo "1. Plug your Chromatic into your PC via USB."
echo "2. Ensure the device is powered ON."
read -p "Press [Enter] to continue..."

echo ""
echo "Flashing firmware... Please do not unplug the device."

# 2. Run the flash command
# Note: On Linux, you often need root privileges to talk directly to USB hardware 
# unless specific udev rules are set up. Using sudo ensures it works out of the box.
FLASH_CMD="openFPGALoader --write-flash --cable gwu2x --reset evt1_x2.fs"

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    sudo $FLASH_CMD
else
    $FLASH_CMD
fi

# 3. Check for success
if [ $? -ne 0 ]; then
    echo ""
    echo "[ERROR] Flashing failed!"
    echo "Please check your USB connection, ensure the device is ON, and try again."
else
    echo ""
    echo "[SUCCESS] Firmware updated successfully!"
    echo "The Chromatic is now rebooting with the new logic."
fi