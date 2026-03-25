#!/bin/sh
# installdotfiles.sh — symlink dotfiles with preview and confirmation

BOLD="\033[1m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
RESET="\033[0m"

path=$(pwd)
skipped=0
linked=0
warned=0

# ── Package list ───────────────────────────────────────────────────────────────
# Inferred from every tool/app that has a config directory or dotfile above.
# pacman packages (official repos)
PACMAN_PKGS="
    alacritty
    base-devel
    bash
    blender
    broot
    bspwm
    calcurse
    chromium
    compton
    deadd-notification-center
    dolphin
    dunst
    gimp
    git
    gtk2
    gtk3
    hunter
    i3-wm
    i3blocks
    imwheel
    joplin
    kdenlive
    kitty
    lf
    mpv
    neofetch
    neovim
    newsboat
    nnn
    obs-studio
    pavucontrol
    pcmanfm
    pistol
    polybar
    powerline
    ranger
    starship
    sxhkd
    transmission-daemon
    vifm
    vscodium
    xorg-xmodmap
    xorg-xrdb
    yay
    zathura
    zathura-pdf-mupdf
    zsh
"

# AUR packages (installed via yay)
AUR_PKGS="
    bookmenu
    broot
    btops
    cfiles
    deadd-notification-center
    dharkael-git
    hunter
    imwheel
    joplin-desktop
    lf
    nnn
    pistol-git
    powerline-shell
    tabdmenu
    transmission-rfss
    twmn-git
    vscodium-bin
"

# ── Package install helpers ────────────────────────────────────────────────────

install_packages() {
    printf "${BOLD}${CYAN}Step 1: Installing packages${RESET}\n\n"

    # Check for pacman
    if ! command -v pacman >/dev/null 2>&1; then
        printf "${RED}  pacman not found — skipping package installation.${RESET}\n\n"
        return
    fi

    # Sync and install pacman packages
    printf "${BOLD}  pacman packages${RESET}\n"
    printf "  Syncing repos...\n"
    sudo pacman -Sy --noconfirm 2>&1 | tail -3

    pkgs_to_install=""
    for pkg in $PACMAN_PKGS; do
        [ -z "$pkg" ] && continue
        if pacman -Qi "$pkg" >/dev/null 2>&1; then
            printf "${CYAN}    already installed:${RESET} %s\n" "$pkg"
        else
            printf "${GREEN}    queued:${RESET} %s\n" "$pkg"
            pkgs_to_install="$pkgs_to_install $pkg"
        fi
    done

    if [ -n "$pkgs_to_install" ]; then
        printf "\n  Installing missing pacman packages...\n"
        sudo pacman -S --noconfirm --needed $pkgs_to_install
        if [ $? -ne 0 ]; then
            printf "${RED}  Some pacman packages failed to install. Continuing anyway.${RESET}\n"
        fi
    else
        printf "${GREEN}  All pacman packages already installed.${RESET}\n"
    fi

    # Check for yay (AUR helper)
    printf "\n${BOLD}  AUR packages (yay)${RESET}\n"
    if ! command -v yay >/dev/null 2>&1; then
        printf "${YELLOW}  yay not found — installing it first...${RESET}\n"
        git clone https://aur.archlinux.org/yay.git /tmp/yay-install
        (cd /tmp/yay-install && makepkg -si --noconfirm)
        rm -rf /tmp/yay-install
    fi

    if command -v yay >/dev/null 2>&1; then
        aur_to_install=""
        for pkg in $AUR_PKGS; do
            [ -z "$pkg" ] && continue
            if yay -Qi "$pkg" >/dev/null 2>&1; then
                printf "${CYAN}    already installed:${RESET} %s\n" "$pkg"
            else
                printf "${GREEN}    queued:${RESET} %s\n" "$pkg"
                aur_to_install="$aur_to_install $pkg"
            fi
        done

        if [ -n "$aur_to_install" ]; then
            printf "\n  Installing missing AUR packages...\n"
            yay -S --noconfirm --needed $aur_to_install
            if [ $? -ne 0 ]; then
                printf "${RED}  Some AUR packages failed to install. Continuing anyway.${RESET}\n"
            fi
        else
            printf "${GREEN}  All AUR packages already installed.${RESET}\n"
        fi
    else
        printf "${RED}  yay installation failed — skipping AUR packages.${RESET}\n"
    fi

    printf "\n${GREEN}${BOLD}  Package installation complete.${RESET}\n\n"
}

install_packages

# ── Helpers ────────────────────────────────────────────────────────────────────

# Register a symlink to be created: link_plan SRC DEST
# Stores entries in a newline-delimited string (POSIX sh, no arrays)
PLAN=""
add_plan() {
    src="$1"
    dest="$2"
    PLAN="${PLAN}${src}||${dest}
"
}

# Ensure a directory exists (non-sudo)
ensure_dir() {
    [ ! -d "$1" ] && mkdir -p "$1"
}

# ── Build the plan ─────────────────────────────────────────────────────────────

# Home directory dotfiles
add_plan "$path/.bash_profile"        "$HOME/.bash_profile"
add_plan "$path/.bashrc"              "$HOME/.bashrc"
add_plan "$path/.gitconfig"           "$HOME/.gitconfig"
add_plan "$path/.imwheelrc"           "$HOME/.imwheelrc"
add_plan "$path/.profile"             "$HOME/.profile"
add_plan "$path/config/nvim/init.vim" "$HOME/.vimrc"
add_plan "$path/.Xresources"          "$HOME/.Xresources"
add_plan "$path/.xinitrc"             "$HOME/.xinitrc"
add_plan "$path/.Xmodmap"             "$HOME/.Xmodmap"
add_plan "$path/.zcompdump"           "$HOME/.zcompdump"
add_plan "$path/.zprofile"            "$HOME/.zprofile"
add_plan "$path/.zshenv"              "$HOME/.zshenv"
add_plan "$path/.zshrc"               "$HOME/.zshrc"

# Config: individual files
add_plan "$path/config/GIMP/filters"                    "$HOME/.config/GIMP/2.10/filters"
add_plan "$path/config/GIMP/patterns"                   "$HOME/.config/GIMP/2.10/patterns"
add_plan "$path/config/joplin/keymap.json"              "$HOME/.config/joplin/keymap.json"
add_plan "$path/config/nnn/plugins"                     "$HOME/.config/nnn/plugins"
add_plan "$path/config/obs-studio/basic"                "$HOME/.config/obs-studio/basic"
add_plan "$path/config/transmission-daemon/settings.json" "$HOME/.config/transmission-daemon/settings.json"
add_plan "$path/config/VSCodium/keybindings.json"       "$HOME/.config/VSCodium/User/keybindings.json"
add_plan "$path/config/VSCodium/settings.json"          "$HOME/.config/VSCodium/User/settings.json"
add_plan "$path/config/compton.conf"                    "$HOME/.config/compton.conf"
add_plan "$path/config/dolphinrc"                       "$HOME/.config/dolphinrc"
add_plan "$path/config/kdeglobals"                      "$HOME/.config/kdeglobals"
add_plan "$path/config/kdenliverc"                      "$HOME/.config/kdenliverc"
add_plan "$path/config/kiorc"                           "$HOME/.config/kiorc"
add_plan "$path/config/kservicemenurc"                  "$HOME/.config/kservicemenurc"
add_plan "$path/config/ktrashrc"                        "$HOME/.config/ktrashrc"
add_plan "$path/config/mimeapps.list"                   "$HOME/.config/mimeapps.list"
add_plan "$path/config/pavucontrol.ini"                 "$HOME/.config/pavucontrol.ini"
add_plan "$path/config/starship.toml"                   "$HOME/.config/starship.toml"
add_plan "$path/config/user-dirs.dirs"                  "$HOME/.config/user-dirs.dirs"
add_plan "$path/config/wall.png"                        "$HOME/.config/wall.png"

# Config: whole directories (rm -rf existing before linking)
add_plan "$path/config/alacritty"         "$HOME/.config/alacritty"
add_plan "$path/config/blender"           "$HOME/.config/blender"
add_plan "$path/config/bookmenu"          "$HOME/.config/bookmenu"
add_plan "$path/config/broot"             "$HOME/.config/broot"
add_plan "$path/config/bspwm"             "$HOME/.config/bspwm"
add_plan "$path/config/btops"             "$HOME/.config/btops"
add_plan "$path/config/.calcurse"         "$HOME/.config/.calcurse"
add_plan "$path/config/cfiles"            "$HOME/.config/cfiles"
add_plan "$path/config/deadd"             "$HOME/.config/deadd"
add_plan "$path/config/Dharkael"          "$HOME/.config/Dharkael"
add_plan "$path/config/dunst"             "$HOME/.config/dunst"
add_plan "$path/config/gtk-2.0"           "$HOME/.config/gtk-2.0"
add_plan "$path/config/gtk-3.0"           "$HOME/.config/gtk-3.0"
add_plan "$path/config/hunter"            "$HOME/.config/hunter"
add_plan "$path/config/i3"                "$HOME/.config/i3"
add_plan "$path/config/i3blocks"          "$HOME/.config/i3blocks"
add_plan "$path/config/import"            "$HOME/.config/import"
add_plan "$path/config/kitty"             "$HOME/.config/kitty"
add_plan "$path/config/lf"                "$HOME/.config/lf"
add_plan "$path/config/mpv"               "$HOME/.config/mpv"
add_plan "$path/config/neofetch"          "$HOME/.config/neofetch"
add_plan "$path/config/newsboat"          "$HOME/.config/newsboat"
add_plan "$path/config/nvim"              "$HOME/.config/nvim"
add_plan "$path/config/pcmanfm"           "$HOME/.config/pcmanfm"
add_plan "$path/config/pistol"            "$HOME/.config/pistol"
add_plan "$path/config/polybar"           "$HOME/.config/polybar"
add_plan "$path/config/powerline-shell"   "$HOME/.config/powerline-shell"
add_plan "$path/config/ranger"            "$HOME/.config/ranger"
add_plan "$path/config/search"            "$HOME/.config/search"
add_plan "$path/config/shellconfig"       "$HOME/.config/shellconfig"
add_plan "$path/config/sxhkd"             "$HOME/.config/sxhkd"
add_plan "$path/config/tabdmenu"          "$HOME/.config/tabdmenu"
add_plan "$path/config/transmission-rfss" "$HOME/.config/transmission-rfss"
add_plan "$path/config/twmn"              "$HOME/.config/twmn"
add_plan "$path/config/vifm"              "$HOME/.config/vifm"
add_plan "$path/config/yay"               "$HOME/.config/yay"
add_plan "$path/config/zathura"           "$HOME/.config/zathura"

# Local share
add_plan "$path/.local/share/applications" "$HOME/.local/share/applications"
add_plan "$path/.local/share/fonts"        "$HOME/.local/share/fonts"

# Cron (sudo)
add_plan "$path/cron" "/var/spool/cron"

# ── Print preview ──────────────────────────────────────────────────────────────

printf "${BOLD}${CYAN}Step 2: Dotfiles symlink preview${RESET}\n"
printf "${CYAN}Source directory: ${RESET}%s\n\n" "$path"
printf "%-55s  %s\n" "SOURCE" "DESTINATION"
printf "%-55s  %s\n" "------" "-----------"

IFS_BAK="$IFS"
IFS="
"
for entry in $PLAN; do
    [ -z "$entry" ] && continue
    src="${entry%%||*}"
    dest="${entry##*||}"
    if [ ! -e "$src" ] && [ ! -L "$src" ]; then
        printf "${YELLOW}%-55s${RESET}  %s  ${YELLOW}[MISSING — will skip]${RESET}\n" "$src" "$dest"
    elif [ -e "$dest" ] || [ -L "$dest" ]; then
        printf "${GREEN}%-55s${RESET}  %s  ${CYAN}[will replace]${RESET}\n" "$src" "$dest"
    else
        printf "${GREEN}%-55s${RESET}  %s  [new]\n" "$src" "$dest"
    fi
done
IFS="$IFS_BAK"

printf "\n"

# ── Confirm ────────────────────────────────────────────────────────────────────

printf "${BOLD}Proceed with installation? [y/N] ${RESET}"
read answer
case "$answer" in
    [yY][eE][sS]|[yY]) ;;
    *)
        printf "${RED}Aborted.${RESET}\n"
        exit 0
        ;;
esac

printf "\n${BOLD}Step 2: Installing symlinks...${RESET}\n\n"

# ── Apply ──────────────────────────────────────────────────────────────────────

do_link() {
    src="$1"
    dest="$2"
    use_sudo="$3"   # "sudo" or ""

    # Check source exists
    if [ ! -e "$src" ] && [ ! -L "$src" ]; then
        printf "${YELLOW}  SKIP${RESET}    %s  (source not found)\n" "$src"
        skipped=$((skipped + 1))
        return
    fi

    # Ensure parent directory exists
    parent=$(dirname "$dest")
    if [ "$use_sudo" = "sudo" ]; then
        sudo mkdir -p "$parent" 2>/dev/null
    else
        mkdir -p "$parent" 2>/dev/null
    fi

    # Remove existing destination if it's a directory symlink or regular dir
    if [ -d "$dest" ] && [ ! -L "$dest" ]; then
        if [ "$use_sudo" = "sudo" ]; then
            sudo rm -rf "$dest"
        else
            rm -rf "$dest"
        fi
    fi

    # Create symlink
    if [ "$use_sudo" = "sudo" ]; then
        sudo ln -sf "$src" "$dest"
    else
        ln -sf "$src" "$dest"
    fi

    if [ $? -eq 0 ]; then
        printf "${GREEN}  LINKED${RESET}  %s\n        → %s\n" "$src" "$dest"
        linked=$((linked + 1))
    else
        printf "${RED}  FAILED${RESET}  %s → %s\n" "$src" "$dest"
        warned=$((warned + 1))
    fi
}

# ── Home dotfiles ──────────────────────────────────────────────────────────────
printf "${BOLD}Home directory${RESET}\n"
do_link "$path/.bash_profile"        "$HOME/.bash_profile"
do_link "$path/.bashrc"              "$HOME/.bashrc"
do_link "$path/.gitconfig"           "$HOME/.gitconfig"
do_link "$path/.imwheelrc"           "$HOME/.imwheelrc"
do_link "$path/.profile"             "$HOME/.profile"
do_link "$path/config/nvim/init.vim" "$HOME/.vimrc"
do_link "$path/.Xresources"          "$HOME/.Xresources"
do_link "$path/.xinitrc"             "$HOME/.xinitrc"
do_link "$path/.Xmodmap"             "$HOME/.Xmodmap"
do_link "$path/.zcompdump"           "$HOME/.zcompdump"
do_link "$path/.zprofile"            "$HOME/.zprofile"
do_link "$path/.zshenv"              "$HOME/.zshenv"
do_link "$path/.zshrc"               "$HOME/.zshrc"

# ── Config: ensure base dirs ───────────────────────────────────────────────────
printf "\n${BOLD}Config directory${RESET}\n"
ensure_dir "$HOME/.config"
ensure_dir "$HOME/.config/GIMP/2.10"
ensure_dir "$HOME/.config/joplin"
ensure_dir "$HOME/.config/nnn"
ensure_dir "$HOME/.config/obs-studio"
ensure_dir "$HOME/.config/transmission-daemon"
ensure_dir "$HOME/.config/VSCodium/User"

do_link "$path/config/GIMP/filters"                     "$HOME/.config/GIMP/2.10/filters"
do_link "$path/config/GIMP/patterns"                    "$HOME/.config/GIMP/2.10/patterns"
do_link "$path/config/joplin/keymap.json"               "$HOME/.config/joplin/keymap.json"
do_link "$path/config/nnn/plugins"                      "$HOME/.config/nnn/plugins"
do_link "$path/config/obs-studio/basic"                 "$HOME/.config/obs-studio/basic"
do_link "$path/config/transmission-daemon/settings.json" "$HOME/.config/transmission-daemon/settings.json"
do_link "$path/config/VSCodium/keybindings.json"        "$HOME/.config/VSCodium/User/keybindings.json"
do_link "$path/config/VSCodium/settings.json"           "$HOME/.config/VSCodium/User/settings.json"
do_link "$path/config/alacritty"         "$HOME/.config/alacritty"
do_link "$path/config/blender"           "$HOME/.config/blender"
do_link "$path/config/bookmenu"          "$HOME/.config/bookmenu"
do_link "$path/config/broot"             "$HOME/.config/broot"
do_link "$path/config/bspwm"             "$HOME/.config/bspwm"
do_link "$path/config/btops"             "$HOME/.config/btops"
do_link "$path/config/.calcurse"         "$HOME/.config/.calcurse"
do_link "$path/config/cfiles"            "$HOME/.config/cfiles"
do_link "$path/config/deadd"             "$HOME/.config/deadd"
do_link "$path/config/Dharkael"          "$HOME/.config/Dharkael"
do_link "$path/config/dunst"             "$HOME/.config/dunst"
do_link "$path/config/gtk-2.0"           "$HOME/.config/gtk-2.0"
do_link "$path/config/gtk-3.0"           "$HOME/.config/gtk-3.0"
do_link "$path/config/hunter"            "$HOME/.config/hunter"
do_link "$path/config/i3"                "$HOME/.config/i3"
do_link "$path/config/i3blocks"          "$HOME/.config/i3blocks"
do_link "$path/config/import"            "$HOME/.config/import"
do_link "$path/config/kitty"             "$HOME/.config/kitty"
do_link "$path/config/lf"                "$HOME/.config/lf"
do_link "$path/config/mpv"               "$HOME/.config/mpv"
do_link "$path/config/neofetch"          "$HOME/.config/neofetch"
do_link "$path/config/newsboat"          "$HOME/.config/newsboat"
do_link "$path/config/nvim"              "$HOME/.config/nvim"
do_link "$path/config/pcmanfm"           "$HOME/.config/pcmanfm"
do_link "$path/config/pistol"            "$HOME/.config/pistol"
do_link "$path/config/polybar"           "$HOME/.config/polybar"
do_link "$path/config/powerline-shell"   "$HOME/.config/powerline-shell"
do_link "$path/config/ranger"            "$HOME/.config/ranger"
do_link "$path/config/search"            "$HOME/.config/search"
do_link "$path/config/shellconfig"       "$HOME/.config/shellconfig"
do_link "$path/config/sxhkd"             "$HOME/.config/sxhkd"
do_link "$path/config/tabdmenu"          "$HOME/.config/tabdmenu"
do_link "$path/config/transmission-rfss" "$HOME/.config/transmission-rfss"
do_link "$path/config/twmn"              "$HOME/.config/twmn"
do_link "$path/config/vifm"              "$HOME/.config/vifm"
do_link "$path/config/yay"               "$HOME/.config/yay"
do_link "$path/config/zathura"           "$HOME/.config/zathura"
do_link "$path/config/compton.conf"      "$HOME/.config/compton.conf"
do_link "$path/config/dolphinrc"         "$HOME/.config/dolphinrc"
do_link "$path/config/kdeglobals"        "$HOME/.config/kdeglobals"
do_link "$path/config/kdenliverc"        "$HOME/.config/kdenliverc"
do_link "$path/config/kiorc"             "$HOME/.config/kiorc"
do_link "$path/config/kservicemenurc"    "$HOME/.config/kservicemenurc"
do_link "$path/config/ktrashrc"          "$HOME/.config/ktrashrc"
do_link "$path/config/mimeapps.list"     "$HOME/.config/mimeapps.list"
do_link "$path/config/pavucontrol.ini"   "$HOME/.config/pavucontrol.ini"
do_link "$path/config/starship.toml"     "$HOME/.config/starship.toml"
do_link "$path/config/user-dirs.dirs"    "$HOME/.config/user-dirs.dirs"
do_link "$path/config/wall.png"          "$HOME/.config/wall.png"

# ── Local share ────────────────────────────────────────────────────────────────
printf "\n${BOLD}Local share${RESET}\n"
ensure_dir "$HOME/.local/share"
do_link "$path/.local/share/applications" "$HOME/.local/share/applications"
do_link "$path/.local/share/fonts"        "$HOME/.local/share/fonts"

# ── Cron (sudo) ────────────────────────────────────────────────────────────────
printf "\n${BOLD}Cron (requires sudo)${RESET}\n"
do_link "$path/cron" "/var/spool/cron" "sudo"

# ── Summary ────────────────────────────────────────────────────────────────────
printf "\n${BOLD}──────────────────────────────────────────${RESET}\n"
printf "${GREEN}  Linked:  %d${RESET}\n" "$linked"
printf "${YELLOW}  Skipped: %d${RESET} (source missing)\n" "$skipped"
printf "${RED}  Failed:  %d${RESET}\n" "$warned"
printf "${BOLD}──────────────────────────────────────────${RESET}\n"
