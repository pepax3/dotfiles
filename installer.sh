#!/bin/bash

# Install packages using pacman
sudo pacman -S xorg-server xorg-xinit libx11 libxinerama libxft webkit2gtk git flameshot feh xorg-xrandr dunst noto-fonts-emoji

# Move to dwm directory and install
cd dwm 
sudo make clean install

# Move to dmenu directory and install
cd ../dmenu
sudo make clean install

# Move to st directory and install
cd ../st
sudo make clean install

# Move to slstatus directory and install
cd ../slstatus
sudo make clean install

# Move back to home directory
cd ../

# Create directory for dunst configuration if it doesn't exist
mkdir -p ~/.config/dunst

# Move dunstrc to dunst configuration directory
mv dunstrc ~/.config/dunst

# Move .xinitrc to home directory
mv .xinitrc ~/

# Move to /opt directory
cd /opt

# Clone yay-git repository
sudo git clone https://aur.archlinux.org/yay-git.git

# Change ownership of yay-git directory
sudo chown -R $USER:$USER ./yay-git

# Move to yay-git directory
cd yay-git 

# Build and install yay-git package
makepkg -si

# Update yay packages
yay -Sy

# Install additional packages using yay
yay -S ttf-iosevka ttf-iosevka-term discord betterdiscord-installer brave-bin spotify sptlrx

# Move back to dwm-berserk-rice directory
cd ~/dwm-berserk-rice

# Create directory for BetterDiscord themes if it doesn't exist
mkdir -p ~/.config/BetterDiscord/themes

# Move gruvbox.theme.css to BetterDiscord themes directory
mv gruvbox.theme.css ~/.config/BetterDiscord/themes

# Move back to Downloads directory
cd ~/Downloads

# Download and execute BlackArch strap.sh script
curl -O https://blackarch.org/strap.sh
chmod +x strap.sh
sudo ./strap.sh

# End of script
