#!/usr/bin/env bash
# =============================================================================
#  Brodie Robertson Dotfiles Installer
#  Based on: https://github.com/BrodieRobertson/dotfiles
#            https://github.com/BrodieRobertson/scripts
#  Target: Arch Linux (uses paru AUR helper)
#  Run as your normal user (NOT root). Script will sudo when needed.
# =============================================================================

set -euo pipefail

# ── colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

msg()  { echo -e "${CYAN}${BOLD}==> ${RESET}${BOLD}$*${RESET}"; }
ok()   { echo -e "${GREEN}[✔]${RESET} $*"; }
warn() { echo -e "${YELLOW}[!]${RESET} $*"; }
die()  { echo -e "${RED}[✘] FATAL: $*${RESET}"; exit 1; }

# ── safety checks ────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] && die "Do NOT run this script as root."
command -v pacman &>/dev/null || die "This script is for Arch Linux only."

# ── config ───────────────────────────────────────────────────────────────────
DOTFILES_REPO="https://github.com/BrodieRobertson/dotfiles"
SCRIPTS_REPO="https://github.com/BrodieRobertson/scripts"
DOTFILES_DIR="$HOME/.dotfiles"
SCRIPTS_DIR="$HOME/scripts"
CONFIG="$HOME/.config"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# ── helpers ───────────────────────────────────────────────────────────────────
backup_file() {
    local target="$1"
    if [[ -e "$target" && ! -L "$target" ]]; then
        mkdir -p "$BACKUP_DIR"
        warn "Backing up existing $target → $BACKUP_DIR/"
        cp -r "$target" "$BACKUP_DIR/"
    fi
}

safe_symlink() {
    # safe_symlink <source> <destination>
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    backup_file "$dst"
    ln -sfn "$src" "$dst"
}

pkg_installed() { pacman -Qi "$1" &>/dev/null; }

pacman_install() {
    local pkgs=("$@")
    local missing=()
    for p in "${pkgs[@]}"; do
        pkg_installed "$p" || missing+=("$p")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        msg "Installing from official repos: ${missing[*]}"
        sudo pacman -S --needed --noconfirm "${missing[@]}"
    fi
}

aur_install() {
    local pkgs=("$@")
    local missing=()
    for p in "${pkgs[@]}"; do
        pkg_installed "$p" || missing+=("$p")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        msg "Installing from AUR: ${missing[*]}"
        # --noconfirm        : no Y/N prompts
        # --skipreview       : don't pause to show PKGBUILD diffs (main freeze cause)
        # --removemake       : clean up makedepends after build
        # --noupgrademenu    : skip the upgrade selection menu
        # PAGER=cat          : stop paru piping output to less (another freeze cause)
        PAGER=cat paru -S --needed --noconfirm --skipreview \
            --removemake --noupgrademenu "${missing[@]}"
    fi
}

# =============================================================================
#  STEP 1 – Bootstrap paru (AUR helper)
# =============================================================================
bootstrap_paru() {
    msg "Bootstrapping paru AUR helper"
    if command -v paru &>/dev/null; then
        ok "paru already installed"
        # Patch paru.conf to prevent all freeze causes going forward
        configure_paru
        return
    fi

    pacman_install git base-devel

    # Receive the paru maintainer's GPG key so makepkg doesn't hang on key import
    gpg --keyserver keyserver.ubuntu.com \
        --recv-keys 6BC26A17B9B7018A 2>/dev/null || \
    gpg --keyserver hkps://keys.openpgp.org \
        --recv-keys 6BC26A17B9B7018A 2>/dev/null || \
        warn "GPG key fetch failed — continuing anyway (may prompt during build)"

    local tmpdir
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/paru.git "$tmpdir/paru"
    # MAKEFLAGS uses all cores so the Rust compile doesn't appear frozen
    MAKEFLAGS="-j$(nproc)" PAGER=cat \
        makepkg -si --noconfirm -C "$tmpdir/paru"
    rm -rf "$tmpdir"

    configure_paru
    ok "paru installed"
}

# Write a non-interactive paru.conf so it never prompts/pauses again
configure_paru() {
    local conf="${XDG_CONFIG_HOME:-$HOME/.config}/paru/paru.conf"
    mkdir -p "$(dirname "$conf")"
    # Only write if the key options aren't already there
    if ! grep -q "SkipReview" "$conf" 2>/dev/null; then
        msg "Writing non-interactive paru.conf"
        cat > "$conf" <<'EOF'
[options]
PgpFetch
Devel
Provides
DevelSuffixes = -git -cvs -svn -bzr -darcs -always
UpgradeMenu = false
SkipReview             # never pause to show PKGBUILD diffs
RemoveMake             # clean makedepends after build
SudoLoop               # keep sudo alive so builds don't stall waiting for password
CombinedUpgrade        # mix official + AUR upgrades in one pass
NewsOnUpgrade          # show Arch news but don't block
EOF
        ok "paru.conf written — freezing disabled"
    else
        ok "paru.conf already has SkipReview"
    fi
}

# =============================================================================
#  STEP 2 – Clone repos
# =============================================================================
clone_repos() {
    msg "Cloning BrodieRobertson/dotfiles"
    if [[ -d "$DOTFILES_DIR/.git" ]]; then
        warn "Dotfiles repo already cloned — pulling latest"
        git -C "$DOTFILES_DIR" pull
    else
        git clone --depth 1 "$DOTFILES_REPO" "$DOTFILES_DIR"
    fi

    msg "Cloning BrodieRobertson/scripts"
    if [[ -d "$SCRIPTS_DIR/.git" ]]; then
        warn "Scripts repo already cloned — pulling latest"
        git -C "$SCRIPTS_DIR" pull
    else
        git clone --depth 1 "$SCRIPTS_REPO" "$SCRIPTS_DIR"
    fi
    ok "Repos cloned"
}

# =============================================================================
#  STEP 3 – Install packages
# =============================================================================

install_base() {
    msg "Installing base system utilities"
    pacman_install \
        base-devel git curl wget unzip zip tar \
        xorg-server xorg-xinit xorg-xrdb xorg-xrandr \
        xorg-xprop xorg-xdotool xorg-xsetroot \
        dbus networkmanager network-manager-applet \
        pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
        alsa-utils \
        udiskie udisks2 \
        polkit polkit-gnome \
        thunar gvfs \
        fontconfig xdg-utils xdg-user-dirs
}

install_wm_bspwm() {
    msg "Installing bspwm + sxhkd stack"
    pacman_install \
        bspwm sxhkd \
        picom \
        polybar \
        rofi \
        dunst libnotify \
        hsetroot \
        xdotool wmname
    aur_install \
        bsp-layout
}

install_wm_hyprland() {
    msg "Installing Hyprland (Wayland) stack"
    pacman_install \
        hyprland \
        waybar \
        swaybg \
        dunst libnotify \
        tofi \
        wl-clipboard \
        xdg-desktop-portal-hyprland \
        qt5-wayland qt6-wayland
    aur_install \
        hyprpicker
}

install_wm_i3() {
    msg "Installing i3 stack"
    pacman_install \
        i3-wm i3blocks i3status \
        rofi \
        dunst libnotify \
        picom
}

install_terminal_tools() {
    msg "Installing terminal emulators & shell tooling"
    # Terminal emulators
    pacman_install \
        kitty alacritty

    # Shell
    pacman_install \
        zsh zsh-completions

    # Core CLI tools Brodie uses
    pacman_install \
        neovim vim \
        lf ranger \
        fzf \
        ripgrep fd bat \
        eza \
        git-delta \
        htop btop \
        tmux \
        stow \
        jq \
        imagemagick \
        ffmpeg \
        mpv \
        zathura zathura-pdf-mupdf \
        nsxiv \
        trash-cli \
        the_silver_searcher \
        highlight \
        glow \
        moar \
        newsboat \
        ncmpcpp mpd mpc \
        fastfetch \
        prettyping \
        dragon-drop
    
    aur_install \
        z.lua \
        zsh-you-should-use \
        zsh-syntax-highlighting \
        spaceship-prompt \
        pistol \
        tremc \
        gitui \
        joshuto
}

install_gui_apps() {
    msg "Installing GUI applications"
    pacman_install \
        brave-browser \
        flameshot \
        gimp \
        pcmanfm \
        transmission-gtk \
        vlc \
        blender \
        fcitx5 fcitx5-configtool \
        qt5ct qt6ct \
        imwheel

    aur_install \
        vscodium-bin \
        deadd-notification-center \
        joplin-desktop
}

install_fonts() {
    msg "Installing fonts"
    pacman_install \
        ttf-jetbrains-mono \
        ttf-jetbrains-mono-nerd \
        noto-fonts noto-fonts-emoji \
        ttf-font-awesome \
        ttf-sourcecodepro-nerd

    aur_install \
        ttf-bebas-neue \
        otf-azonix
}

install_gtk_qt_themes() {
    msg "Installing GTK/QT themes & icon packs"
    aur_install \
        nordic-theme \
        papirus-icon-theme \
        lxappearance
    pacman_install \
        gtk2 gtk3 \
        kvantum \
        qt5-styleplugins
}

# =============================================================================
#  STEP 4 – Link dotfiles
# =============================================================================
link_dotfiles() {
    msg "Linking dotfiles from $DOTFILES_DIR"

    # Shell
    safe_symlink "$DOTFILES_DIR/.zshrc"      "$HOME/.zshrc"
    safe_symlink "$DOTFILES_DIR/.zshenv"     "$HOME/.zshenv"
    safe_symlink "$DOTFILES_DIR/.zprofile"   "$HOME/.zprofile"
    safe_symlink "$DOTFILES_DIR/.bash_profile" "$HOME/.bash_profile"
    safe_symlink "$DOTFILES_DIR/.bashrc"     "$HOME/.bashrc"
    safe_symlink "$DOTFILES_DIR/.profile"    "$HOME/.profile"

    # X11
    safe_symlink "$DOTFILES_DIR/.xinitrc"    "$HOME/.xinitrc"
    safe_symlink "$DOTFILES_DIR/.Xresources" "$HOME/.Xresources"
    safe_symlink "$DOTFILES_DIR/.Xmodmap"    "$HOME/.Xmodmap"
    safe_symlink "$DOTFILES_DIR/.imwheelrc"  "$HOME/.imwheelrc"
    safe_symlink "$DOTFILES_DIR/config/X11"  "$CONFIG/X11"

    # WMs
    safe_symlink "$DOTFILES_DIR/config/bspwm"    "$CONFIG/bspwm"
    safe_symlink "$DOTFILES_DIR/config/sxhkd"    "$CONFIG/sxhkd"
    safe_symlink "$DOTFILES_DIR/config/i3"       "$CONFIG/i3"
    safe_symlink "$DOTFILES_DIR/config/i3blocks" "$CONFIG/i3blocks"
    safe_symlink "$DOTFILES_DIR/config/hypr"     "$CONFIG/hypr"

    # Status bars
    safe_symlink "$DOTFILES_DIR/config/polybar"  "$CONFIG/polybar"
    safe_symlink "$DOTFILES_DIR/config/waybar"   "$CONFIG/waybar"
    safe_symlink "$DOTFILES_DIR/config/yabar"    "$CONFIG/yabar"
    safe_symlink "$DOTFILES_DIR/config/lemonbar" "$CONFIG/lemonbar" 2>/dev/null || true

    # Launchers / notifications
    safe_symlink "$DOTFILES_DIR/config/rofi"   "$CONFIG/rofi"
    safe_symlink "$DOTFILES_DIR/config/dunst"  "$CONFIG/dunst"
    safe_symlink "$DOTFILES_DIR/config/tofi"   "$CONFIG/tofi"
    safe_symlink "$DOTFILES_DIR/config/deadd"  "$CONFIG/deadd"

    # Terminals
    safe_symlink "$DOTFILES_DIR/config/alacritty" "$CONFIG/alacritty"
    safe_symlink "$DOTFILES_DIR/config/kitty"     "$CONFIG/kitty"

    # Shell config fragments
    safe_symlink "$DOTFILES_DIR/config/shellconfig" "$CONFIG/shellconfig"
    safe_symlink "$DOTFILES_DIR/config/zsh"         "$CONFIG/zsh"

    # Editor – neovim
    safe_symlink "$DOTFILES_DIR/config/nvim" "$CONFIG/nvim"

    # File managers
    safe_symlink "$DOTFILES_DIR/config/lf"      "$CONFIG/lf"
    safe_symlink "$DOTFILES_DIR/config/ranger"  "$CONFIG/ranger"
    safe_symlink "$DOTFILES_DIR/config/vifm"    "$CONFIG/vifm"
    safe_symlink "$DOTFILES_DIR/config/nnn"     "$CONFIG/nnn"

    # Media
    safe_symlink "$DOTFILES_DIR/config/mpv"     "$CONFIG/mpv"
    safe_symlink "$DOTFILES_DIR/config/mpd"     "$CONFIG/mpd"
    safe_symlink "$DOTFILES_DIR/config/ncmpcpp" "$CONFIG/ncmpcpp"
    safe_symlink "$DOTFILES_DIR/config/ncspot"  "$CONFIG/ncspot"

    # News / bookmarks
    safe_symlink "$DOTFILES_DIR/config/newsboat"  "$CONFIG/newsboat"
    safe_symlink "$DOTFILES_DIR/config/bookmenu"  "$CONFIG/bookmenu"

    # Misc
    safe_symlink "$DOTFILES_DIR/config/btop"         "$CONFIG/btop"
    safe_symlink "$DOTFILES_DIR/config/neofetch"     "$CONFIG/neofetch"
    safe_symlink "$DOTFILES_DIR/config/flameshot"    "$CONFIG/flameshot"
    safe_symlink "$DOTFILES_DIR/config/pcmanfm"      "$CONFIG/pcmanfm"
    safe_symlink "$DOTFILES_DIR/config/gtk-2.0"      "$CONFIG/gtk-2.0"
    safe_symlink "$DOTFILES_DIR/config/gtk-3.0"      "$CONFIG/gtk-3.0"
    safe_symlink "$DOTFILES_DIR/config/qt5ct"        "$CONFIG/qt5ct"
    safe_symlink "$DOTFILES_DIR/config/qt6ct"        "$CONFIG/qt6ct"
    safe_symlink "$DOTFILES_DIR/config/paru"         "$CONFIG/paru"
    safe_symlink "$DOTFILES_DIR/config/gitui"        "$CONFIG/gitui"
    safe_symlink "$DOTFILES_DIR/config/joplin"       "$CONFIG/joplin"
    safe_symlink "$DOTFILES_DIR/config/pistol"       "$CONFIG/pistol"
    safe_symlink "$DOTFILES_DIR/config/VSCodium"     "$CONFIG/VSCodium"

    # Fonts bundled in dotfiles
    if [[ -d "$DOTFILES_DIR/.local/share/fonts" ]]; then
        mkdir -p "$HOME/.local/share/fonts"
        cp -rn "$DOTFILES_DIR/.local/share/fonts/." "$HOME/.local/share/fonts/"
        fc-cache -f
        ok "Custom fonts installed"
    fi

    # Desktop entries
    if [[ -d "$DOTFILES_DIR/.local/share/applications" ]]; then
        mkdir -p "$HOME/.local/share/applications"
        cp -rn "$DOTFILES_DIR/.local/share/applications/." "$HOME/.local/share/applications/" 2>/dev/null || true
    fi

    ok "Dotfiles linked"
}

# =============================================================================
#  STEP 5 – Install scripts
# =============================================================================
install_scripts() {
    msg "Making scripts executable and adding to PATH"

    find "$SCRIPTS_DIR" -type f ! -name "*.md" ! -name "LICENSE*" \
         ! -name "*.lua" ! -name "joshuto" \
         -exec chmod +x {} \;

    # Add scripts dir to PATH via zshenv if not already there
    if ! grep -q 'HOME/scripts' "$HOME/.zshenv" 2>/dev/null; then
        warn "scripts PATH already managed by .zshenv symlink — no changes needed"
    fi

    ok "Scripts ready at $SCRIPTS_DIR"
}

# =============================================================================
#  STEP 6 – Shell setup
# =============================================================================
setup_shell() {
    msg "Setting default shell to zsh"
    if [[ "$SHELL" != "$(command -v zsh)" ]]; then
        chsh -s "$(command -v zsh)"
        ok "Default shell changed to zsh (re-login to take effect)"
    else
        ok "zsh already default shell"
    fi

    # zsh history cache dir
    mkdir -p "$HOME/.cache/zsh"
    mkdir -p "$HOME/.local/share/zsh"

    ok "Shell setup done"
}

# =============================================================================
#  STEP 7 – Compositor & display setup
# =============================================================================
setup_display() {
    msg "Reloading Xresources (if in X session)"
    if [[ -n "${DISPLAY:-}" ]]; then
        xrdb -merge "$HOME/.Xresources" && ok "Xresources loaded"
    else
        warn "No DISPLAY detected — skipping xrdb (will load at next X login)"
    fi
}

# =============================================================================
#  STEP 8 – Enable system services
# =============================================================================
enable_services() {
    msg "Enabling system services"

    # NetworkManager
    sudo systemctl enable --now NetworkManager 2>/dev/null && ok "NetworkManager enabled"

    # pipewire
    systemctl --user enable --now pipewire.service       2>/dev/null || true
    systemctl --user enable --now pipewire-pulse.service 2>/dev/null || true
    systemctl --user enable --now wireplumber.service    2>/dev/null || true
    ok "Pipewire audio services enabled"

    # mpd
    systemctl --user enable --now mpd.service 2>/dev/null || true
    ok "MPD enabled"

    # transmission
    sudo systemctl enable --now transmission.service 2>/dev/null || true

    # udiskie (auto-mount)
    systemctl --user enable --now udiskie.service 2>/dev/null || true
}

# =============================================================================
#  STEP 9 – WM-specific final setup
# =============================================================================
setup_bspwm() {
    msg "bspwm post-install"
    chmod +x "$CONFIG/bspwm/bspwmrc" 2>/dev/null || true

    # Make bspwm autostart via .xinitrc
    if ! grep -q bspwm "$HOME/.xinitrc" 2>/dev/null; then
        echo "exec bspwm" >> "$HOME/.xinitrc"
        ok "Added 'exec bspwm' to .xinitrc"
    fi
}

setup_hyprland() {
    msg "Hyprland post-install"
    # Create a simple SDDM/greetd session entry if needed
    if [[ ! -f /usr/share/wayland-sessions/hyprland.desktop ]]; then
        sudo tee /usr/share/wayland-sessions/hyprland.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Hyprland
Comment=A dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
EOF
        ok "Created Hyprland wayland session entry"
    fi
}

# =============================================================================
#  STEP 10 – Neovim plugin install
# =============================================================================
setup_nvim() {
    msg "Installing Neovim plugins (vim-plug detected)"
    local plug_path="$HOME/.local/share/nvim/site/autoload/plug.vim"
    if [[ ! -f "$plug_path" ]]; then
        curl -fLo "$plug_path" --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
        ok "vim-plug installed"
    else
        ok "vim-plug already present"
    fi

    warn "Run ':PlugInstall' inside Neovim to finish plugin setup"
}

# =============================================================================
#  STEP 11 – GTK / Qt theme application
# =============================================================================
apply_themes() {
    msg "Applying Nord GTK + Papirus icon theme"

    # GTK 2
    mkdir -p "$CONFIG/gtk-2.0"
    cat > "$HOME/.gtkrc-2.0" <<'EOF'
gtk-theme-name="Nordic"
gtk-icon-theme-name="Papirus-Dark"
gtk-font-name="Noto Sans 10"
gtk-cursor-theme-name="Adwaita"
gtk-cursor-theme-size=0
gtk-toolbar-style=GTK_TOOLBAR_BOTH
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle="hintfull"
EOF

    # GTK 3
    mkdir -p "$CONFIG/gtk-3.0"
    cat > "$CONFIG/gtk-3.0/settings.ini" <<'EOF'
[Settings]
gtk-theme-name=Nordic
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Noto Sans 10
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=0
gtk-toolbar-style=GTK_TOOLBAR_BOTH
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintfull
EOF

    ok "GTK theme configured (Nordic + Papirus-Dark)"
}

# =============================================================================
#  STEP 12 – Nord colour theme for Alacritty (patch)
# =============================================================================
patch_alacritty_nord() {
    msg "Ensuring Nord colour theme is set in Alacritty config"
    local cfg="$CONFIG/alacritty/alacritty.toml"
    if [[ -f "$cfg" ]] && ! grep -q "Nord\|nord" "$cfg"; then
        # Append a minimal Nord colour scheme if not already present
        cat >> "$cfg" <<'EOF'

# ── Nord colour scheme (appended by installer) ───────────────────────────────
[colors.primary]
background = "#2e3440"
foreground = "#d8dee9"

[colors.normal]
black   = "#3b4252"
red     = "#bf616a"
green   = "#a3be8c"
yellow  = "#ebcb8b"
blue    = "#81a1c1"
magenta = "#b48ead"
cyan    = "#88c0d0"
white   = "#e5e9f0"

[colors.bright]
black   = "#4c566a"
red     = "#bf616a"
green   = "#a3be8c"
yellow  = "#ebcb8b"
blue    = "#81a1c1"
magenta = "#b48ead"
cyan    = "#8fbcbb"
white   = "#eceff4"
EOF
        ok "Nord colours appended to alacritty.toml"
    else
        ok "Alacritty config already has colour scheme"
    fi
}

# =============================================================================
#  STEP 13 – Final summary
# =============================================================================
print_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗"
    echo -e "║       Brodie Robertson Dotfiles — Install Complete!          ║"
    echo -e "╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  ${CYAN}Dotfiles${RESET}  →  $DOTFILES_DIR"
    echo -e "  ${CYAN}Scripts${RESET}   →  $SCRIPTS_DIR"
    echo -e "  ${CYAN}Backups${RESET}   →  $BACKUP_DIR  (if any existed)"
    echo ""
    echo -e "${BOLD}What to do next:${RESET}"
    echo "  1. Log out and back in (or reboot) — zsh is now your default shell"
    echo "  2. Start X with bspwm:   startx"
    echo "     Start Hyprland:        Hyprland"
    echo "     Start i3:             startx ~/.xinitrc i3"
    echo "  3. Inside Neovim run:   :PlugInstall"
    echo "  4. Set wallpaper:       cp your-wall.png ~/.config/wall.png"
    echo "  5. Edit monitor layout in ~/.config/bspwm/bspwmrc"
    echo "     and ~/.config/hypr/hyprland.conf to match your displays"
    echo ""
    echo -e "${YELLOW}Note:${RESET} bspwm scripts (bspswallow, crystal, etc.) live in ~/scripts/bspwm/"
    echo "      They are already on your PATH via ~/.zshenv"
    echo ""
}

# =============================================================================
#  MAIN – interactive menu
# =============================================================================
main() {
    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════╗"
    echo "  ║   Brodie Robertson Dotfiles Installer            ║"
    echo "  ║   github.com/BrodieRobertson                     ║"
    echo "  ╚══════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo -e "${BOLD}Choose which WM(s) to install:${RESET}"
    echo "  1) bspwm  (Brodie's primary X11 setup)"
    echo "  2) Hyprland (his current Wayland setup)"
    echo "  3) i3 (classic; configs included)"
    echo "  4) All of the above"
    read -rp "Choice [1-4, default=2]: " WM_CHOICE
    WM_CHOICE="${WM_CHOICE:-2}"

    echo ""
    echo -e "${BOLD}Install GUI applications? (brave, gimp, vscodium, joplin…)${RESET}"
    read -rp "[Y/n]: " INSTALL_GUI
    INSTALL_GUI="${INSTALL_GUI:-Y}"

    echo ""
    warn "This will install many packages and symlink configs."
    warn "Existing files will be backed up to $BACKUP_DIR"
    read -rp "Continue? [Y/n]: " CONFIRM
    CONFIRM="${CONFIRM:-Y}"
    [[ "${CONFIRM,,}" =~ ^(y|yes)$ ]] || { echo "Aborted."; exit 0; }

    # ── Run steps ─────────────────────────────────────────────────────────────
    bootstrap_paru
    clone_repos

    install_base
    install_terminal_tools
    install_fonts
    install_gtk_qt_themes

    case "$WM_CHOICE" in
        1) install_wm_bspwm ;;
        2) install_wm_hyprland ;;
        3) install_wm_i3 ;;
        4) install_wm_bspwm; install_wm_hyprland; install_wm_i3 ;;
        *) warn "Unknown choice, defaulting to Hyprland"; install_wm_hyprland ;;
    esac

    [[ "${INSTALL_GUI,,}" =~ ^(y|yes)$ ]] && install_gui_apps

    link_dotfiles
    install_scripts
    setup_shell
    setup_display
    enable_services
    setup_nvim
    apply_themes
    patch_alacritty_nord

    case "$WM_CHOICE" in
        1) setup_bspwm ;;
        2) setup_hyprland ;;
        3) : ;;
        4) setup_bspwm; setup_hyprland ;;
    esac

    print_summary
}

main "$@"
