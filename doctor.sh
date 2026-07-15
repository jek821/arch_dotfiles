#!/bin/bash
# doctor.sh — checks that everything these dotfiles depend on is present
# on this machine, and prints fix instructions for anything that isn't.
#
# Written for Arch Linux (uses pacman). Read-only: never installs anything
# itself, it only tells you the command to run.
#
# Usage: ./doctor.sh

set -u

PASS=0
WARN=0
FAIL=0
MISSING_PKGS=()

c_red()    { printf '\033[31m%s\033[0m' "$1"; }
c_yellow() { printf '\033[33m%s\033[0m' "$1"; }
c_green()  { printf '\033[32m%s\033[0m' "$1"; }
c_bold()   { printf '\033[1m%s\033[0m' "$1"; }

ok()   { PASS=$((PASS+1)); printf "  [%s] %s\n" "$(c_green "OK")" "$1"; }
warn() { WARN=$((WARN+1)); printf "  [%s] %s\n" "$(c_yellow "WARN")" "$1"; [ -n "${2:-}" ] && printf "         %s\n" "$2"; }
fail() { FAIL=$((FAIL+1)); printf "  [%s] %s\n" "$(c_red "FAIL")" "$1"; [ -n "${2:-}" ] && printf "         %s\n" "$2"; }

section() { printf "\n%s\n" "$(c_bold "$1")"; }

# check_pkg <label> <binary-or-empty> <pacman-pkg>
# Passes if the binary is on PATH, or (if no binary given, or binary not
# on PATH) if the pacman package is installed — some packages (e.g.
# hyprpolkitagent) don't put anything on PATH.
check_pkg() {
    local label="$1" bin="$2" pkg="$3"
    if [ -n "$bin" ] && command -v "$bin" >/dev/null 2>&1; then
        ok "$label ($bin)"
        return
    fi
    if pacman -Qq "$pkg" >/dev/null 2>&1; then
        ok "$label ($pkg installed)"
        return
    fi
    fail "$label — missing" "sudo pacman -S $pkg"
    MISSING_PKGS+=("$pkg")
}

echo "$(c_bold "dotfiles doctor") — checking dependencies for ~/.config"

# ---------------------------------------------------------------------------
section "Hyprland desktop (compositor, bar, notifications, launcher, lock)"
check_pkg "Hyprland"              Hyprland          hyprland
check_pkg "waybar"                waybar            waybar
check_pkg "mako"                  mako              mako
check_pkg "hypridle"              hypridle          hypridle
check_pkg "hyprlock"              hyprlock          hyprlock
check_pkg "hyprpaper"             hyprpaper         hyprpaper
check_pkg "hyprpolkitagent"       hyprpolkitagent   hyprpolkitagent
check_pkg "fuzzel (app launcher)" fuzzel            fuzzel
check_pkg "grim (screenshot)"     grim              grim
check_pkg "slurp (region select)" slurp             slurp
check_pkg "wl-copy (clipboard)"   wl-copy           wl-clipboard
check_pkg "brightnessctl"         brightnessctl     brightnessctl

# ---------------------------------------------------------------------------
section "Terminals & file manager"
check_pkg "kitty"                 kitty             kitty
check_pkg "foot"                  foot              foot
check_pkg "yazi"                  yazi              yazi

# ---------------------------------------------------------------------------
section "Audio / network / bluetooth"
check_pkg "wpctl (wireplumber)"   wpctl             wireplumber
check_pkg "pipewire"              pipewire          pipewire
check_pkg "pipewire-pulse"        ""                pipewire-pulse
check_pkg "pavucontrol"           pavucontrol       pavucontrol
check_pkg "nmtui (NetworkManager)" nmtui            networkmanager
check_pkg "bluetoothctl"          bluetoothctl      bluez-utils
check_pkg "bluetooth daemon"      ""                bluez

if command -v systemctl >/dev/null 2>&1; then
    if [ "$(systemctl is-enabled NetworkManager 2>/dev/null)" != "enabled" ]; then
        warn "NetworkManager.service not enabled" "sudo systemctl enable --now NetworkManager"
    else
        ok "NetworkManager.service enabled"
    fi
    if [ "$(systemctl is-enabled bluetooth 2>/dev/null)" != "enabled" ]; then
        warn "bluetooth.service not enabled" "sudo systemctl enable --now bluetooth"
    else
        ok "bluetooth.service enabled"
    fi
fi

for unit in \
    "systemd/user/sockets.target.wants/pipewire.socket" \
    "systemd/user/sockets.target.wants/pipewire-pulse.socket" \
    "systemd/user/pipewire.service.wants/wireplumber.service" \
    "systemd/user/default.target.wants/pipewire.service" \
    "systemd/user/default.target.wants/pipewire-pulse.service" \
    "systemd/user/pipewire-session-manager.service"; do
    path="$HOME/.config/$unit"
    if [ -L "$path" ] && [ ! -e "$path" ]; then
        warn "broken user-unit symlink: $unit" "Its target isn't installed — reinstall pipewire/pipewire-pulse/wireplumber."
    fi
done

# ---------------------------------------------------------------------------
section "Browser"
check_pkg "firefox" firefox firefox

# ---------------------------------------------------------------------------
section "dconf / GTK"
check_pkg "dconf" dconf dconf

# ---------------------------------------------------------------------------
section "Neovim + toolchain (nvim/ is its own repo, not part of this one)"
if [ -d "$HOME/.config/nvim" ] && [ -n "$(ls -A "$HOME/.config/nvim" 2>/dev/null)" ]; then
    ok "nvim config present at ~/.config/nvim"
else
    fail "nvim config missing" "git clone https://github.com/jek821/Cvim.git ~/.config/nvim"
fi

check_pkg "neovim" nvim neovim
if command -v nvim >/dev/null 2>&1; then
    nvim_ver=$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    nvim_major=${nvim_ver%%.*}
    nvim_minor=${nvim_ver##*.}
    if [ "$nvim_major" -gt 0 ] || { [ "$nvim_major" -eq 0 ] && [ "$nvim_minor" -ge 11 ]; }; then
        ok "neovim version $nvim_ver (>= 0.11 required)"
    else
        fail "neovim version $nvim_ver is too old (need >= 0.11)" "sudo pacman -S neovim"
    fi
fi

check_pkg "git"     git     git
check_pkg "gcc"     gcc     gcc
check_pkg "gdb"     gdb     gdb
check_pkg "python3" python3 python
check_pkg "node (Mason needs it for pyright)" node nodejs
check_pkg "ripgrep (Telescope live grep)" rg ripgrep

# clangd / pyright / clang-format / ruff / debugpy are installed
# automatically by Mason on first nvim launch — not checked here.

# ---------------------------------------------------------------------------
section "Claude Code CLI (mimeapps.list registers its URL handler)"
if command -v claude >/dev/null 2>&1; then
    ok "claude ($(command -v claude))"
else
    fail "claude CLI not installed" "curl -fsSL https://claude.ai/install.sh | bash   (or: npm install -g @anthropic-ai/claude-code)"
fi
if [ -f "$HOME/.local/share/applications/claude-code-url-handler.desktop" ]; then
    ok "claude-code-url-handler.desktop present"
else
    warn "claude-code-url-handler.desktop missing" "Reinstall/launch claude once to register the claude-cli:// URL handler used by mimeapps.list."
fi

# ---------------------------------------------------------------------------
section "Fonts"
if command -v fc-list >/dev/null 2>&1; then
    if fc-list | grep -qi "JetBrainsMono Nerd Font"; then
        ok "JetBrainsMono Nerd Font"
    else
        fail "JetBrainsMono Nerd Font not found" "sudo pacman -S ttf-jetbrains-mono-nerd && fc-cache -f"
        MISSING_PKGS+=("ttf-jetbrains-mono-nerd")
    fi
else
    warn "fontconfig (fc-list) not installed, can't check fonts" "sudo pacman -S fontconfig"
fi

# ---------------------------------------------------------------------------
section "Hardware-specific values (verify these match THIS machine)"

# LIBVA_DRIVER_NAME=iHD in hypr/hyprland.conf is Intel's VA-API driver.
if command -v lspci >/dev/null 2>&1; then
    gpu=$(lspci -nn 2>/dev/null | grep -iE "vga|3d|display")
    if echo "$gpu" | grep -qi intel; then
        ok "GPU looks Intel — LIBVA_DRIVER_NAME=iHD (hypr/hyprland.conf) is correct"
    elif echo "$gpu" | grep -qi amd; then
        warn "GPU looks AMD but hypr/hyprland.conf hardcodes LIBVA_DRIVER_NAME=iHD (Intel)" \
             "Change to 'env = LIBVA_DRIVER_NAME,radeonsi' (needs libva-mesa-driver), or remove the line."
    elif echo "$gpu" | grep -qi nvidia; then
        warn "GPU looks NVIDIA but hypr/hyprland.conf hardcodes LIBVA_DRIVER_NAME=iHD (Intel)" \
             "Change to 'env = LIBVA_DRIVER_NAME,nvidia' (needs nvidia-utils) or remove the line."
    else
        warn "Couldn't identify GPU vendor from lspci" "Manually verify LIBVA_DRIVER_NAME=iHD in hypr/hyprland.conf matches your GPU."
    fi
else
    warn "lspci not found, can't verify GPU vendor" "sudo pacman -S pciutils"
fi

# eDP-1 / HDMI* are hardcoded in hypr/edp-state.conf and hypr/lid-close.sh.
if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors >/dev/null 2>&1; then
    monitors=$(hyprctl monitors -j 2>/dev/null | grep -o '"name": *"[^"]*"' | cut -d'"' -f4)
    if echo "$monitors" | grep -q "^eDP-1$"; then
        ok "laptop panel is named eDP-1, matches hypr/edp-state.conf and lid-close.sh"
    else
        warn "no output named eDP-1 (found: $(echo "$monitors" | tr '\n' ' '))" \
             "Update the monitor name in hypr/edp-state.conf and hypr/lid-close.sh to match, or these lid-switch/monitor hooks won't work."
    fi
else
    warn "Hyprland not running (or hyprctl unavailable) — can't verify monitor names" \
         "Once logged in, run 'hyprctl monitors' and confirm the panel is named eDP-1 (used by hypr/edp-state.conf, hypr/lid-close.sh)."
fi

# switch:on:Lid Switch bind in hyprland.conf assumes a laptop lid switch exists.
if [ -r /proc/bus/input/devices ] && grep -qi "Lid Switch" /proc/bus/input/devices; then
    ok "lid switch device detected"
else
    warn "no lid switch device detected" "Expected on a desktop — the 'switch:on:Lid Switch' bind in hypr/hyprland.conf simply won't fire; harmless to leave in."
fi

# ---------------------------------------------------------------------------
section "Summary"
printf "%s passed, %s warnings, %s failed\n" "$(c_green "$PASS")" "$(c_yellow "$WARN")" "$(c_red "$FAIL")"

if [ "${#MISSING_PKGS[@]}" -gt 0 ]; then
    echo
    echo "Install all missing pacman packages in one shot:"
    printf "  sudo pacman -S %s\n" "${MISSING_PKGS[*]}"
fi

[ "$FAIL" -eq 0 ]
