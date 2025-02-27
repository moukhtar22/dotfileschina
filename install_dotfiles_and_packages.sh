#!/bin/bash

# ================================
# Combined Installation Script for DotfilesChina + Packages
# Repository: https://github.com/moukhtar22/dotfileschina
# Author: Moukhtar Morsy
# ================================

# Exit on error
set -e

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to print messages
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root. Use sudo."
fi

# Update the system
print_message "Updating the system..."
pacman -Syu --noconfirm || print_error "Failed to update the system."

# Install Yay (AUR helper) if not already installed
if ! command -v yay &> /dev/null; then
    print_message "Installing Yay (AUR helper)..."
    pacman -S --needed --noconfirm git base-devel || print_error "Failed to install essential tools."
    git clone https://aur.archlinux.org/yay.git 
    
    makepkg -si --noconfirm || print_error "Failed to install Yay."
    cd - || print_error "Failed to return to original directory."
else
    print_warning "Yay is already installed. Skipping."
fi

# Define package lists
PACMAN_PACKAGES=(
    ananicy-cpp nftables iptables-nft firejail pass brightnessctl playerctl nm-connection-editor bluez-utils pipewire
    pipewire-alsa pipewire-audio pipewire-jack pipewire-pulse pipewire-zeroconf wireplumber pwvucontrol gnome-disk-utility
    gpart otf-apple-fonts ttf-apple-emoji noto-fonts-cjk ntfs-3g tectonic tree-sitter tree-sitter-cli zathura zathura-pdf-mupdf
    telegram-desktop nicotine+ audacity gimp-devel mpv termusic microsoft-edge-stable-bin librewolf-bin zen-browser-bin
    firefox-tridactyl-native intel-gpu-tools intel-media-driver intel-ucode vulkan-intel libva-utils vdpauinfo vulkan-tools
    clinfo btop htop-vim iotop-c fastfetch duf progress s-tui perl-image-exiftool zsh yt-dlp starship reflector quarto-cli-bin
    pandoc-bin less gum graphviz gocryptfs eza git git-crypt git-delta topgrade ttyper rsync rm-improved glow prettyping bob
    cht.sh-git bat yazi ffmpeg ffmpegthumbnailer p7zip jq poppler fd ripgrep ripgrep-all fzf zoxide imagemagick mmv-c-git
    ripdrag rclone bc carapace-bin impala bluetui fcitx5 fcitx5-chinese-addons fcitx5-material-color ttf-noto-cjk
    ttf-wqy-microhei ttf-wqy-zenhei i3-gaps polybar rofi alacritty neovim pamixer scrot maim xclip feh dunst playerctl
)

AUR_PACKAGES=(
    lunacy-bin
)

# Install Pacman packages
print_message "Installing Pacman packages..."
pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}" || print_error "Failed to install Pacman packages."

# Install AUR packages
if [[ ${#AUR_PACKAGES[@]} -gt 0 ]]; then
    print_message "Installing AUR packages..."
    yay -S --needed --noconfirm "${AUR_PACKAGES[@]}" || print_error "Failed to install AUR packages."
else
    print_warning "No AUR packages to install. Skipping."
fi

# Clone the dotfileschina repository
REPO_URL="https://github.com/moukhtar22/dotfileschina.git"
INSTALL_DIR="$HOME/dotfileschina"

if [[ -d "$INSTALL_DIR" ]]; then
    print_warning "Directory $INSTALL_DIR already exists. Skipping clone."
else
    print_message "Cloning repository from $REPO_URL..."
    git clone "$REPO_URL" "$INSTALL_DIR" || print_error "Failed to clone the repository."
fi

# Copy configuration files
print_message "Copying configuration files..."
CONFIG_DIR="$HOME/.config"
mkdir -p "$CONFIG_DIR"

cp -r "$INSTALL_DIR/config/i3" "$CONFIG_DIR/" || print_error "Failed to copy i3 config."
cp -r "$INSTALL_DIR/config/polybar" "$CONFIG_DIR/" || print_error "Failed to copy Polybar config."
cp -r "$INSTALL_DIR/config/alacritty" "$CONFIG_DIR/" || print_error "Failed to copy Alacritty config."
cp -r "$INSTALL_DIR/config/nvim" "$CONFIG_DIR/" || print_error "Failed to copy Neovim config."
cp -r "$INSTALL_DIR/config/rofi" "$CONFIG_DIR/" || print_error "Failed to copy Rofi config."

cp "$INSTALL_DIR/.zshrc" "$HOME/" || print_error "Failed to copy .zshrc."
cp "$INSTALL_DIR/.xinitrc" "$HOME/" || print_error "Failed to copy .xinitrc."

# Set Zsh as the default shell
print_message "Setting Zsh as the default shell..."
chsh -s /bin/zsh || print_warning "Failed to set Zsh as the default shell."

# Install Oh My Zsh (optional)
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    print_message "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    print_warning "Oh My Zsh is already installed. Skipping."
fi

# Configure Fcitx5 for Chinese input
print_message "Configuring Fcitx5 for Chinese input..."
echo "export GTK_IM_MODULE=fcitx" >> "$HOME/.xprofile"
echo "export QT_IM_MODULE=fcitx" >> "$HOME/.xprofile"
echo "export XMODIFIERS=@im=fcitx" >> "$HOME/.xprofile"

# Post-installation message
print_message "Installation completed successfully!"
print_message "You can now start i3 by running 'startx'."
