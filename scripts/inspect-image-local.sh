#!/bin/bash
# Inspect the built Raspberry Pi image inside the Lima VM.
# Usage: ./scripts/inspect-image-local.sh

set -euo pipefail

LIMA_INSTANCE="msd-builder"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

IMG_XZ="${REPO_ROOT}/raspi-machine-status-display.img.xz"
if [ ! -f "$IMG_XZ" ]; then
    echo "Error: ${IMG_XZ} not found — run build-image-local.sh first"
    exit 1
fi

if ! limactl list --format '{{.Name}}' 2>/dev/null | grep -q "^${LIMA_INSTANCE}$"; then
    echo "Error: Lima instance '${LIMA_INSTANCE}' not found"
    exit 1
fi

limactl start "${LIMA_INSTANCE}" 2>/dev/null || true

echo "→ Decompressing image (to /tmp inside VM)..."
limactl shell "${LIMA_INSTANCE}" -- bash -c "
    xz -d -k -T0 '${IMG_XZ}' -c > /tmp/msd-inspect.img 2>/dev/null || \
    cp '${IMG_XZ%.xz}' /tmp/msd-inspect.img 2>/dev/null || true
"

limactl shell "${LIMA_INSTANCE}" -- bash << 'EOF'
set -euo pipefail

PASS=0; FAIL=0
ok()   { echo "  ✓  $1"; PASS=$((PASS+1)); }
fail() { echo "  ✗  $1"; FAIL=$((FAIL+1)); }
chk()  { # chk "label" "grep pattern" "file"
    if sudo grep -qE "$2" "$3" 2>/dev/null; then ok "$1"; else fail "$1 — not found in $3"; fi
}

IMG=/tmp/msd-inspect.img
[ -f "$IMG" ] || { echo "Error: decompressed image not found"; exit 1; }

echo "→ Cleaning up stale loop devices..."
for l in $(sudo losetup -j "$IMG" 2>/dev/null | cut -d: -f1); do
    sudo losetup -d "$l" 2>/dev/null || true
done

sudo apt-get install -y --no-install-recommends kpartx 2>/dev/null | tail -1
LOOP=$(sudo losetup --show -fP "$IMG")
sudo kpartx -as "$LOOP"
LOOPN="${LOOP##*/}"

echo ""
echo "=== Partition layout ==="
sudo lsblk "$LOOP"

# ── Mount boot partition ──────────────────────────────────────────────────────
sudo mkdir -p /mnt/msd-boot /mnt/msd-rootfs
sudo mount "/dev/mapper/${LOOPN}p1" /mnt/msd-boot 2>/dev/null || \
    { fail "boot partition mount"; }

# ── Mount rootfs ──────────────────────────────────────────────────────────────
ROOTFS_PART=$(sudo blkid "/dev/mapper/${LOOPN}p2" "/dev/mapper/${LOOPN}p3" "/dev/mapper/${LOOPN}p4" 2>/dev/null \
    | grep -E 'TYPE="ext4"|TYPE="erofs"' | head -1 | cut -d: -f1)
[ -n "$ROOTFS_PART" ] || { fail "rootfs partition not found"; sudo kpartx -d "$LOOP"; sudo losetup -d "$LOOP"; exit 1; }
sudo mount "$ROOTFS_PART" /mnt/msd-rootfs

# ── Boot partition ────────────────────────────────────────────────────────────
echo ""
echo "=== cmdline.txt ==="
sudo cat /mnt/msd-boot/cmdline.txt 2>/dev/null || fail "cmdline.txt missing"
chk "console=tty1"    "console=tty1"           /mnt/msd-boot/cmdline.txt
chk "quiet"           "\bquiet\b"               /mnt/msd-boot/cmdline.txt
chk "root=LABEL=ROOT" "root=LABEL=ROOT"         /mnt/msd-boot/cmdline.txt

echo ""
echo "=== config.txt (relevant lines) ==="
sudo grep -E 'disable_splash|arm_64bit|audio|dtparam' /mnt/msd-boot/config.txt 2>/dev/null || echo "  (none)"
chk "disable_splash=1" "disable_splash=1"       /mnt/msd-boot/config.txt
chk "arm_64bit (pi3)"  "arm_64bit=1"            /mnt/msd-boot/config.txt
chk "audio off"        "dtparam=audio=off"       /mnt/msd-boot/config.txt

# ── Service file ──────────────────────────────────────────────────────────────
SVC=/mnt/msd-rootfs/etc/systemd/system/machine-status.service
echo ""
echo "=== machine-status.service ==="
sudo cat "$SVC" 2>/dev/null || fail "service file missing"
chk "ExecStart cage"          "cage.*machine_status_display"  "$SVC"
chk "WLR_NO_HARDWARE_CURSORS" "WLR_NO_HARDWARE_CURSORS=1"     "$SVC"
chk "udevadm settle"          "udevadm settle"                 "$SVC"
chk "Restart=always"          "Restart=always"                 "$SVC"
if sudo grep -q "PAMName\|TTYPath" "$SVC" 2>/dev/null; then
    fail "PAMName or TTYPath in service — breaks cage DRM init"
else
    ok "no PAMName/TTYPath (correct — these break cage)"
fi
if sudo ls /mnt/msd-rootfs/etc/systemd/system/multi-user.target.wants/machine-status.service &>/dev/null || \
   sudo ls /mnt/msd-rootfs/etc/systemd/system/default.target.wants/machine-status.service &>/dev/null; then
    ok "service enabled (multi-user.target.wants)"
else
    fail "service NOT enabled"
fi

# ── User groups ───────────────────────────────────────────────────────────────
echo ""
echo "=== User groups (msd) ==="
sudo grep 'msd' /mnt/msd-rootfs/etc/group 2>/dev/null | sed 's/^/  /' || true
for g in video input render tty seat; do
    if sudo grep -qE "^${g}:.*msd" /mnt/msd-rootfs/etc/group 2>/dev/null; then
        ok "group $g"
    else
        fail "group $g missing for msd"
    fi
done

# ── sudoers ───────────────────────────────────────────────────────────────────
echo ""
echo "=== sudoers ==="
sudo cat /mnt/msd-rootfs/etc/sudoers.d/machine-status-update 2>/dev/null || fail "sudoers missing"

# ── USB automount rule ────────────────────────────────────────────────────────
echo ""
echo "=== udev USB automount rule ==="
sudo cat /mnt/msd-rootfs/etc/udev/rules.d/99-usb-automount.rules 2>/dev/null || fail "udev rule missing"
chk "/media/%k mount path"   "/media/%k"          /mnt/msd-rootfs/etc/udev/rules.d/99-usb-automount.rules
chk "SUBSYSTEMS==usb"        'SUBSYSTEMS=="usb"'  /mnt/msd-rootfs/etc/udev/rules.d/99-usb-automount.rules
chk "DEVTYPE==partition"     'DEVTYPE.*partition' /mnt/msd-rootfs/etc/udev/rules.d/99-usb-automount.rules
if sudo test -d /mnt/msd-rootfs/media; then ok "/media dir exists"; else fail "/media dir missing"; fi

# ── System config ─────────────────────────────────────────────────────────────
echo ""
echo "=== fstab (non-comment lines) ==="
sudo grep -v '^#' /mnt/msd-rootfs/etc/fstab 2>/dev/null | grep -v '^$' | sed 's/^/  /' || fail "fstab missing"
if sudo grep -q 'by-slot' /mnt/msd-rootfs/etc/fstab 2>/dev/null; then
    fail "fstab still has /dev/disk/by-slot/ paths — emergency mode at boot"
else
    ok "fstab no slot paths"
fi

echo ""
echo "=== Journal rotation ==="
sudo cat /mnt/msd-rootfs/etc/systemd/journald.conf.d/size-limit.conf 2>/dev/null || fail "journald config missing"

echo ""
echo "=== cgroup accounting suppressed ==="
sudo cat /mnt/msd-rootfs/etc/systemd/system.conf.d/no-cgroup-accounting.conf 2>/dev/null || fail "cgroup config missing"

# ── Binaries ──────────────────────────────────────────────────────────────────
echo ""
echo "=== Binaries ==="
if sudo test -f /mnt/msd-rootfs/usr/bin/machine_status_display; then
    SIZE=$(sudo stat -c%s /mnt/msd-rootfs/usr/bin/machine_status_display)
    ok "machine_status_display (${SIZE} bytes)"
else
    fail "machine_status_display missing"
fi
if sudo test -f /mnt/msd-rootfs/usr/bin/cage; then ok "cage"; else fail "cage missing"; fi
if sudo test -f /mnt/msd-rootfs/usr/bin/dbus-run-session; then ok "dbus-run-session"; else fail "dbus-run-session missing"; fi
if sudo test -f /mnt/msd-rootfs/usr/sbin/seatd || sudo test -f /mnt/msd-rootfs/usr/bin/seatd; then ok "seatd binary"; else fail "seatd binary missing"; fi
if sudo ls /mnt/msd-rootfs/etc/systemd/system/multi-user.target.wants/seatd.service &>/dev/null || \
   sudo ls /mnt/msd-rootfs/etc/systemd/system/default.target.wants/seatd.service &>/dev/null; then
    ok "seatd enabled"
else
    fail "seatd NOT enabled"
fi
if sudo test -f /mnt/msd-rootfs/etc/tmpfiles.d/msd-runtime-dir.conf; then
    ok "tmpfiles /run/user/1000"; sudo cat /mnt/msd-rootfs/etc/tmpfiles.d/msd-runtime-dir.conf | sed 's/^/  /'
else
    fail "tmpfiles /run/user/1000 missing"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo "  PASS: ${PASS}   FAIL: ${FAIL}"
echo "════════════════════════════════════════"

sudo umount /mnt/msd-boot  2>/dev/null || true
sudo umount /mnt/msd-rootfs 2>/dev/null || true
sudo kpartx -d "$LOOP" 2>/dev/null || true
sudo losetup -d "$LOOP"
rm -f "$IMG"
echo "✓ Done"
EOF
