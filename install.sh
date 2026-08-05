#!/bin/bash

# ==========================================================
# SKRYPT KONFIGURACYJNY WIZUALNYCH ASPEKTÓW KDE PLASMA
# ==========================================================

set -euo pipefail

# --- Kolory ---
INFO='\033[0;34m'
SUCCESS='\033[0;32m'
ERROR='\033[0;31m'
WARN='\033[0;33m'
NC='\033[0m'

log_info()  { echo -e "${INFO}==> $*${NC}"; }
log_ok()    { echo -e "${SUCCESS}==> $*${NC}"; }
log_err()   { echo -e "${ERROR}==> BŁĄD: $*${NC}" >&2; }
log_warn()  { echo -e "${WARN}==> UWAGA: $*${NC}"; }

# --- Zmienne ---
CURRENT_USER=$(whoami)
OLD_USER_PLACEHOLDER="bartek"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ==========================================================
# 1. WSTĘPNE SPRAWDZENIA I UPRAWNIENIA
# ==========================================================

# Upewnij się, że skrypt NIE jest uruchamiany jako root
if [[ "$EUID" -eq 0 ]]; then
    log_err "Nie uruchamiaj skryptu jako root. Uruchom jako zwykły użytkownik z dostępem do sudo."
    exit 1
fi

# Pułapka na błędy i zakończenie skryptu
trap 'log_err "Skrypt zakończył się błędem w linii $LINENO. Polecenie: $BASH_COMMAND"' ERR

# Tymczasowy wyjątek sudo (by nie pytało o hasło w trakcie wykonywania skryptu)
sudo -v
echo "$CURRENT_USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/99-temp-installer > /dev/null

# ==========================================================
# 2. KONFIGURACJA SYSTEMOWA (SUDO)
# ==========================================================
log_info "Przechodzę do konfiguracji systemowej (wymaga uprawnień)..."

# Konfiguracja awatara użytkownika
if [[ -f "$SCRIPT_DIR/piwo.png" ]]; then
    # Avatar dla Plasmy
    sudo mkdir -p /usr/share/plasma/avatars/
    sudo cp -f "$SCRIPT_DIR/piwo.png" /usr/share/plasma/avatars/piwo.png
    sudo chmod 644 /usr/share/plasma/avatars/piwo.png

    # Avatar dla Menedżera Logowania (SDDM / AccountsService)
    sudo mkdir -p /var/lib/AccountsService/icons/
    sudo cp -f "$SCRIPT_DIR/piwo.png" /var/lib/AccountsService/icons/"$CURRENT_USER"
    sudo chmod 644 /var/lib/AccountsService/icons/"$CURRENT_USER"

    # Rejestracja ikony w AccountsService
    ACCOUNTS_FILE="/var/lib/AccountsService/users/$CURRENT_USER"
    sudo mkdir -p /var/lib/AccountsService/users/

    if [[ ! -f "$ACCOUNTS_FILE" ]]; then
        echo -e "[User]\nIcon=/var/lib/AccountsService/icons/$CURRENT_USER" | sudo tee "$ACCOUNTS_FILE" > /dev/null
    else
        if sudo grep -q "^Icon=" "$ACCOUNTS_FILE"; then
            sudo sed -i "s|^Icon=.*|Icon=/var/lib/AccountsService/icons/$CURRENT_USER|" "$ACCOUNTS_FILE"
        else
            echo "Icon=/var/lib/AccountsService/icons/$CURRENT_USER" | sudo tee -a "$ACCOUNTS_FILE" > /dev/null
        fi
    fi
fi

# Zmiana ekranu logowania
if [[ -f "$SCRIPT_DIR/start.png" ]]; then
    sudo mkdir -p /usr/share/wallpapers
    sudo cp -f "$SCRIPT_DIR/start.png" /usr/share/wallpapers/start.png
    sudo chmod 644 /usr/share/wallpapers/start.png
fi

# Kopiowanie konfiguracji logowania
if [[ -f "$SCRIPT_DIR/plasmalogin.conf" ]]; then
    sudo cp -f "$SCRIPT_DIR/plasmalogin.conf" /etc/plasmalogin.conf
    sudo chmod 644 /etc/plasmalogin.conf
fi

log_info "Zmiana Tapety..."
TARGET_DIR="$HOME/.local/share/wallpapers"

# Upewnienie się, że katalog docelowy istnieje
mkdir -p "$TARGET_DIR"

# Kopiowanie tapety do katalogu domowego
if [[ -f "$SCRIPT_DIR/wallpaper.jpg" ]]; then
    cp -f "$SCRIPT_DIR/wallpaper.jpg" "$TARGET_DIR/wallpaper.jpg"
    log_ok "Skopiowano wallpaper.jpg do $TARGET_DIR/wallpaper.jpg"
else
    log_warn "Brak pliku wallpaper.jpg w katalogu skryptu."
fi

# Konfiguracja BleachBit dla roota
if [ -d "$SCRIPT_DIR/bleachbit" ]; then
    sudo mkdir -p /root/.config/bleachbit
    sudo cp -af "$SCRIPT_DIR/bleachbit/." /root/.config/bleachbit/
    log_ok "Skopiowano konfigurację BleachBit."
else
    log_warn "Folder $SCRIPT_DIR/bleachbit nie istnieje — pomijam."
fi

# ==========================================================
# 3. KONFIGURACJA WIZUALNA (KONTO UŻYTKOWNIKA)
# ==========================================================
log_info "Zatrzymywanie środowiska KDE, aby nie nadpisało naszych zmian..."
systemctl --user stop plasma-plasmashell.service 2>/dev/null || true
kquitapp6 plasmashell 2>/dev/null || killall -9 plasmashell 2>/dev/null || true
sleep 2

log_info "Kopiowanie plików konfiguracyjnych na uśpionym środowisku..."
if [[ -d "$SCRIPT_DIR/.config" ]]; then cp -af "$SCRIPT_DIR/.config/." ~/.config/; fi
if [[ -d "$SCRIPT_DIR/.local" ]]; then cp -af "$SCRIPT_DIR/.local/." ~/.local/; fi
if [[ -d "$SCRIPT_DIR/.icons" ]]; then cp -af "$SCRIPT_DIR/.icons/." ~/.icons/; fi

if [[ "$OLD_USER_PLACEHOLDER" != "$CURRENT_USER" ]]; then
    grep -rl --include="*.conf" --include="*.json" --include="*.ini" \
        "/home/$OLD_USER_PLACEHOLDER" ~/.config 2>/dev/null \
        | xargs -r sed -i "s|/home/$OLD_USER_PLACEHOLDER|/home/$CURRENT_USER|g" || true
fi

log_info "Czyszczenie pamięci podręcznej (Cache)..."
rm -rf ~/.cache/icon-cache.kcache ~/.cache/plasma* ~/.cache/ico*

log_info "Tworzenie wymuszenia tapety przy najbliższym starcie systemu..."
WALLPAPER_PATH="$HOME/.local/share/wallpapers/wallpaper.jpg"
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

# Tworzymy plik .desktop, który wstrzeliwuje tapetę bezpośrednio w działającą sesję
# Skrypt będzie próbował użyć plasma-apply-wallpaperimage. Jeśli operacja się uda (kod 0),
# plik usunie sam siebie z autostartu i przerwie pętlę.
cat > "$AUTOSTART_DIR/force-wallpaper.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Wymuszenie Tapety
Exec=bash -c 'for i in {1..30}; do plasma-apply-wallpaperimage "$WALLPAPER_PATH" && rm -f "$AUTOSTART_DIR/force-wallpaper.desktop" && break; sleep 2; done'
Hidden=false
NoDisplay=true
X-KDE-autostart-condition=
EOF

chmod +x "$AUTOSTART_DIR/force-wallpaper.desktop"
log_ok "Zadanie zmiany tapety zostało zakolejkowane do wykonania po restarcie."

# Odbudowa bazy systemowej
if command -v kbuildsycoca6 &>/dev/null; then
    kbuildsycoca6 --noincremental &>/dev/null || true
fi

# ==========================================================
# 4. ZAKOŃCZENIE I SPRZĄTANIE
# ==========================================================
log_info "Usuwam tymczasowe uprawnienia sudo..."
sudo rm -f /etc/sudoers.d/99-temp-installer

log_ok "KONFIGURACJA ZAKOŃCZONA SUKCESEM!"
sleep 3
systemctl reboot
