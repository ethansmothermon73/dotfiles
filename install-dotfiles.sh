#!/usr/bin/env bash
# ==============================================================================
#  install-dotfiles.sh
#  Installs cristianpb/dotfiles on Arch Linux or Ubuntu
#  - Clones the repo and uses GNU stow to symlink every config
#  - Patches i3 config: removes the built-in bar block, launches polybar instead
#  - Installs all required packages (pacman / apt)
# ==============================================================================

set -euo pipefail

# ── colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERR]${RESET}   $*" >&2; }
header()  { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════${RESET}"; \
            echo -e "${BOLD}${CYAN}  $*${RESET}"; \
            echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"; }

# ── detect OS ────────────────────────────────────────────────────────────────
detect_os() {
    if command -v pacman &>/dev/null; then
        OS="arch"
    elif command -v apt-get &>/dev/null; then
        OS="ubuntu"
    else
        error "Unsupported OS. Only Arch Linux and Ubuntu/Debian are supported."
        exit 1
    fi
    success "Detected OS: ${OS}"
}

# ── package lists ─────────────────────────────────────────────────────────────
ARCH_PACKAGES=(
    # core / build
    git stow base-devel curl wget unzip

    # shell
    bash bash-completion zsh

    # terminal & multiplexer
    tmux

    # window manager & display
    xorg-server xorg-xinit xorg-xrandr xorg-xset xorg-xrdb
    i3-wm i3lock i3status dmenu
    polybar
    compton picom          # compton is legacy name; picom is the fork
    dunst
    feh

    # fonts (needed by polybar / termite)
    ttf-font-awesome noto-fonts noto-fonts-emoji
    ttf-dejavu ttf-liberation
    terminus-font

    # terminal emulators
    termite

    # editors
    neovim vim python-pynvim nodejs npm

    # file manager / viewer
    ranger nsxiv

    # media
    mpd ncmpcpp

    # email
    mutt notmuch isync

    # misc utilities
    ripgrep fd bat htop
)

UBUNTU_PACKAGES=(
    # core / build
    git stow build-essential curl wget unzip software-properties-common

    # shell
    bash bash-completion zsh

    # terminal & multiplexer
    tmux

    # window manager & display
    xorg xinit x11-xserver-utils
    i3 i3lock i3status dmenu
    dunst feh compton

    # fonts
    fonts-font-awesome fonts-noto fonts-noto-color-emoji
    fonts-dejavu fonts-liberation

    # terminal emulators
    termite

    # editors
    neovim vim python3-pynvim nodejs npm

    # file manager / viewer
    ranger

    # media
    mpd ncmpcpp

    # email
    mutt notmuch isync

    # misc utilities
    ripgrep fd-find bat htop
)

# ── install helpers ────────────────────────────────────────────────────────────
install_arch_packages() {
    header "Installing Arch packages"
    sudo pacman -Syu --noconfirm
    for pkg in "${ARCH_PACKAGES[@]}"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            info "Already installed: $pkg"
        else
            info "Installing: $pkg"
            sudo pacman -S --noconfirm --needed "$pkg" || warn "Could not install $pkg (may be AUR-only)"
        fi
    done
}

install_ubuntu_packages() {
    header "Installing Ubuntu packages"
    sudo apt-get update -y
    # neovim stable PPA
    if ! apt-cache show neovim | grep -q "Version: 0\.[89]\|Version: [1-9]" 2>/dev/null; then
        info "Adding neovim unstable PPA for a recent version..."
        sudo add-apt-repository -y ppa:neovim-ppa/unstable || true
        sudo apt-get update -y
    fi
    for pkg in "${UBUNTU_PACKAGES[@]}"; do
        if dpkg -l "$pkg" &>/dev/null; then
            info "Already installed: $pkg"
        else
            info "Installing: $pkg"
            sudo apt-get install -y "$pkg" || warn "Could not install $pkg"
        fi
    done
}

install_polybar_ubuntu() {
    # polybar is not in standard Ubuntu repos; build from source or use PPA
    if command -v polybar &>/dev/null; then
        success "polybar already installed"
        return
    fi
    header "Building polybar from source (Ubuntu)"
    sudo apt-get install -y \
        cmake cmake-data pkg-config python3-sphinx python3-packaging \
        libcairo2-dev libxcb1-dev libxcb-util0-dev libxcb-randr0-dev \
        libxcb-composite0-dev python3-xcbgen xcb-proto libxcb-image0-dev \
        libxcb-ewmh-dev libxcb-icccm4-dev libxcb-xkb-dev libxcb-xrm-dev \
        libxcb-cursor-dev libasound2-dev libpulse-dev libjsoncpp-dev \
        libmpdclient-dev libcurl4-openssl-dev libnl-genl-3-dev \
        libuv1-dev libwireplumber-0.4-dev libpipewire-0.3-dev || true

    TMP_POLY=$(mktemp -d)
    git clone --recursive https://github.com/polybar/polybar "$TMP_POLY/polybar"
    cmake -S "$TMP_POLY/polybar" -B "$TMP_POLY/polybar/build" \
          -DCMAKE_BUILD_TYPE=Release \
          -DENABLE_ALSA=ON -DENABLE_PULSEAUDIO=ON
    cmake --build "$TMP_POLY/polybar/build" -- -j"$(nproc)"
    sudo cmake --install "$TMP_POLY/polybar/build"
    rm -rf "$TMP_POLY"
    success "polybar installed"
}

install_yay_aur() {
    if [[ "$OS" == "arch" ]] && ! command -v yay &>/dev/null; then
        header "Installing yay (AUR helper)"
        TMP_YAY=$(mktemp -d)
        git clone https://aur.archlinux.org/yay.git "$TMP_YAY"
        (cd "$TMP_YAY" && makepkg -si --noconfirm)
        rm -rf "$TMP_YAY"
        success "yay installed"
    fi
}

# ── clone dotfiles ────────────────────────────────────────────────────────────
DOTFILES_DIR="$HOME/.dotfiles"

clone_dotfiles() {
    header "Cloning dotfiles"
    if [[ -d "$DOTFILES_DIR/.git" ]]; then
        info "Dotfiles already cloned — pulling latest..."
        git -C "$DOTFILES_DIR" pull --rebase
    else
        git clone https://github.com/cristianpb/dotfiles "$DOTFILES_DIR"
        success "Cloned to $DOTFILES_DIR"
    fi
}

# ── stow all packages ─────────────────────────────────────────────────────────
#
#  Pre-flight conflict resolution strategy:
#   1. Simulate stow (--no) to collect every conflict path
#   2. For each conflicting target:
#        a. Absolute symlink pointing elsewhere  → remove it
#        b. Relative symlink owned by a different stow dir → remove it
#        c. Plain file / directory not owned by stow       → back it up (.bak)
#   3. Run the real stow now that the path is clear
#
stow_dotfiles() {
    header "Symlinking configs with stow"
    cd "$DOTFILES_DIR"

    SKIP=(".git" "." "..")
    BACKUP_DIR="$HOME/.dotfiles-conflicts-backup-$(date +%Y%m%d_%H%M%S)"

    resolve_conflicts() {
        local pkg="$1"

        # Dry-run: capture stderr which contains conflict/warning lines
        local sim_out
        sim_out=$(stow --simulate --restow --target="$HOME" "$pkg" 2>&1 || true)

        # Pull out every conflicting target path (relative to $HOME)
        # stow prints lines like:
        #   * existing target is not a link: .bashrc
        #   * existing target is neither a link nor a directory: .bashrc
        #   * existing target is not owned by stow: .config/nvim
        local conflicts
        conflicts=$(echo "$sim_out" | grep -oP '(?<=: )[^\s].*' | grep -v '^$' || true)

        if [[ -z "$conflicts" ]]; then
            return 0   # nothing to fix
        fi

        mkdir -p "$BACKUP_DIR"
        warn "Resolving conflicts for package '$pkg':"

        while IFS= read -r rel; do
            local target="$HOME/$rel"

            [[ -z "$rel" ]] && continue

            if [[ -L "$target" ]]; then
                # It's a symlink — absolute or owned by a foreign stow dir
                local dest
                dest=$(readlink "$target")
                warn "  Removing conflicting symlink: $target -> $dest"
                rm -f "$target"

            elif [[ -f "$target" ]]; then
                # Plain file — back it up
                local bak="$BACKUP_DIR/$rel"
                mkdir -p "$(dirname "$bak")"
                warn "  Backing up plain file: $target → $bak"
                mv "$target" "$bak"

            elif [[ -d "$target" ]]; then
                # Directory not owned by stow — back it up
                local bak="$BACKUP_DIR/$rel"
                mkdir -p "$(dirname "$bak")"
                warn "  Backing up directory: $target → $bak"
                mv "$target" "$bak"
            fi
        done <<< "$conflicts"
    }

    for d in */; do
        pkg="${d%/}"
        [[ " ${SKIP[*]} " =~ " ${pkg} " ]] && continue
        [[ ! -d "$pkg" ]] && continue

        info "Stowing: $pkg"

        # First attempt — clean run
        if stow --restow --target="$HOME" "$pkg" 2>/dev/null; then
            continue
        fi

        # Second attempt — resolve conflicts then retry
        warn "  Conflict detected for '$pkg' — auto-resolving..."
        resolve_conflicts "$pkg"

        if stow --restow --target="$HOME" "$pkg" 2>/dev/null; then
            success "  '$pkg' stowed after conflict resolution"
        else
            # Last resort: --adopt (pull existing files into dotfiles dir)
            # then reset to repo version so our configs win
            warn "  Falling back to --adopt for '$pkg'..."
            stow --adopt --restow --target="$HOME" "$pkg" 2>/dev/null || true
            git -C "$DOTFILES_DIR" checkout -- "$pkg" 2>/dev/null || true
            success "  '$pkg' stowed via adopt+reset"
        fi
    done

    if [[ -d "$BACKUP_DIR" ]]; then
        info "Conflicting originals backed up to: $BACKUP_DIR"
    fi

    success "All packages stowed"
}

# ── patch i3 config: replace bar block with polybar exec ─────────────────────
patch_i3_config() {
    header "Patching i3 config → replace built-in bar with polybar"

    I3_CFG="$HOME/.config/i3/config"

    if [[ ! -f "$I3_CFG" ]]; then
        warn "i3 config not found at $I3_CFG — skipping patch"
        return
    fi

    # Backup original
    cp "$I3_CFG" "${I3_CFG}.bak"
    info "Backup saved to ${I3_CFG}.bak"

    # 1. Remove the entire `bar { ... }` block (handles multi-line)
    python3 - "$I3_CFG" <<'PYEOF'
import re, sys

with open(sys.argv[1], 'r') as f:
    content = f.read()

# Remove bar { ... } block (greedy multi-line)
cleaned = re.sub(r'\nbar\s*\{[^}]*\}', '', content, flags=re.DOTALL)

with open(sys.argv[1], 'w') as f:
    f.write(cleaned)

print("  Removed built-in bar block")
PYEOF

    # 2. Ensure polybar launch script is exec'd on i3 startup
    if ! grep -q "polybar" "$I3_CFG"; then
        cat >> "$I3_CFG" <<'I3APPEND'

# ── Polybar (replaces i3bar) ──────────────────────────────────────────────────
exec_always --no-startup-id $HOME/.config/polybar/launch.sh
I3APPEND
        success "Added polybar exec_always to i3 config"
    else
        info "polybar already referenced in i3 config"
    fi
}

# ── create polybar launch.sh if absent ───────────────────────────────────────
ensure_polybar_launch() {
    LAUNCH="$HOME/.config/polybar/launch.sh"

    if [[ -f "$LAUNCH" ]]; then
        success "polybar launch.sh already exists"
    else
        header "Creating polybar launch.sh"
        mkdir -p "$HOME/.config/polybar"
        cat > "$LAUNCH" <<'LAUNCH_SH'
#!/usr/bin/env bash
# Kill any running polybar instances
killall -q polybar || true

# Wait until processes have been shut down
while pgrep -u "$UID" -x polybar > /dev/null; do sleep 0.5; done

# Launch polybar on every connected monitor
if type "xrandr" &>/dev/null; then
    for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
        MONITOR=$m polybar --reload main &
    done
else
    polybar --reload main &
fi

echo "Polybar launched"
LAUNCH_SH
        chmod +x "$LAUNCH"
        success "Created $LAUNCH"
    fi
}

# ── neovim plugin bootstrap ───────────────────────────────────────────────────
setup_neovim() {
    header "Setting up Neovim"

    NVIM_CFG="$HOME/.config/nvim"

    # Detect plugin manager used by the dotfiles (vim-plug is most common)
    if [[ -f "$NVIM_CFG/init.vim" ]] || [[ -f "$NVIM_CFG/init.lua" ]]; then
        # Install vim-plug if init.vim references it
        if grep -rq "plug#begin\|vim-plug\|Plug '" "$NVIM_CFG" 2>/dev/null; then
            PLUG_PATH="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload/plug.vim"
            if [[ ! -f "$PLUG_PATH" ]]; then
                info "Installing vim-plug..."
                curl -fLo "$PLUG_PATH" --create-dirs \
                    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
            fi
            info "Running PlugInstall (headless)..."
            nvim --headless +PlugInstall +qall 2>/dev/null || warn "PlugInstall had warnings (normal on first run)"
        fi

        # packer.nvim
        if grep -rq "packer\|use(" "$NVIM_CFG" 2>/dev/null; then
            PACKER_PATH="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/packer/start/packer.nvim"
            if [[ ! -d "$PACKER_PATH" ]]; then
                info "Installing packer.nvim..."
                git clone --depth 1 https://github.com/wbthomason/packer.nvim "$PACKER_PATH"
            fi
            info "Running PackerSync (headless)..."
            nvim --headless -c "autocmd User PackerComplete quitall" -c "PackerSync" 2>/dev/null || \
                warn "PackerSync had warnings (normal on first run)"
        fi

        success "Neovim plugins bootstrapped"
    else
        warn "No Neovim config found at $NVIM_CFG — skipping plugin install"
    fi
}

# ── bash / zsh config ─────────────────────────────────────────────────────────
setup_shell() {
    header "Shell config"
    # Source .bashrc if it exists and we're in bash
    if [[ -f "$HOME/.bashrc" ]]; then
        info ".bashrc is in place"
    fi
    if [[ -f "$HOME/.bash_aliases" ]]; then
        info ".bash_aliases is in place"
    fi
    success "Shell configs linked"
}

# ── xorg / colour / theme ─────────────────────────────────────────────────────
setup_xorg() {
    header "Xorg / colour config"
    if [[ -f "$HOME/.Xresources" ]]; then
        xrdb -merge "$HOME/.Xresources" 2>/dev/null && success "Merged .Xresources" \
            || warn "xrdb not available (maybe not in an X session)"
    fi
}

# ── compton / picom compositor ────────────────────────────────────────────────
setup_compositor() {
    header "Compositor"
    if [[ -f "$HOME/.config/compton.conf" ]] || [[ -f "$HOME/.compton.conf" ]]; then
        success "compton/picom config in place"
    fi
}

# ── dunst notification daemon ─────────────────────────────────────────────────
setup_dunst() {
    header "Dunst"
    if [[ -f "$HOME/.config/dunst/dunstrc" ]]; then
        success "dunstrc in place"
    fi
}

# ── fonts ─────────────────────────────────────────────────────────────────────
setup_fonts() {
    header "Refreshing font cache"
    fc-cache -fv &>/dev/null && success "Font cache refreshed" || warn "fc-cache failed"
}

# ── git config ────────────────────────────────────────────────────────────────
setup_git() {
    header "Git config"
    if [[ -f "$HOME/.gitconfig" ]]; then
        success ".gitconfig is in place"
        # Optionally prompt for identity
        if ! git config --global user.email &>/dev/null; then
            warn "Git user.email not set. Run: git config --global user.email 'you@example.com'"
        fi
    fi
}

# ── tmux plugin manager ───────────────────────────────────────────────────────
setup_tmux() {
    header "Tmux"
    TPM="$HOME/.tmux/plugins/tpm"
    if [[ -f "$HOME/.tmux.conf" ]] && [[ ! -d "$TPM" ]]; then
        info "Installing tmux plugin manager..."
        git clone https://github.com/tmux-plugins/tpm "$TPM"
        success "TPM installed — press prefix+I inside tmux to install plugins"
    elif [[ -d "$TPM" ]]; then
        success "TPM already present"
    fi
}

# ── ranger devicons / image preview ──────────────────────────────────────────
setup_ranger() {
    header "Ranger"
    if [[ -d "$HOME/.config/ranger" ]]; then
        # Generate default config if not present
        if ! [[ -f "$HOME/.config/ranger/rc.conf" ]]; then
            ranger --copy-config=all 2>/dev/null || true
        fi
        success "Ranger config in place"
    fi
}

# ── summary ───────────────────────────────────────────────────────────────────
print_summary() {
    echo ""
    echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${GREEN}║          Installation complete! 🎉                   ║${RESET}"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  ${BOLD}Dotfiles location:${RESET}  $DOTFILES_DIR"
    echo -e "  ${BOLD}i3 config:${RESET}          ~/.config/i3/config"
    echo -e "  ${BOLD}Polybar launch:${RESET}     ~/.config/polybar/launch.sh"
    echo -e "  ${BOLD}Neovim config:${RESET}      ~/.config/nvim/"
    echo ""
    echo -e "  ${CYAN}Next steps:${RESET}"
    echo -e "  1. Log out and select i3 from your display manager"
    echo -e "  2. Open nvim and run  ${BOLD}:PlugInstall${RESET}  (or ${BOLD}:PackerSync${RESET}) if needed"
    echo -e "  3. Inside tmux press  ${BOLD}prefix + I${RESET}  to install tmux plugins"
    echo -e "  4. Customise ~/.config/polybar/config  to match your monitors"
    echo -e "  5. Update git identity:"
    echo -e "       git config --global user.name  'Your Name'"
    echo -e "       git config --global user.email 'you@example.com'"
    echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
#  MAIN
# ══════════════════════════════════════════════════════════════════════════════
main() {
    echo -e "${BOLD}${CYAN}"
    echo "  ██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗"
    echo "  ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝"
    echo "  ██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗"
    echo "  ██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║"
    echo "  ██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║"
    echo "  ╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝"
    echo -e "${RESET}"
    echo -e "  ${BOLD}cristanpb/dotfiles installer${RESET} — Arch & Ubuntu"
    echo ""

    detect_os

    # ── install packages ──────────────────────────────────────────────────────
    case "$OS" in
        arch)
            install_arch_packages
            install_yay_aur
            # AUR packages that aren't in extra/community
            if command -v yay &>/dev/null; then
                info "Installing AUR extras via yay..."
                yay -S --noconfirm --needed \
                    termite nerd-fonts-complete 2>/dev/null || \
                    warn "Some AUR packages failed — continuing"
            fi
            ;;
        ubuntu)
            install_ubuntu_packages
            install_polybar_ubuntu
            ;;
    esac

    # ── dotfiles ──────────────────────────────────────────────────────────────
    clone_dotfiles
    stow_dotfiles

    # ── i3 + polybar ─────────────────────────────────────────────────────────
    patch_i3_config
    ensure_polybar_launch

    # ── per-app setup ─────────────────────────────────────────────────────────
    setup_neovim
    setup_shell
    setup_xorg
    setup_compositor
    setup_dunst
    setup_fonts
    setup_git
    setup_tmux
    setup_ranger

    print_summary
}

main "$@"
