# Machine Status Display — Raspberry Pi Image

Builds a minimal Debian Trixie (arm64) image that boots directly into the
Machine Status Display Tauri 2 app as a Wayland kiosk via `cage`.

Uses [rpi-image-gen](https://github.com/raspberrypi/rpi-image-gen).

## Supported hardware

| Model | Notes |
|-------|-------|
| Raspberry Pi 3B / 3B+ | `arm_64bit=1` applied via config.txt |
| Raspberry Pi Zero 2 W | `arm_64bit=1` applied via config.txt |
| Raspberry Pi 4 / CM4  | Native 64-bit |
| Raspberry Pi 5        | Change `device.layer: rpi4` → `rpi5` in `config/machine-status.yaml` |

## Partition layout

`image-rpios` — MBR + ext4, two partitions:

| Partition | Label | Type | Mount |
|-----------|-------|------|-------|
| p1 | BOOT | FAT32 | `/boot/firmware` |
| p2 | ROOT | ext4  | `/` |

No AB slot mechanism. Data survives OS updates (data lives in `/home/msd`, not swapped out).

## Local build (Mac with Lima)

```bash
# First run: ~10-15 min (clones rpi-image-gen, installs deps)
./scripts/build-image-local.sh

# Force clean build
./scripts/build-image-local.sh --clean

# Build for USB update testing (install older release)
./scripts/build-image-local.sh --app-version=v0.1.14

# Debug image (journald forwarded to console, service stdout → tty)
./scripts/build-image-local.sh --debug
```

Output: `raspi-machine-status-display.img.xz` in repo root.

## Inspect image (without flashing)

```bash
./scripts/inspect-image-local.sh
```

Mounts partitions inside the Lima VM and checks all critical settings:
cmdline.txt, fstab, service file, groups, PAM config, binaries, udev rules.

## CI build

`../.github/workflows/release.yml` — `rpi-image` job.
Triggered on tag push (`v*`) or manual dispatch.
Runs on GitHub-hosted arm64 runner.

## Flash

```bash
xzcat raspi-machine-status-display.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
```

Or use Raspberry Pi Imager with the `.img.xz` file directly.

## Architecture

### Boot flow
1. Pi bootloader reads `BOOT` FAT partition
2. Kernel boots, mounts `ROOT` ext4 partition
3. systemd starts, reaches `multi-user.target`
4. `machine-status.service` starts:
   - PAMName=machine-status → `pam_systemd` creates logind session + `/run/user/1000`
   - `udevadm settle` → waits for USB device enumeration
   - `cage` starts → `dbus-run-session machine_status_display`
   - `chvt 1` → explicitly activates VT1, logind marks session active → mouse/touch works
   - `udevadm trigger --subsystem-match=input` → synthesises ADD events for all input devices

### Key design decisions

| Decision | Reason |
|----------|--------|
| `PAMName=machine-status` (minimal PAM) | Full login PAM stack causes VT timing conflicts |
| `LIBSEAT_BACKEND=logind` | Correct backend for logind-managed sessions |
| `ExecStartPost=+chvt 1` | Triggers logind session activation → TakeDevice grants input |
| `systemd-mount` for USB | headless Trixie has no usbmount; systemd-mount is the correct approach |
| Post-build fstab/cmdline fix | `rpi-image-gen setup.sh` injects slot paths after all hooks |
| `systemd-networkd-wait-online` masked | Kiosk has no hard network dependency at boot |

### Post-build fixes

`rpi-image-gen`'s `image/mbr/simple_dual/setup.sh` runs **after** all hooks and:
- Rewrites cmdline.txt: `root=ROOTDEV` → `root=/dev/disk/by-slot/system`
- Rewrites fstab with `/dev/disk/by-slot/*` paths

These paths don't exist on MBR+ext4 (no AB slot) → **emergency mode** at boot.

`build-image-local.sh` and `release.yml` apply post-build fixes:
- `cmdline.txt`: `root=/dev/disk/by-slot/system` → `root=LABEL=ROOT rootfstype=ext4`
- `fstab`: slot paths → `LABEL=ROOT` / `LABEL=BOOT`

## SSH debugging

```bash
ssh msd@machine-status.local    # via mDNS (avahi)
# password: msd

systemctl status machine-status
journalctl -b -u machine-status -f
```

## USB update

Place on USB stick root:
```
Machine.Status.Display_X.Y.Z_arm64.deb
Machine.Status.Display_X.Y.Z_arm64.deb.sig
```

The app scans every 5 seconds via `/proc/mounts` for any `/dev/sd*` mount.
Signature is verified (minisign, base64-encoded `.sig` file from GitHub releases).
Blue update banner appears if version is newer than installed.

## File overview

```
image/
  config/machine-status.yaml   rpi-image-gen build config (hardware, partitions)
  layer/machine-status.yaml    Custom layer (packages, service, groups, PAM, udev)
  kiosk.service.tpl             systemd service template (substituted at build time)
```
