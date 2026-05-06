use serde::{Deserialize, Serialize};
use tauri::Emitter;
use std::fs;
use std::path::PathBuf;
use tauri::Manager;
use base64::Engine as _;

// Tauri signing public key (same as plugins.updater.pubkey in tauri.conf.json)
const UPDATER_PUBKEY_B64: &str =
    "dW50cnVzdGVkIGNvbW1lbnQ6IG1pbmlzaWduIHB1YmxpYyBrZXk6IEIxMkI4NzZFODRDMzY1QQpSV1JhTmt6b2RyZ1NDNDUrMWF3YldKbXJpcjhxUWkyUnJHK3NLZm4wKzJRY0RGeEpoMmJOTmNxZgo=";

fn verify_update_sig(file_bytes: &[u8], sig_b64_or_raw: &str) -> Result<(), String> {
    let decoded = base64::engine::general_purpose::STANDARD
        .decode(UPDATER_PUBKEY_B64)
        .map_err(|e| e.to_string())?;
    let pubkey_str = String::from_utf8(decoded).map_err(|e| e.to_string())?;
    let pubkey = minisign_verify::PublicKey::decode(&pubkey_str).map_err(|e| e.to_string())?;

    // sig may be raw minisign text or base64-encoded (latest.json / .sig files wrap in b64).
    // Trim whitespace: .sig files often have a trailing \n which breaks base64 decode.
    let input = sig_b64_or_raw.trim();
    let sig_str = if input.starts_with("untrusted comment:") {
        input.to_string()
    } else {
        let bytes = base64::engine::general_purpose::STANDARD
            .decode(input)
            .map_err(|e| e.to_string())?;
        String::from_utf8(bytes).map_err(|e| e.to_string())?
    };

    let sig = minisign_verify::Signature::decode(&sig_str).map_err(|e| e.to_string())?;
    pubkey.verify(file_bytes, &sig, false).map_err(|e| e.to_string())
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MediumItem {
    pub de: String,
    pub en: String,
    pub active: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LibraryMedium {
    pub id: String,
    pub de: String,
    pub en: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Safety {
    pub emergency_stop: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Machine {
    pub id: String,
    pub number: String,
    pub phase: String,
    pub media: Vec<MediumItem>,
    pub safety: Safety,
    #[serde(default)]
    pub note: String,
    #[serde(default)]
    pub work_permit: bool,
    #[serde(default)]
    pub work_permit_days: u32,
    #[serde(default)]
    pub work_permit_date: String,
    #[serde(default)]
    pub responsible: String,
    #[serde(default)]
    pub last_changed: String,
}

#[derive(Debug, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct Db {
    pub machines: Vec<Machine>,
    #[serde(default)]
    pub media_library: Vec<LibraryMedium>,
}

fn db_path(app: &tauri::AppHandle) -> PathBuf {
    let data_dir = app
        .path()
        .app_data_dir()
        .expect("failed to resolve app data dir");
    fs::create_dir_all(&data_dir).ok();
    data_dir.join("machines.json")
}

fn read_db(app: &tauri::AppHandle) -> Db {
    let path = db_path(app);
    fs::read_to_string(&path)
        .ok()
        .and_then(|content| serde_json::from_str(&content).ok())
        .unwrap_or_default()
}

fn write_db(app: &tauri::AppHandle, db: &Db) -> Result<(), String> {
    let path = db_path(app);
    let json = serde_json::to_string_pretty(db).map_err(|e| e.to_string())?;
    fs::write(path, json).map_err(|e| e.to_string())
}

#[tauri::command]
fn get_machines(app: tauri::AppHandle) -> Vec<Machine> {
    read_db(&app).machines
}

#[tauri::command]
fn save_machine(app: tauri::AppHandle, machine: Machine) -> Result<(), String> {
    let mut db = read_db(&app);
    if let Some(pos) = db.machines.iter().position(|m| m.id == machine.id) {
        eprintln!("[msd] save_machine: update id={} number={}", machine.id, machine.number);
        db.machines[pos] = machine;
    } else {
        eprintln!("[msd] save_machine: insert id={} number={}", machine.id, machine.number);
        db.machines.push(machine);
    }
    write_db(&app, &db)
}

#[tauri::command]
fn delete_machine(app: tauri::AppHandle, id: String) -> Result<(), String> {
    eprintln!("[msd] delete_machine: id={}", id);
    let mut db = read_db(&app);
    db.machines.retain(|m| m.id != id);
    write_db(&app, &db)
}

#[tauri::command]
fn get_media_library(app: tauri::AppHandle) -> Vec<LibraryMedium> {
    read_db(&app).media_library
}

#[tauri::command]
fn save_media_library(app: tauri::AppHandle, library: Vec<LibraryMedium>) -> Result<(), String> {
    let mut db = read_db(&app);
    db.media_library = library;
    write_db(&app, &db)
}

#[derive(Debug, Clone, Serialize)]
pub struct UsbUpdate {
    pub path: String,
    pub version: String,
}


fn read_sig_file(sig_path: &str) -> Option<String> {
    let bytes = fs::read(sig_path).ok()?;
    // Strip UTF-8 BOM if present (Windows may add one).
    let bytes = bytes.strip_prefix(b"\xef\xbb\xbf").unwrap_or(&bytes);
    // Trim trailing whitespace/newlines so base64 decode doesn't fail.
    let s = String::from_utf8(bytes.to_vec()).ok()?;
    Some(s.trim().to_string())
}

fn check_deb_file(path: std::path::PathBuf, current: &str) -> Option<UsbUpdate> {
    let name = path.file_name()?.to_str()?;
    if name.starts_with("._") { return None; }
    if !name.ends_with("_arm64.deb") { return None; }
    let version = name.split('_').nth(1).unwrap_or("0.0.0").to_string();
    if !semver_gt(&version, current) { return None; }
    let sig_path = format!("{}.sig", path.to_string_lossy());
    let sig_str = read_sig_file(&sig_path)?;
    let deb_bytes = fs::read(&path).ok()?;
    verify_update_sig(&deb_bytes, &sig_str).ok()?;
    Some(UsbUpdate { path: path.to_string_lossy().to_string(), version })
}

fn scan_for_usb_update() -> Option<UsbUpdate> {
    let current = env!("CARGO_PKG_VERSION");
    let mounts = fs::read_to_string("/proc/mounts").unwrap_or_default();
    let mut best: Option<UsbUpdate> = None;
    for line in mounts.lines() {
        let mut parts = line.split_whitespace();
        let dev = parts.next().unwrap_or("");
        let mountpoint = parts.next().unwrap_or("");
        if !dev.starts_with("/dev/sd") { continue; }
        let Ok(entries) = fs::read_dir(mountpoint) else { continue; };
        for entry in entries.flatten() {
            if let Some(u) = check_deb_file(entry.path(), current) {
                let is_better = best.as_ref().map_or(true, |b| semver_gt(&u.version, &b.version));
                if is_better { best = Some(u); }
            }
        }
    }
    best
}

fn verify_deb_package(path: &str) -> Result<(), String> {
    let out = std::process::Command::new("dpkg-deb")
        .args(["--field", path, "Package"])
        .output()
        .map_err(|e| e.to_string())?;
    let pkg = String::from_utf8_lossy(&out.stdout).trim().to_lowercase();
    if pkg != "machine-status-display" {
        return Err(format!("rejected: package name '{}' is not 'machine-status-display'", pkg));
    }
    Ok(())
}

fn install_deb(path: &str) -> Result<(), String> {
    verify_deb_package(path)?;
    // Run update script in a transient systemd cgroup so it survives
    // machine-status.service stopping mid-update.
    std::process::Command::new("sudo")
        .args([
            "systemd-run",
            "--no-block",
            "--collect",
            "--quiet",
            "/usr/local/sbin/msd-update.sh",
            path,
        ])
        .spawn()
        .map_err(|e| e.to_string())?;
    Ok(())
}

#[tauri::command]
fn install_usb_update(path: String) -> Result<(), String> {
    install_deb(&path)
}

#[derive(Debug, Clone, Serialize)]
pub struct OtaUpdate {
    pub version: String,
    pub path: String,
}

fn has_internet() -> bool {
    use std::net::TcpStream;
    TcpStream::connect_timeout(
        &"1.1.1.1:443".parse().unwrap(),
        std::time::Duration::from_secs(3),
    )
    .is_ok()
}

fn fetch_latest_ota() -> Option<(String, String, String)> {
    // Use latest.json (same endpoint as tauri-plugin-updater) — contains version + deb sig
    let body: serde_json::Value = ureq::get(
        "https://github.com/joe2824/machine_status_display/releases/latest/download/latest.json",
    )
    .set("User-Agent", "machine-status-display")
    .call()
    .ok()?
    .into_json()
    .ok()?;

    let version = body["version"].as_str()?.to_string();

    let deb = &body["platforms"]["linux-aarch64-deb"];
    let url = deb["url"].as_str()?.to_string();
    let sig = deb["signature"].as_str()?.to_string();

    Some((version, url, sig))
}

fn semver_gt(remote: &str, current: &str) -> bool {
    fn parse(v: &str) -> (u32, u32, u32) {
        let mut p = v.split('.');
        let a = p.next().and_then(|x| x.parse().ok()).unwrap_or(0);
        let b = p.next().and_then(|x| x.parse().ok()).unwrap_or(0);
        let c = p.next().and_then(|x| x.parse().ok()).unwrap_or(0);
        (a, b, c)
    }
    parse(remote) > parse(current)
}

fn download_and_verify_deb(url: &str, version: &str, sig_b64: &str) -> Option<String> {
    let dest = format!("/tmp/machine-status-display_{}_arm64.deb", version);
    let bytes = if std::path::Path::new(&dest).exists() {
        fs::read(&dest).ok()?
    } else {
        let response = ureq::get(url)
            .set("User-Agent", "machine-status-display")
            .call()
            .ok()?;
        let mut buf = Vec::new();
        std::io::copy(&mut response.into_reader(), &mut buf).ok()?;
        fs::write(&dest, &buf).ok()?;
        buf
    };
    if verify_update_sig(&bytes, sig_b64).is_err() {
        fs::remove_file(&dest).ok();
        return None;
    }
    Some(dest)
}

#[tauri::command]
fn install_ota_update(path: String) -> Result<(), String> {
    install_deb(&path)
}

#[tauri::command]
fn debug_usb_scan() -> Vec<String> {
    let current = env!("CARGO_PKG_VERSION");
    let mut results: Vec<String> = Vec::new();
    let mut detail: Vec<String> = Vec::new();

    let mounts = fs::read_to_string("/proc/mounts").unwrap_or_default();
    let mounted: Vec<(String, String)> = mounts.lines()
        .filter_map(|l| {
            let mut p = l.split_whitespace();
            let dev = p.next()?;
            let mp  = p.next()?;
            if dev.starts_with("/dev/sd") { Some((dev.to_string(), mp.to_string())) } else { None }
        })
        .collect();

    let mount_summary = if mounted.is_empty() {
        "USB: none mounted".to_string()
    } else {
        mounted.iter().map(|(d, m)| format!("{} → {}", d, m)).collect::<Vec<_>>().join(", ")
    };

    // Scan /media only (our udev rule mounts here; /run/media not used)
    for (_, mountpoint) in &mounted {
        let mpath = std::path::Path::new(mountpoint);
        let all_files: Vec<String> = fs::read_dir(mpath)
            .map(|rd| rd.flatten()
                .filter_map(|e| e.file_name().into_string().ok())
                .collect())
            .unwrap_or_default();

        detail.push(format!("{}:", mountpoint));
        for f in all_files.iter().filter(|f| !f.starts_with('.')) {
            detail.push(format!("  {}", f));
        }

        // Collect all valid updates, then pick the highest version
        let mut valid: Vec<(String, String)> = Vec::new(); // (version, status_line)

        for name in &all_files {
            if name.starts_with("._") { continue; }
            if !name.ends_with("_arm64.deb") { continue; }

            let path = mpath.join(name);
            let version = name.split('_').nth(1).unwrap_or("?").to_string();
            let newer = semver_gt(&version, current);
            // sig is always paired with its own deb — same name + .sig
            let sig_name = format!("{}.sig", name);
            let sig_path = mpath.join(&sig_name);
            let sig_present = all_files.iter().any(|f| f == &sig_name);

            detail.push(format!("  v{}  deb+sig: {}", version,
                if sig_present { "paired ✓" } else { "sig MISSING ✗" }));

            if !sig_present {
                results.push(format!("✗ v{} — sig missing ({} not found)", version, sig_name));
                continue;
            }

            let sig_str = match fs::read(&sig_path) {
                Err(e) => {
                    results.push(format!("✗ v{} — sig read error: {}", version, e));
                    continue;
                }
                Ok(raw) => {
                    let raw = raw.strip_prefix(b"\xef\xbb\xbf").unwrap_or(&raw).to_vec();
                    match String::from_utf8(raw.clone()) {
                        Ok(s) => s,
                        Err(_) => {
                            let hex: String = raw.iter().take(16)
                                .map(|b| format!("{:02x}", b))
                                .collect::<Vec<_>>().join(" ");
                            results.push(format!("✗ v{} — sig binary, not text: {}", version, hex));
                            continue;
                        }
                    }
                }
            };

            let deb_bytes = match fs::read(&path) {
                Err(e) => { results.push(format!("✗ v{} — deb read error: {}", version, e)); continue; }
                Ok(b) => b,
            };

            match verify_update_sig(&deb_bytes, &sig_str) {
                Err(e)    => results.push(format!("✗ v{} — sig invalid: {}", version, e)),
                Ok(_) if newer => { valid.push((version.clone(), format!("✓ v{} valid", version))); }
                Ok(_) if version == current => results.push(format!("= v{} — same as installed, no update needed", version)),
                Ok(_)     => results.push(format!("↓ v{} — valid but older than v{}", version, current)),
            }
        }

        if !valid.is_empty() {
            // Pick highest version — same logic as scan_for_usb_update
            valid.sort_by(|a, b| if semver_gt(&a.0, &b.0) { std::cmp::Ordering::Less } else { std::cmp::Ordering::Greater });
            let (best_ver, _) = &valid[0];
            for (ver, line) in &valid {
                if ver == best_ver {
                    results.push(format!("{} — NEWEST → banner shown", line));
                } else {
                    results.push(format!("{} — skipped (older than v{})", line, best_ver));
                }
            }
        }
    }

    let sep = "─".repeat(34);
    let mut out = vec![
        format!("v{}  |  {}", current, mount_summary),
        sep.clone(),
    ];
    if results.is_empty() {
        out.push(if mounted.is_empty() {
            "  no USB drive mounted".to_string()
        } else {
            "  no *_arm64.deb found".to_string()
        });
    } else {
        out.extend(results);
    }
    out.push(sep);
    out.extend(detail);
    out
}

#[tauri::command]
fn get_service_log() -> Vec<String> {
    let out = std::process::Command::new("journalctl")
        .args(["-u", "machine-status", "-n", "200", "--no-pager", "--output=short-monotonic"])
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).to_string())
        .unwrap_or_else(|e| format!("journalctl failed: {}", e));
    out.lines().map(|l| l.to_string()).collect()
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(tauri_plugin_process::init())
        .setup(|app| {
            eprintln!("[msd] startup v{}", env!("CARGO_PKG_VERSION"));

            // USB update scanner thread (every 5 s)
            let handle = app.handle().clone();
            std::thread::spawn(move || {
                let mut last_path = String::new();
                loop {
                    std::thread::sleep(std::time::Duration::from_secs(5));
                    if let Some(update) = scan_for_usb_update() {
                        if update.path != last_path {
                            eprintln!("[msd] usb-update found: {} v{}", update.path, update.version);
                            last_path = update.path.clone();
                            handle.emit("usb-update-available", update).ok();
                        }
                    } else {
                        if !last_path.is_empty() {
                            eprintln!("[msd] usb-update gone (drive removed)");
                        }
                        last_path.clear();
                    }
                }
            });

            // OTA update checker thread (every 30 min; cheap connectivity pre-check)
            let handle2 = app.handle().clone();
            std::thread::spawn(move || {
                let current = env!("CARGO_PKG_VERSION");
                let mut last_notified = String::new();
                std::thread::sleep(std::time::Duration::from_secs(30));
                loop {
                    eprintln!("[msd] ota-check: has_internet={}", has_internet());
                    if has_internet() {
                        match fetch_latest_ota() {
                            None => eprintln!("[msd] ota-check: fetch failed"),
                            Some((version, url, sig)) => {
                                eprintln!("[msd] ota-check: latest={} current={}", version, current);
                                if version != last_notified && semver_gt(&version, current) {
                                    eprintln!("[msd] ota-check: downloading {}", url);
                                    if let Some(path) = download_and_verify_deb(&url, &version, &sig) {
                                        eprintln!("[msd] ota-update ready: {}", path);
                                        last_notified = version.clone();
                                        handle2.emit("ota-update-available", OtaUpdate { version, path }).ok();
                                    } else {
                                        eprintln!("[msd] ota-check: download/verify failed");
                                    }
                                }
                            }
                        }
                    }
                    std::thread::sleep(std::time::Duration::from_secs(30 * 60));
                }
            });

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            get_machines,
            save_machine,
            delete_machine,
            get_media_library,
            save_media_library,
            install_usb_update,
            install_ota_update,
            debug_usb_scan,
            get_service_log
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
