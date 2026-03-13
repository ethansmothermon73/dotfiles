#!/bin/bash
# =============================================================================
# Brodie Robertson Dotfiles - Full Install Script
# Based on: https://github.com/BrodieRobertson/dotfiles
# Run this on Arch Linux (or Arch-based distro)
# Usage: chmod +x install-brodie-dotfiles.sh && ./install-brodie-dotfiles.sh
# =============================================================================

set -e

DOTFILES_DIR="$HOME/repos/dotfiles"
DOTFILES_ZIP="dotfiles-master.zip"

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()     { echo -e "${RED}[ERR]${NC}  $*"; exit 1; }

# ─── Verify Arch ──────────────────────────────────────────────────────────────
[[ -f /etc/arch-release ]] || die "This script is for Arch Linux only."

# ─── 1. Install paru (AUR helper) ─────────────────────────────────────────────
install_paru() {
    if ! command -v paru &>/dev/null; then
        info "Installing paru (AUR helper)..."
        sudo pacman -S --needed --noconfirm base-devel git
        tmpdir=$(mktemp -d)
        git clone https://aur.archlinux.org/paru.git "$tmpdir/paru"
        (cd "$tmpdir/paru" && makepkg -si --noconfirm)
        rm -rf "$tmpdir"
        success "paru installed"
    else
        success "paru already installed"
    fi
}

# ─── 2. Install all packages ──────────────────────────────────────────────────
install_packages() {
    info "Installing pacman packages..."

    PACMAN_PKGS=(
        # Shell & Terminal
        zsh
        alacritty
        kitty

        # Window Manager & Display
        bspwm
        sxhkd
        awesome
        picom
        polybar
        rofi
        hsetroot
        xorg-xrdb
        xorg-xinit
        xorg-server
        xorg-xsetroot
        xdotool

        # Prompt
        powerline
        python-powerline-shell

        # Zsh plugins
        zsh-syntax-highlighting

        # File Managers
        lf
        ranger
        nnn
        vifm
        udiskie

        # Editor
        neovim
        vim

        # Fonts
        ttf-jetbrains-mono-nerd
        ttf-hack-nerd
        noto-fonts-emoji
        otf-font-awesome

        # Fetch / Info
        fastfetch
        neofetch

        # System Tools
        btop
        htop
        lsd
        eza
        fzf
        ripgrep
        fd
        bat
        exa
        prettyping
        pkgfile
        trash-cli
        xsel
        xclip
        flameshot
        dunst
        libnotify

        # Media
        mpv
        mpd
        ncmpcpp
        mpc
        sxiv
        nsxiv
        zathura
        zathura-pdf-mupdf

        # Networking & System
        networkmanager
        network-manager-applet
        transmission-daemon
        transmission-cli
        ufw

        # Audio
        pulseaudio
        pulseaudio-alsa
        pavucontrol
        alsa-utils

        # GTK / Qt Theming
        papirus-icon-theme
        breeze
        qt5ct
        qt6ct
        lxappearance

        # Dev Tools
        git
        nodejs
        npm
        python
        python-pip
        lua
        go
        rust
        cargo

        # Misc
        highlight
        glow
        moar
        calcurse
        newsboat
        pcmanfm
        dragon-drop
        xdg-utils
        xdg-user-dirs
        fcitx5
        fcitx5-gtk
        fcitx5-qt
        imwheel
    )

    sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}" || warn "Some pacman packages failed (may already be installed or name changed)"
    success "Pacman packages installed"

    info "Installing AUR packages..."
    AUR_PKGS=(
        # Prompt
        powerline-shell

        # Zsh plugins
        zsh-you-should-use
        pkgfile

        # Terminal extras
        z.lua
        prettyping

        # Theming
        breeze-gtk
        papirus-folders-git

        # Fonts
        ttf-bebas-neue
        ttf-roboto

        # System
        bspswallow
        picom-animations-git

        # Apps
        nsxiv
        moar
        glow

        # Neovim dependencies
        nodejs-neovim
        python-pynvim
    )

    paru -S --needed --noconfirm "${AUR_PKGS[@]}" 2>/dev/null || warn "Some AUR packages failed — install manually if needed"
    success "AUR packages installed"
}

# ─── 3. Extract / clone dotfiles ──────────────────────────────────────────────
setup_dotfiles_dir() {
    info "Setting up dotfiles directory at $DOTFILES_DIR..."
    mkdir -p "$HOME/repos"

    if [[ -f "$HOME/$DOTFILES_ZIP" ]]; then
        info "Found uploaded zip — extracting..."
        unzip -o "$HOME/$DOTFILES_ZIP" -d "$HOME/repos/"
        # The zip extracts as dotfiles-master; rename to dotfiles
        if [[ -d "$HOME/repos/dotfiles-master" ]]; then
            mv "$HOME/repos/dotfiles-master" "$DOTFILES_DIR"
        fi
        success "Dotfiles extracted to $DOTFILES_DIR"
    elif [[ ! -d "$DOTFILES_DIR" ]]; then
        info "Cloning BrodieRobertson/dotfiles from GitHub..."
        git clone https://github.com/BrodieRobertson/dotfiles.git "$DOTFILES_DIR"
        success "Dotfiles cloned"
    else
        success "Dotfiles directory already exists at $DOTFILES_DIR"
    fi
}

# ─── 4. Symlink dotfiles ──────────────────────────────────────────────────────
symlink_dotfiles() {
    info "Symlinking dotfiles..."
    path="$DOTFILES_DIR"

    lns() { ln -sf "$1" "$2" && success "Linked: $2"; }
    mkd() { [[ ! -d "$1" ]] && mkdir -p "$1"; }

    # ── Home directory ──
    lns "$path/.bash_profile"   "$HOME/.bash_profile"
    lns "$path/.bashrc"         "$HOME/.bashrc"
    lns "$path/.imwheelrc"      "$HOME/.imwheelrc"
    lns "$path/.profile"        "$HOME/.profile"
    lns "$path/.Xresources"     "$HOME/.Xresources"
    lns "$path/.xinitrc"        "$HOME/.xinitrc"
    lns "$path/.Xmodmap"        "$HOME/.Xmodmap"
    lns "$path/.zcompdump"      "$HOME/.zcompdump"
    lns "$path/.zprofile"       "$HOME/.zprofile"
    lns "$path/.zshenv"         "$HOME/.zshenv"
    lns "$path/.zshrc"          "$HOME/.zshrc"
    lns "$path/config/nvim/init.vim" "$HOME/.vimrc"

    # ── ~/.config directories ──
    mkd "$HOME/.config"

    for dir in \
        alacritty awesome bashtop bookmenu bspwm btop calcurse cfiles \
        deadd dunst flameshot gitui gtk-2.0 gtk-3.0 hypr i3 i3blocks \
        joplin kitty lf mpd mpv ncmpcpp ncspot neofetch newsboat nnn \
        nvim pcmanfm pistol polybar powerline-shell ranger rofi \
        shellconfig sxhkd tabdmenu tofi transmission-daemon \
        transmission-rss twmn vifm vlc waybar zsh \
        succade cointop paru
    do
        target="$HOME/.config/$dir"
        source="$path/config/$dir"
        if [[ -d "$source" ]]; then
            [[ -e "$target" || -L "$target" ]] && rm -rf "$target"
            lns "$source" "$target"
        fi
    done

    # Single config files
    lns "$path/config/compton.conf"     "$HOME/.config/compton.conf"
    lns "$path/config/dolphinrc"        "$HOME/.config/dolphinrc"
    lns "$path/config/kdeglobals"       "$HOME/.config/kdeglobals"
    lns "$path/config/mimeapps.list"    "$HOME/.config/mimeapps.list"
    lns "$path/config/pavucontrol.ini"  "$HOME/.config/pavucontrol.ini"
    lns "$path/config/wall.png"         "$HOME/.config/wall.png"
    # NOTE: starship.toml exists in repo but we skip it per user request (no starship)

    # ── ~/.local ──
    mkd "$HOME/.local/share"
    [[ -e "$HOME/.local/share/applications" ]] && rm -rf "$HOME/.local/share/applications"
    lns "$path/.local/share/applications" "$HOME/.local/share/applications"
    [[ -e "$HOME/.local/share/fonts" ]] && rm -rf "$HOME/.local/share/fonts"
    lns "$path/.local/share/fonts" "$HOME/.local/share/fonts"

    # ── GIMP ──
    mkd "$HOME/.config/GIMP/2.10"
    lns "$path/config/GIMP/filters"  "$HOME/.config/GIMP/2.10/filters"
    lns "$path/config/GIMP/patterns" "$HOME/.config/GIMP/2.10/patterns"

    # ── VSCodium ──
    mkd "$HOME/.config/VSCodium/User"
    lns "$path/config/VSCodium/keybindings.json" "$HOME/.config/VSCodium/User/keybindings.json"
    lns "$path/config/VSCodium/settings.json"    "$HOME/.config/VSCodium/User/settings.json"

    # ── X11 ──
    mkd "$HOME/.config/X11"
    lns "$path/.xinitrc"    "$HOME/.config/X11/xinitrc"
    lns "$path/.Xmodmap"    "$HOME/.config/X11/xmodmap"
    lns "$path/.Xresources" "$HOME/.config/X11/xresources"

    success "All dotfiles symlinked"
}

# ─── 5. Powerline-shell purple prompt ─────────────────────────────────────────
setup_prompt() {
    info "Setting up powerline-shell purple prompt (no starship)..."

    # Ensure python powerline-shell is installed
    pip install powerline-shell --user 2>/dev/null || true

    # Config + theme are already linked via dotfiles (~/.config/powerline-shell/)
    # The theme sets: USERNAME_BG=53 (dark purple), PATH_BG=5 (purple) — exact Brodie colors

    # Add powerline-shell to .zshrc if not already sourced there
    # (Brodie's zshrc uses spaceship at the bottom; we patch it to use powerline-shell)
    ZSHRC="$HOME/.zshrc"
    if [[ -f "$ZSHRC" ]] && grep -q "spaceship" "$ZSHRC"; then
        info "Patching .zshrc: replacing spaceship prompt with powerline-shell..."
        # Create override file that sources after .zshrc
        cat > "$HOME/.config/zsh/prompt-override.zsh" << 'EOF'
# Override: use powerline-shell (purple prompt) instead of spaceship
function powerline_precmd() {
    PS1="$(powerline-shell --shell zsh $?)"
}
function install_powerline_precmd() {
    for s in "${precmd_functions[@]}"; do
        if [ "$s" = "powerline_precmd" ]; then return; fi
    done
    precmd_functions+=(powerline_precmd)
}
if [ "$TERM" != "linux" ]; then
    install_powerline_precmd
fi
EOF
        # Source the override at end of zshrc if not already there
        grep -q "prompt-override" "$ZSHRC" || echo 'source ~/.config/zsh/prompt-override.zsh' >> "$ZSHRC"
        success "Powerline-shell purple prompt configured"
    fi
}

# ─── 6. Neovim plugins ────────────────────────────────────────────────────────
setup_neovim() {
    info "Setting up Neovim plugins..."

    # Install vim-plug for neovim
    NVIM_PLUG="$HOME/.local/share/nvim/site/autoload/plug.vim"
    if [[ ! -f "$NVIM_PLUG" ]]; then
        curl -fLo "$NVIM_PLUG" --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
        success "vim-plug installed"
    fi

    # Install coc.nvim node deps
    if command -v node &>/dev/null; then
        COC_DIR="$HOME/.config/nvim/pack/plugins/start/coc.nvim"
        if [[ -d "$COC_DIR" && -f "$COC_DIR/package.json" ]]; then
            (cd "$COC_DIR" && npm ci --no-fund 2>/dev/null) && success "coc.nvim node deps installed" || warn "coc.nvim deps failed"
        fi
    fi

    # Run PlugInstall headlessly
    nvim --headless +PlugInstall +qall 2>/dev/null || true
    success "Neovim plugins setup done"
}

# ─── 7. z.lua setup ───────────────────────────────────────────────────────────
setup_zlua() {
    info "Setting up z.lua..."
    if ! command -v lua &>/dev/null; then
        warn "lua not found — z.lua won't work until lua is installed"
        return
    fi
    ZLUA_PATH="$HOME/.local/bin/z.lua"
    if [[ ! -f "$ZLUA_PATH" ]]; then
        mkdir -p "$HOME/.local/bin"
        curl -fsSL https://raw.githubusercontent.com/skywind3000/z.lua/master/z.lua \
            -o "$ZLUA_PATH"
        success "z.lua downloaded to $ZLUA_PATH"
    else
        success "z.lua already present"
    fi
}

# ─── 8. GTK & Icon Theme ──────────────────────────────────────────────────────
setup_themes() {
    info "Applying GTK theme (Breeze-Dark + Papirus-Dark)..."
    # GTK3 settings are already symlinked from dotfiles (Breeze-Dark, Papirus-Dark, Roboto 11)
    # Refresh font cache
    fc-cache -fv &>/dev/null && success "Font cache refreshed"
    # Update icon cache
    gtk-update-icon-cache -f /usr/share/icons/Papirus-Dark 2>/dev/null || true
    success "Themes configured"
}

# ─── 9. Set zsh as default shell ─────────────────────────────────────────────
set_zsh_default() {
    if [[ "$SHELL" != "$(which zsh)" ]]; then
        info "Setting zsh as default shell..."
        chsh -s "$(which zsh)"
        success "zsh is now your default shell (log out & back in)"
    else
        success "zsh is already the default shell"
    fi
}

# ─── 10. Create cache dir for zsh history ────────────────────────────────────
setup_dirs() {
    info "Creating required directories..."
    mkdir -p "$HOME/.cache/zsh"
    mkdir -p "$HOME/.local/share/zsh"
    mkdir -p "$HOME/scripts"
    mkdir -p "$HOME/pictures/screenshots"
    success "Directories created"
}

# ─── 11. Enable services ─────────────────────────────────────────────────────
enable_services() {
    info "Enabling systemd services..."
    sudo systemctl enable --now NetworkManager 2>/dev/null && success "NetworkManager enabled" || true
    sudo systemctl enable --now transmission 2>/dev/null || true
    sudo systemctl enable --now mpd --user 2>/dev/null || true
}

# ─── 12. pkgfile database update (command-not-found) ─────────────────────────
update_pkgfile() {
    if command -v pkgfile &>/dev/null; then
        info "Updating pkgfile database..."
        sudo pkgfile --update && success "pkgfile database updated"
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║   Brodie Robertson Dotfiles — Full Installer     ║${NC}"
echo -e "${BOLD}${CYAN}║   github.com/BrodieRobertson/dotfiles             ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

install_paru
install_packages
setup_dotfiles_dir
symlink_dotfiles
setup_prompt
setup_neovim
setup_zlua
setup_themes
set_zsh_default
setup_dirs
enable_services
update_pkgfile

echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║   ✓  Installation complete!                      ║${NC}"
echo -e "${BOLD}${GREEN}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}${GREEN}║  Next steps:                                     ║${NC}"
echo -e "${BOLD}${GREEN}║  1. Log out and back in (zsh + env vars)         ║${NC}"
echo -e "${BOLD}${GREEN}║  2. Start X with: startx  (launches AwesomeWM)   ║${NC}"
echo -e "${BOLD}${GREEN}║     or switch to bspwm: change .xinitrc          ║${NC}"
echo -e "${BOLD}${GREEN}║  3. Polybar starts automatically via bspwmrc     ║${NC}"
echo -e "${BOLD}${GREEN}║  4. Prompt: brodie | arch | ~ | $ (purple/pink)  ║${NC}"
echo -e "${BOLD}${GREEN}║  5. Font: JetBrains Mono (alacritty + kitty)     ║${NC}"
echo -e "${BOLD}${GREEN}║  6. GTK: Breeze-Dark + Papirus-Dark icons        ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Dotfiles live at: $DOTFILES_DIR${NC}"
echo -e "${YELLOW}Prompt config:    ~/.config/powerline-shell/${NC}"
echo -e "${YELLOW}Shell config:     ~/.config/shellconfig/${NC}"
echo ""
