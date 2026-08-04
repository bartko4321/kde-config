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
kquitapp6 plasmashell 2>/dev/null || kquitapp5 plasmashell 2>/dev/null || killall plasmashell 2>/dev/null || true
sleep 2

log_info "Kopiowanie konfiguracji użytkownika na uśpionym środowisku..."

# Kopiowanie struktury zachowując uprawnienia i ukryte pliki
[[ -d "$SCRIPT_DIR/.config" ]] && cp -af "$SCRIPT_DIR/.config/." ~/.config/
[[ -d "$SCRIPT_DIR/.local" ]] && cp -af "$SCRIPT_DIR/.local/." ~/.local/
[[ -d "$SCRIPT_DIR/.icons" ]] && cp -af "$SCRIPT_DIR/.icons/." ~/.icons/

# Zamiana ścieżek tylko w plikach tekstowych (.conf, .json, .ini)
if [[ "$OLD_USER_PLACEHOLDER" != "$CURRENT_USER" ]]; then
    find ~/.config -type f \( -name "*.conf" -o -name "*.json" -o -name "*.ini" \) \
        -exec sed -i "s|/home/$OLD_USER_PLACEHOLDER|/home/$CURRENT_USER|g" {} + || true
fi

log_info "Czyszczenie pamięci podręcznej (Cache)..."
rm -rf ~/.cache/icon-cache.kcache ~/.cache/plasma* ~/.cache/ico*

# Odpalamy chwilowo Plasmę w tle, żeby załadowała skopiowane pliki .config
if command -v kstart6 &>/dev/null; then
    kstart6 plasmashell >/dev/null 2>&1 &
elif command -v kstart5 &>/dev/null; then
    kstart5 plasmashell >/dev/null 2>&1 &
else
    setsid plasmashell >/dev/null 2>&1 &
fi

# Wykryj poprawną nazwę binarki qdbus (Plasma 6 często ją zmienia)
QDBUS_BIN=""
for candidate in qdbus qdbus6 qdbus-qt6 qdbus-qt5; do
    if command -v "$candidate" &>/dev/null; then
        QDBUS_BIN="$candidate"
        break
    fi
done

if [[ -z "$QDBUS_BIN" ]]; then
    log_warn "Nie znaleziono polecenia qdbus – pomijanie ustawiania tapety."
else
    log_info "Oczekiwanie na usługę D-Bus plasmashell..."
    READY=0
    for i in $(seq 1 30); do
        if "$QDBUS_BIN" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript 'true' &>/dev/null; then
            READY=1
            break
        fi
        sleep 1
    done

    if [[ "$READY" -ne 1 ]]; then
        log_warn "plasmashell nie zarejestrował usługi D-Bus w czasie 30s – pomijanie ustawiania tapety."
    else
        log_info "Ustawianie tapety dla wszystkich pulpitów..."
        "$QDBUS_BIN" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
var allDesktops = desktops();
for (i=0; i<allDesktops.length; i++) {
    d = allDesktops[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = Array("Wallpaper", "org.kde.image", "General");
    d.writeConfig("Image", "file:///'"$HOME"'/.local/share/wallpapers/wallpaper2.jpg");
}' || log_warn "Nie udało się ustawić tapety (qdbus zwrócił błąd)."
    fi
fi

# Zabijamy proces DRUGI RAZ, wymuszając zrzut stanu konfiguracji na dysk
log_info "Zapisywanie stanu środowiska..."
kquitapp6 plasmashell 2>/dev/null || kquitapp5 plasmashell 2>/dev/null || killall plasmashell 2>/dev/null || true
sleep 2

# Odbudowa bazy cache (sycoca)
if command -v kbuildsycoca6 &>/dev/null; then
    kbuildsycoca6 --noincremental &>/dev/null || true
elif command -v kbuildsycoca5 &>/dev/null; then
    kbuildsycoca5 --noincremental &>/dev/null || true
fi

log_ok "KONFIGURACJA ZAKOŃCZONA SUKCESEM!"

# ==========================================================
# 4. ZAKOŃCZENIE I SPRZĄTANIE
# ==========================================================
log_info "Usuwam tymczasowe uprawnienia sudo..."
sudo rm -f /etc/sudoers.d/99-temp-installer

log_ok "KONFIGURACJA ZAKOŃCZONA SUKCESEM!"
sleep 3
systemctl reboot
