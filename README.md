Dotfiles Installation Guide
This guide outlines the simple steps to install your dotfiles from a GitHub repository. Dotfiles are configuration files that personalize your system and applications.

Prerequisites
Before proceeding, ensure you have the following installed on your system:

Git: Version control system for tracking changes to your dotfiles.
Installation Steps
Install Git: If Git is not already installed on your system, you can do so using your package manager. For example, on systems using Pacman package manager:

```bash
sudo pacman -S git
```
Clone Dotfiles Repository: Clone your dotfiles repository from GitHub. Replace <repository-url> with the URL of your dotfiles repository.

```bash
git clone https://github.com/pepax3/dotfiles
```
Navigate to Dotfiles Directory: Move into the dotfiles directory.

```bash
cd dotfiles
```
Make Installer Executable: Ensure the installer script (installer.sh) is executable.

```bash
chmod +x installer.sh
```
Run Installer: Execute the installer script to apply your configurations.

```bash
./installer.sh
```
Customization
Feel free to customize the dotfiles according to your preferences. You can edit the configuration files using your preferred text editor.

Contribution
If you have suggestions for improvements or new features, feel free to open an issue or submit a pull request.
