#!/usr/bin/env bash
#
# Netrix bootstrap installer
# Downloads the official Netrix offline release zip, extracts it,
# runs the bundled install.sh, then launches netrix-manager.py (menu).
#
# Usage (one-liner, once hosted on your repo e.g. as install.sh):
#   curl -fsSL https://raw.githubusercontent.com/parhampahlevann/netrix/main/install.sh | bash
#
# Or locally:
#   bash install.sh
#
set -euo pipefail

# ---------- Config ----------
VERSION="v4.0.0"
ARCH="amd64"
REPO="parhampahlevann/netrix"
ZIP_NAME="Netrix-${VERSION}-Offline-${ARCH}.zip"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${ZIP_NAME}"
WORKDIR="$(mktemp -d /tmp/netrix-install.XXXXXX)"

# ---------- Helpers ----------
log()  { echo -e "\033[1;32m[*]\033[0m $*"; }
err()  { echo -e "\033[1;31m[!]\033[0m $*" >&2; }
need_root_cmd() { command -v sudo &>/dev/null && echo "sudo" || echo ""; }

SUDO="$(need_root_cmd)"

cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

# ---------- Dependencies ----------
ensure_deps() {
    local missing=()
    for bin in unzip curl; do
        command -v "$bin" &>/dev/null || missing+=("$bin")
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        log "Installing missing dependencies: ${missing[*]}"
        if command -v apt-get &>/dev/null; then
            $SUDO apt-get update -y
            $SUDO apt-get install -y "${missing[@]}"
        elif command -v yum &>/dev/null; then
            $SUDO yum install -y "${missing[@]}"
        elif command -v dnf &>/dev/null; then
            $SUDO dnf install -y "${missing[@]}"
        else
            err "Could not detect a supported package manager. Please install manually: ${missing[*]}"
            exit 1
        fi
    fi
}

# ---------- Download ----------
download_zip() {
    log "Downloading Netrix ${VERSION} (${ARCH})..."
    cd "$WORKDIR"
    if ! curl -fsSL -o "$ZIP_NAME" "$DOWNLOAD_URL"; then
        err "Download failed: $DOWNLOAD_URL"
        exit 1
    fi
}

# ---------- Extract ----------
extract_zip() {
    log "Extracting $ZIP_NAME..."
    unzip -oq "$ZIP_NAME"
    # Detect the actual top-level folder from the archive, so this script
    # keeps working even if the internal folder naming changes between releases.
    EXTRACT_DIR="$(unzip -Z1 "$ZIP_NAME" | head -n1 | cut -d'/' -f1)"
    if [ -z "$EXTRACT_DIR" ] || [ ! -d "$EXTRACT_DIR" ]; then
        err "Could not determine the extracted folder."
        exit 1
    fi
    log "Extracted to: $WORKDIR/$EXTRACT_DIR"
}

# ---------- Install ----------
run_installer() {
    INSTALL_SCRIPT="$(find "$EXTRACT_DIR" -maxdepth 2 -iname "install.sh" | head -n1)"
    if [ -z "$INSTALL_SCRIPT" ]; then
        err "install.sh not found inside the extracted package."
        exit 1
    fi
    log "Running installer: $INSTALL_SCRIPT"
    chmod +x "$INSTALL_SCRIPT"
    $SUDO bash "$INSTALL_SCRIPT"
}

# ---------- Launch manager menu ----------
launch_manager() {
    log "Launching Netrix manager..."
    if command -v netrix-manager.py &>/dev/null; then
        $SUDO netrix-manager.py
    elif [ -f "$EXTRACT_DIR/netrix-manager.py" ]; then
        chmod +x "$EXTRACT_DIR/netrix-manager.py"
        $SUDO "$EXTRACT_DIR/netrix-manager.py"
    else
        err "netrix-manager.py not found on PATH or in the package."
        err "If install.sh placed it elsewhere, run it manually, e.g.: sudo netrix-manager.py"
        exit 1
    fi
}

# ---------- Main ----------
main() {
    ensure_deps
    download_zip
    extract_zip
    run_installer
    launch_manager
}

main "$@"
