#!/usr/bin/env bash

# ============================================================ #
# 🚀 Gost Proxy Installer
#      v1.3.0 (2026) © Ivan.Nginx
# ------------------------------------------------------------ #
# 🧾 Description:
#    ★ Installs / Updates Gost Proxy
#    ★ Downloads latest release from GitHub
#    ★ Generates YAML configuration
#    ★ Creates systemd service
#    ★ Configures firewall (UFW / firewalld / iptables)
#    ★ Tests HTTP & SOCKS5 proxies
#    ★ Supports Install / Update / Reconfigure / Force modes
# ------------------------------------------------------------ #
# 🔹 Local Usage:
#    ➤ chmod +x install_gost.sh
#
#    ➤ ./install_gost.sh
#
#    or
#
#    ➤ ./install_gost.sh HTTP_PORT SOCKS_PORT USER PASSWORD
#
#    or
#
#    ➤ ./install_gost.sh --force
#
# 🔸 Remote install:
#    ➤ bash <(curl -fsSL https://raw.githubusercontent.com/STEALTHNET-APP/gost-install-script/main/install_gost.sh)
#
# 🔸 Remote reinstall
#    ➤ bash <(curl -fsSL https://raw.githubusercontent.com/STEALTHNET-APP/gost-install-script/main/install_gost.sh) -- --force
# ------------------------------------------------------------ #
# 🌍 Repository:
#
#    https://github.com/STEALTHNET-APP/gost-install-script
# ============================================================ #

set -Eeuo pipefail

###############################################################################
# Constants
###############################################################################

SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="1.0.0"

GITHUB_REPO="go-gost/gost"
GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"

INSTALL_USER="gost"
INSTALL_GROUP="gost"

BIN_DIR="/usr/local/bin"
BIN_FILE="${BIN_DIR}/gost"

CONFIG_DIR="/etc/gost"
CONFIG_FILE="${CONFIG_DIR}/config.yml"

LOG_DIR="/var/log/gost"

SERVICE_NAME="gost"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

DEFAULT_HTTP_PORT="18080"
DEFAULT_SOCKS_PORT="18081"
DEFAULT_USERNAME="gost"

FORCE_MODE=false

HTTP_PORT=""
SOCKS_PORT=""
USERNAME=""
PASSWORD=""

LATEST_VERSION=""
INSTALLED_VERSION=""

ARCHIVE_NAME=""
DOWNLOAD_URL=""

declare -ag LISTENERS=()

###############################################################################
# Colors
###############################################################################

if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    CYAN=""
    BOLD=""
    RESET=""
fi

###############################################################################
# Logging
###############################################################################

info() {
    printf "${CYAN}➜${RESET} %s\n" "$*"
}

success() {
    printf "${GREEN}✔${RESET} %s\n" "$*"
}

warning() {
    printf "${YELLOW}⚠${RESET} %s\n" "$*"
}

error() {
    printf "${RED}✖${RESET} %s\n" "$*" >&2
}

die() {
    error "$*"
    exit 1
}

###############################################################################
# Helpers
###############################################################################

require_root() {
    [[ $EUID -eq 0 ]] || die "Please run this script as root."
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

ensure_dependency() {

    local dependency="$1"

    if ! command_exists "$dependency"; then
        die "Required dependency is missing: ${dependency}"
    fi
}

###############################################################################
# Dependency Check
###############################################################################

check_dependencies() {

    info "Checking required dependencies..."

    ensure_dependency curl
    ensure_dependency tar
    ensure_dependency grep
    ensure_dependency sed
    ensure_dependency awk
    ensure_dependency systemctl

    success "All dependencies are available."

}

###############################################################################
# Arguments
###############################################################################

parse_arguments() {

    if [[ $# -eq 0 ]]; then
        return
    fi

    if [[ "$1" == "--force" || "$1" == "-f" ]]; then
        FORCE_MODE=true
        return
    fi

    [[ $# -eq 4 ]] || die "Invalid number of arguments."

    HTTP_PORT="$1"
    SOCKS_PORT="$2"
    USERNAME="$3"
    PASSWORD="$4"

}

###############################################################################
# Interactive Mode
###############################################################################

ask_configuration() {

    local input

    read -rp "HTTP Port [${DEFAULT_HTTP_PORT}]: " input
    HTTP_PORT="${input:-$DEFAULT_HTTP_PORT}"

    read -rp "SOCKS5 Port [${DEFAULT_SOCKS_PORT}]: " input
    SOCKS_PORT="${input:-$DEFAULT_SOCKS_PORT}"

    read -rp "Username [${DEFAULT_USERNAME}]: " input
    USERNAME="${input:-$DEFAULT_USERNAME}"

    while true; do

        read -rsp "Password: " PASSWORD
        echo

        [[ -n "$PASSWORD" ]] && break

        warning "Password cannot be empty."

    done

}

###############################################################################
# Detect Existing Installation
###############################################################################

detect_installation() {

    if [[ -x "$BIN_FILE" ]]; then

        INSTALLED_VERSION="$("$BIN_FILE" -V 2>/dev/null | head -n1 || true)"

        return 0

    fi

    return 1

}

###############################################################################
# GitHub Release
###############################################################################

fetch_latest_release() {

    info "Fetching latest Gost release..."

    local redirect

    redirect="$(
        curl -fsSLI \
            -o /dev/null \
            -w '%{url_effective}' \
            "https://github.com/${GITHUB_REPO}/releases/latest"
    )"

    LATEST_VERSION="${redirect##*/}"

    [[ "$LATEST_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] \
        || die "Unable to determine latest Gost version."

    ARCHIVE_NAME="gost_${LATEST_VERSION#v}_linux_amd64.tar.gz"

    DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${LATEST_VERSION}/${ARCHIVE_NAME}"

    success "Latest version: ${LATEST_VERSION}"

}

###############################################################################
# Main
###############################################################################

main() {

    require_root

    parse_arguments "$@"

    check_dependencies

    fetch_latest_release

###############################################################################
# Download & Install
###############################################################################

download_gost() {

    local tmp_dir
    local archive

    tmp_dir="$(mktemp -d)"
    archive="${tmp_dir}/${ARCHIVE_NAME}"

    info "Downloading Gost ${LATEST_VERSION}..."

    curl -fL "$DOWNLOAD_URL" -o "$archive" \
        || die "Failed to download Gost."

    info "Extracting archive..."

    tar -xzf "$archive" -C "$tmp_dir" \
        || die "Failed to extract archive."

    [[ -f "${tmp_dir}/gost" ]] \
        || die "Gost binary not found inside archive."

    install -m755 "${tmp_dir}/gost" "$BIN_FILE"

    rm -rf "$tmp_dir"

    success "Gost installed."

}

###############################################################################
# User
###############################################################################

create_user() {

    if id "$INSTALL_USER" >/dev/null 2>&1; then

        success "User '${INSTALL_USER}' already exists."

        return

    fi

    info "Creating system user..."

    useradd \
        --system \
        --no-create-home \
        --shell /usr/sbin/nologin \
        "$INSTALL_USER"

    success "User created."

}

###############################################################################
# Directories
###############################################################################

create_directories() {

    mkdir -p "$CONFIG_DIR"
    chown root:"$INSTALL_GROUP" "$CONFIG_DIR"
    chmod 750 "$CONFIG_DIR"

    mkdir -p "$LOG_DIR"
    chown "$INSTALL_USER":"$INSTALL_GROUP" "$LOG_DIR"
    chmod 750 "$LOG_DIR"

}

###############################################################################
# Listeners
###############################################################################

add_listener() {

    LISTENERS+=("$1")

}

###############################################################################
# Configuration
###############################################################################

export_config() {

    info "Exporting Gost configuration..."

    LISTENERS=()

    add_listener "http://${USERNAME}:${PASSWORD}@:${HTTP_PORT}"

    add_listener "socks5://${USERNAME}:${PASSWORD}@:${SOCKS_PORT}"

    local args=()
    local listener

    for listener in "${LISTENERS[@]}"; do
        args+=(
            -L "$listener"
        )
    done

    "${BIN_FILE}" \
        "${args[@]}" \
        -O yaml \
        > "$CONFIG_FILE" \
        || die "Failed to export Gost configuration."

    chmod 640 "$CONFIG_FILE"

    chown root:"$INSTALL_GROUP" "$CONFIG_FILE"

    success "Configuration exported."

}

###############################################################################
# systemd
###############################################################################

generate_service() {

    info "Generating systemd unit..."

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Gost Proxy
After=network-online.target
Wants=network-online.target

[Service]

Type=simple

User=${INSTALL_USER}
Group=${INSTALL_GROUP}

ExecStart=${BIN_FILE} -C ${CONFIG_FILE}

Restart=always
RestartSec=3

NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=full

AmbientCapabilities=
CapabilityBoundingSet=

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    success "systemd unit created."

}

###############################################################################
# Install
###############################################################################

install_gost() {

    download_gost

    create_user

    create_directories

    export_config

    generate_service

}

###############################################################################
# Update
###############################################################################

update_gost() {

    download_gost

    systemctl restart "$SERVICE_NAME"

    success "Gost updated."

}

###############################################################################
# Reconfigure
###############################################################################

reconfigure_gost() {

    export_config

    systemctl restart "$SERVICE_NAME"

    success "Configuration updated."

}

}

main "$@"