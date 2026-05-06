# Machine Status Display

Full-screen industrial dashboard for monitoring 1–n machines on a 16:9 touchscreen.

## Downloads

| File | Description |
|------|-------------|
| [raspi-machine-status-display.img.gz](https://github.com/joe2824/machine_status_display/releases/latest/download/raspi-machine-status-display.img.gz) | Raspberry Pi image (ready to flash) |
| [machine-status-display.spdx.json](https://github.com/joe2824/machine_status_display/releases/latest/download/machine-status-display.spdx.json) | Software Bill of Materials (SPDX) |
| [cve-report.txt](https://github.com/joe2824/machine_status_display/releases/latest/download/cve-report.txt) | CVE report |

`.deb` + `.deb.sig` for USB updates: [Releases page](https://github.com/joe2824/machine_status_display/releases/latest) → Assets

All releases: [github.com/joe2824/machine_status_display/releases](https://github.com/joe2824/machine_status_display/releases)

---

## Supported Hardware

| Model | Status |
|-------|--------|
| Raspberry Pi 4 | ✓ |
| Raspberry Pi CM4 | ✓ |
| Raspberry Pi 3B / 3B+ | ✓ |
| Raspberry Pi Zero 2 W | ✓ |
| Raspberry Pi 5 | ✓ (image config: `device.layer: rpi5`) |

---

## Raspberry Pi — Installation

### Flash the Raspberry Pi image

1. Install [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
2. Download **`raspi-machine-status-display.img.gz`**
3. Open Raspberry Pi Imager:
   - **Device**: Raspberry Pi (any)
   - **OS**: "Use custom" → select `.img.gz`
   - **Storage**: select SD card or USB SSD
4. Flash → insert SD card into Pi → boot

The system boots directly into the dashboard (Wayland/cage, no desktop).

### Alternative with `dd`

```bash
gunzip -c raspi-machine-status-display.img.gz | sudo dd of=/dev/sdX bs=4M status=progress
```

### SSH access (diagnostics)

```
Host:     machine-status (or IP from router DHCP table)
User:     msd
Password: msd
```

```bash
ssh msd@machine-status.local   # via mDNS (avahi)
journalctl -u machine-status -b --no-pager
```

---

## Raspberry Pi — App update via USB drive

1. Download **two files** from the [releases page](https://github.com/joe2824/machine_status_display/releases/latest):
   - `Machine.Status.Display_X.X.X_arm64.deb`
   - `Machine.Status.Display_X.X.X_arm64.deb.sig`
2. Copy both files **unchanged** to the root of a USB drive3. Plug the USB drive into the running Raspberry Pi

The dashboard detects the files automatically (check interval: 5 seconds), verifies the **cryptographic signature** and shows a **blue update banner** — if the version is newer than the installed one.

4. Tap **"Install now"**
5. The system installs the update and restarts the kiosk service

> **Note:** Both files (`.deb` + `.deb.sig`) must be present. The update is only installed if the signature is valid and the version is newer than the installed one.

---

## Raspberry Pi — OTA update (internet)

If the Raspberry Pi has internet access, the dashboard automatically checks for new versions every 30 minutes. A **green banner** appears when an update is available.

- No manual action required when no internet is present
- Download and signature verification happen automatically in the background
- Install by tapping the banner

---

## Release a new version

```bash
./scripts/release.sh
```

The script detects the last published version automatically and prompts for the bump type:

```
Last release: v0.1.10

  1) patch → 0.1.11  (bug fixes)
  2) minor → 0.2.0   (new features)
  3) major → 1.0.0   (breaking changes)
  4) custom

Bump type [1-4]:
```

All version files are updated, a git commit + tag is created and pushed — CI builds the image, binaries, SBOM and CVE report automatically.

---

## Stack

| Layer | Technology |
|-------|------------|
| Desktop shell | Tauri 2 (Rust) |
| Frontend | SvelteKit 2 + Svelte 5 |
| Styling | Tailwind CSS v4 (Vite plugin) |
| Persistence | Flat-file JSON via Rust (`app_data_dir/machines.json`) |
| Pi OS | Debian Trixie (arm64), MBR + ext4 |
| Kiosk compositor | cage (Wayland) |

## Features

- **Auto-scaling** — container queries (`cqmin`); font grows with card size
- **Media display** — color-coded by medium (compressed air blue, voltage red, …); hidden when inactive
- **Emergency stop bar** — Full / Partial / Non-functional (pulsing); only shown when voltage is active
- **Work permit** — info banner with configurable auto-hide after N days; remaining time + timer reset in edit dialog
- **Responsible person + timestamp** — per machine; who is currently working on it, when last changed
- **Dynamic media** — manage arbitrary media globally (media library)
- **On-screen keyboard** — QWERTZ/QWERTY, shift active, physical keyboard works simultaneously
- **USB update** — plug in `.deb` + `.deb.sig` → signature check → install banner
- **OTA update** — automatic detection when internet is available, signature-verified
- **SBOM + CVE** — every release includes a package inventory (SPDX) + vulnerability report

## Development

```bash
npm install
npm run tauri dev
```

## Project structure

```
src/
  app.css                        Tailwind @theme tokens + cqmin utilities
  lib/
    i18n.ts                      DE/EN translations
    stores/
      machines.ts                Machine store (Tauri invoke)
      mediaLibrary.ts            Media library
      osk.ts                     OSK state
      burnin.ts                  Pixel-shift burn-in protection
    components/
      MachineCard.svelte         Display card (auto-scaled)
      MachineGrid.svelte         Adaptive grid
      MachineManager.svelte      Create / edit machines
      EditDialog.svelte          Form (phase, media, emergency stop, …)
      OSK.svelte                 On-screen keyboard
      MediaIcon.svelte           SVG icons by media name
  routes/
    +page.svelte                 Main page + USB/OTA update banner
src-tauri/
  src/lib.rs                     Rust commands + USB/OTA update detection + signature verification
  tauri.conf.json                Window config (borderless, fullscreen)
image/
  config/machine-status.yaml    rpi-image-gen configuration
  layer/machine-status.yaml     Custom layer (packages, service, sudoers)
  kiosk.service.tpl              systemd service template
scripts/
  release.sh                    Release helper (interactive, version bump + push)
  build-image-local.sh          Local image build via Lima VM
  inspect-image-local.sh        Image inspection via Lima VM
.github/workflows/
  release.yml                   CI: Tauri build + Pi image + SBOM/CVE
```

## Data storage (Raspberry Pi)

App data is stored in the kiosk user's home directory (`msd`):

```
/home/msd/.local/share/com.joel.machine-status-display/machines.json
```
