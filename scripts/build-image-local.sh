#!/bin/bash
# Build the Raspberry Pi image locally using a Lima VM (Apple Silicon / arm64).
#
# Usage:
#   ./scripts/build-image-local.sh              # image only (uses latest GitHub release .deb)
#   ./scripts/build-image-local.sh --build-app            # build Tauri app from local source first
#   ./scripts/build-image-local.sh --app-version=v0.1.10  # install specific older release (USB update test)
#   ./scripts/build-image-local.sh --debug      # no splash, verbose boot, service output on screen
#   ./scripts/build-image-local.sh --clean      # clear rpi-image-gen work dir (force clean build)
#   ./scripts/build-image-local.sh --clean-all  # delete entire rpi-image-gen (re-clone + reinstall)
#   Flags can be combined: --build-app --debug --clean
#
# First run: ~10-15 min (clones rpi-image-gen + installs deps).
# Subsequent runs: ~5-10 min (rpi-image-gen cached, layer files refreshed).
#
# Output: raspi-machine-status-display.img.gz in the repo root.

set -euo pipefail

LIMA_INSTANCE="msd-builder"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_APP=false
DEBUG=false
CLEAN=false
CLEAN_ALL=false
APP_VERSION=""

for arg in "$@"; do
    case "$arg" in
        --build-app)       BUILD_APP=true ;;
        --debug)           DEBUG=true ;;
        --clean)           CLEAN=true ;;
        --clean-all)       CLEAN_ALL=true ;;
        --app-version=*)   APP_VERSION="${arg#--app-version=}" ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

# ── Preflight ────────────────────────────────────────────────────────────────
if ! command -v limactl &>/dev/null; then
    echo "Error: Lima not installed — run: brew install lima"
    exit 1
fi

# ── Start Lima VM ────────────────────────────────────────────────────────────
if ! limactl list --format '{{.Name}}' 2>/dev/null | grep -q "^${LIMA_INSTANCE}$"; then
    echo "→ Creating Lima instance '${LIMA_INSTANCE}' (Ubuntu 24.04, arm64)..."
    limactl start --name "${LIMA_INSTANCE}" template://ubuntu-24.04 --tty=false
else
    echo "→ Starting Lima instance '${LIMA_INSTANCE}'..."
    limactl start "${LIMA_INSTANCE}" 2>/dev/null || true
fi

run() { limactl shell "${LIMA_INSTANCE}" -- bash -c "$1"; }

# ── Clean (optional) ─────────────────────────────────────────────────────────
if [ "$CLEAN_ALL" = true ]; then
    echo "→ Full clean: removing rpi-image-gen (will re-clone + reinstall)..."
    run "sudo rm -rf /tmp/rpi-image-gen"
elif [ "$CLEAN" = true ]; then
    echo "→ Clean: removing rpi-image-gen work directory..."
    run "sudo rm -rf /tmp/rpi-image-gen/work"
fi

# ── Install rpi-image-gen (cached across runs) ───────────────────────────────
run "
if [ ! -d /tmp/rpi-image-gen ]; then
    echo '→ Cloning rpi-image-gen...'
    git clone --depth=1 https://github.com/raspberrypi/rpi-image-gen.git /tmp/rpi-image-gen
    echo '→ Installing rpi-image-gen dependencies...'
    cd /tmp/rpi-image-gen && sudo ./install_deps.sh
    sudo apt-get install -y --no-install-recommends imagemagick xz-utils
else
    echo '→ rpi-image-gen already cached, skipping install.'
fi
"

# ── Build Tauri app from local source (optional) ─────────────────────────────
if [ "$BUILD_APP" = true ]; then
    echo "→ Building Tauri app from local source..."
    
    KEY_B64=$(printf '%s' "${TAURI_SIGNING_PRIVATE_KEY:-}" | base64 | tr -d '\n')
    PW_B64=$(printf '%s' "${TAURI_SIGNING_PRIVATE_KEY_PASSWORD:-}" | base64 | tr -d '\n')
    run "
    # Install build tools (cached after first run)
    if ! command -v rustc &>/dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
    fi
    source ~/.cargo/env
    if ! command -v node &>/dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y --no-install-recommends nodejs
    fi
    sudo apt-get install -y --no-install-recommends \
        libwebkit2gtk-4.1-dev build-essential file libssl-dev librsvg2-dev xdg-utils

    # Copy source to writable location inside VM
    rm -rf /tmp/msd-src
    cp -r '${REPO_ROOT}' /tmp/msd-src

    # Decode and export signing keys inside the VM
    if [ -n \"$KEY_B64\" ]; then
        export TAURI_SIGNING_PRIVATE_KEY=\$(echo \"$KEY_B64\" | base64 -d)
    fi
    if [ -n \"$PW_B64\" ]; then
        export TAURI_SIGNING_PRIVATE_KEY_PASSWORD=\$(echo \"$PW_B64\" | base64 -d)
    fi

    cd /tmp/msd-src
    npm install
    npm run tauri build

    DEB=\$(find src-tauri/target/release/bundle/deb -name '*.deb' | head -1)
    if [ -z \"\$DEB\" ]; then
        echo 'Error: .deb not found after Tauri build.'
        exit 1
    fi
    cp \"\$DEB\" /tmp/rpi-image-gen/machine-status-display_arm64.deb
    echo \"→ Built and staged: \$DEB\"
    "
else
    if [ -n "$APP_VERSION" ]; then
        echo "→ Downloading release ${APP_VERSION} .deb on Mac..."
        VERSION_FLAG="${APP_VERSION}"
    else
        echo "→ Downloading latest release .deb on Mac..."
        VERSION_FLAG=""
    fi
    TEMP_DIR=$(mktemp -d /tmp/msd-download-XXXXXX)
    gh release download ${VERSION_FLAG} \
        --repo joe2824/machine_status_display \
        --pattern "*.deb" \
        --dir "$TEMP_DIR" \
        --clobber
    TEMP_DEB=$(find "$TEMP_DIR" -name "*_arm64.deb" | head -1)
    if [ -z "$TEMP_DEB" ]; then
        echo "Error: no *_arm64.deb found in release assets"
        ls "$TEMP_DIR"
        exit 1
    fi
    echo "→ Copying $(basename "$TEMP_DEB") into Lima VM..."
    limactl cp "$TEMP_DEB" "${LIMA_INSTANCE}:/tmp/rpi-image-gen/machine-status-display_arm64.deb"
    rm -rf "$TEMP_DIR"
fi

# ── Copy layer files (always refresh) ───────────────────────────────────────
echo "→ Copying layer files..."
run "
mkdir -p /tmp/rpi-image-gen/layer/app
cp '${REPO_ROOT}/image/layer/machine-status.yaml' /tmp/rpi-image-gen/layer/app/machine-status.yaml
cp '${REPO_ROOT}/image/kiosk.service.tpl'         /tmp/rpi-image-gen/
"

# ── Build image ──────────────────────────────────────────────────────────────
echo "→ Building Raspberry Pi image (this takes a few minutes)..."
GH_TOKEN=$(gh auth token 2>/dev/null || echo "")
if [ -z "$GH_TOKEN" ]; then
    echo "Warning: no gh token found — run 'gh auth login' if the repo is private"
fi
limactl shell "${LIMA_INSTANCE}" -- bash -c "
export GITHUB_TOKEN='${GH_TOKEN}'
cd /tmp/rpi-image-gen
sudo --preserve-env=GITHUB_TOKEN ./rpi-image-gen build -c '${REPO_ROOT}/image/config/machine-status.yaml'
"

# ── Mandatory boot partition fix ─────────────────────────────────────────────
# rpi-image-gen's rpi4 device layer finalises cmdline.txt AFTER all hooks,
# forcing root=/dev/disk/by-slot/system even for image-rpios (MBR+ext4).
# Fix it here, post-build, every time.
echo "→ Fixing boot partition (root=, disable_splash)..."
limactl shell "${LIMA_INSTANCE}" -- bash << 'BOOTFIX'
set -euo pipefail
IMG=$(sudo find /tmp/rpi-image-gen/work -name 'machine-status-display.img' | head -1)
LOOP=$(sudo losetup --show -fP "$IMG")
sudo kpartx -as "$LOOP"
LOOPN="${LOOP##*/}"
sudo mkdir -p /mnt/msd-bootfix
sudo mount "/dev/mapper/${LOOPN}p1" /mnt/msd-bootfix

if [ -f /mnt/msd-bootfix/cmdline.txt ]; then
    # Fix root device — rpi4 layer sets AB-slot path even for image-rpios
    sudo sed -i 's|root=/dev/disk/by-slot/system|root=LABEL=ROOT rootfstype=ext4|g' /mnt/msd-bootfix/cmdline.txt
    # Remove fullscreen_logo splash params (no splash layer)
    sudo sed -i -e 's/ fullscreen_logo=1//g' \
                -e 's/ fullscreen_logo_name=[^ ]*//g' \
                -e 's/ vt\.global_cursor_default=0//g' \
                /mnt/msd-bootfix/cmdline.txt
    echo "   cmdline.txt: $(cat /mnt/msd-bootfix/cmdline.txt)"
fi

if [ -f /mnt/msd-bootfix/config.txt ]; then
    # Remove any leftover splash-layer entries
    sudo sed -i '/fullscreen_logo/d; /logo\.tga/d' /mnt/msd-bootfix/config.txt
    # Suppress rainbow GPU logo
    grep -q 'disable_splash' /mnt/msd-bootfix/config.txt \
        || sudo sed -i '/^\[all\]/a disable_splash=1' /mnt/msd-bootfix/config.txt
    echo "   disable_splash: $(grep disable_splash /mnt/msd-bootfix/config.txt || echo 'NOT SET')"
fi

sudo umount /mnt/msd-bootfix

# Fix fstab in rootfs — same slot-based paths need replacing
sudo mkdir -p /mnt/msd-rootfix
sudo mount "/dev/mapper/${LOOPN}p2" /mnt/msd-rootfix
if [ -f /mnt/msd-rootfix/etc/fstab ]; then
    sudo sed -i \
        -e 's|/dev/disk/by-slot/system|LABEL=ROOT|g' \
        -e 's|/dev/disk/by-slot/boot|LABEL=BOOT|g' \
        /mnt/msd-rootfix/etc/fstab
    echo "   fstab: $(grep -v '^#' /mnt/msd-rootfix/etc/fstab | grep -v '^$')"
fi
sudo umount /mnt/msd-rootfix

sudo kpartx -d "$LOOP"
sudo losetup -d "$LOOP"
BOOTFIX

# ── Debug image patch (optional) ─────────────────────────────────────────────
# Adds to boot:  verbose kernel messages + all journald output on HDMI
# Adds to service: stdout/stderr → tty (pre-cage failures visible on screen)
# After boot: ssh msd@machine-status.local  |  journalctl -b -u machine-status -f
if [ "$DEBUG" = true ]; then
    echo "→ Patching debug image (verbose boot + journald to console)..."
    limactl shell "${LIMA_INSTANCE}" -- bash << 'DEBUGEOF'
set -euo pipefail
IMG=$(sudo find /tmp/rpi-image-gen/work -name 'machine-status-display.img' | head -1)
LOOP=$(sudo losetup --show -fP "$IMG")
sudo kpartx -as "$LOOP"
LOOPN="${LOOP##*/}"

# Boot partition: remove quiet, add journald forward + systemd log level
sudo mkdir -p /mnt/msd-debug-boot
sudo mount "/dev/mapper/${LOOPN}p1" /mnt/msd-debug-boot
if [ -f /mnt/msd-debug-boot/cmdline.txt ]; then
    sudo sed -i \
        -e 's/ quiet//g' \
        -e 's/$/ systemd.journald.forward_to_console=1 systemd.log_level=info/' \
        /mnt/msd-debug-boot/cmdline.txt
    echo "   cmdline.txt: $(cat /mnt/msd-debug-boot/cmdline.txt)"
fi
sudo umount /mnt/msd-debug-boot

# Rootfs: redirect service output to tty so pre-cage errors appear on screen.
# Also disable Restart=always to prevent crash loops hiding the error.
sudo mkdir -p /mnt/msd-debug-root
sudo mount "/dev/mapper/${LOOPN}p2" /mnt/msd-debug-root
SERVICE=/mnt/msd-debug-root/etc/systemd/system/machine-status.service
if [ -f "$SERVICE" ]; then
    sudo sed -i \
        -e 's/StandardOutput=journal/StandardOutput=tty/' \
        -e 's/StandardError=journal/StandardError=tty/' \
        -e 's/Restart=always/Restart=no/' \
        "$SERVICE"
    echo "   service: stdout/stderr → tty, Restart=no"
fi
sudo umount /mnt/msd-debug-root

sudo kpartx -d "$LOOP"
sudo losetup -d "$LOOP"
DEBUGEOF
fi

# ── Compress and copy output ─────────────────────────────────────────────────
echo "→ Compressing image..."
run "
IMG=\$(sudo find /tmp/rpi-image-gen/work -name 'machine-status-display.img' | head -1)
if [ -z \"\$IMG\" ]; then
    echo 'Error: machine-status-display.img not found — build may have failed.'
    exit 1
fi
sudo xz -T0 -f \"\$IMG\"
sudo chmod a+r \"\${IMG}.xz\"
"

echo "→ Copying image to host..."
IMG_XZ=$(run "sudo find /tmp/rpi-image-gen/work -name 'machine-status-display.img.xz' | head -1" | tr -d '\r')
limactl cp "${LIMA_INSTANCE}:${IMG_XZ}" "${REPO_ROOT}/raspi-machine-status-display.img.xz"

echo ""
echo "✓ Done: ${REPO_ROOT}/raspi-machine-status-display.img.xz"
echo "  Flash with: xzcat raspi-machine-status-display.img.xz | sudo dd of=/dev/sdX bs=4M status=progress"
