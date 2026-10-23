use base::config::keys;
use hbb_common::{config, log};

const APP_NAME: &str = "Velora";
const RENDEZVOUS_SERVER: &str = match option_env!("VELORA_RENDEZVOUS_SERVER") {
    Some(v) => v,
    None => "velora.larchertech.com",
};
const RS_PUB_KEY: &str = match option_env!("VELORA_RS_PUB_KEY") {
    Some(v) => v,
    None => "k4qh2qtb5Pu7PPelodmeP1H5pq4JjXIqnNjJiy2T+VU=",
};

pub const SOURCE_URL: &str = "https://github.com/MatheusLarcher/velora-desk";
/// Local option toggled by the user in the app; off unless they turn it on.
pub const OPTION_START_WITH_WINDOWS: &str = "velora-start-with-windows";

/// Mirrors the user's choice into HKCU\...\Run (per user, no admin). The entry opens
/// the normal, visible app window at login.
#[cfg(windows)]
pub fn apply_start_with_windows(enabled: bool) -> hbb_common::ResultType<()> {
    use winreg::{enums::*, RegKey};
    let run = RegKey::predef(HKEY_CURRENT_USER).open_subkey_with_flags(
        "Software\\Microsoft\\Windows\\CurrentVersion\\Run",
        KEY_SET_VALUE,
    )?;
    if enabled {
        let exe = std::env::current_exe()?;
        run.set_value(APP_NAME, &format!("\"{}\"", exe.display()))?;
    } else {
        match run.delete_value(APP_NAME) {
            Err(e) if e.kind() != std::io::ErrorKind::NotFound => return Err(e.into()),
            _ => {}
        }
    }
    Ok(())
}

const SHORT_ID_MIN: u32 = 1000;
const SHORT_ID_SPAN: u32 = 9000;

fn is_short_id(id: &str) -> bool {
    id.len() == 4 && id.bytes().all(|b| b.is_ascii_digit()) && !id.starts_with('0')
}

/// The client is identified by a 4-digit ID. The first one is derived from the stock
/// RustDesk ID, so every process of this PC (server, UI, service) arrives at the same value.
pub fn ensure_short_id() {
    let id = config::Config::get_id();
    if id.is_empty() || is_short_id(&id) {
        return;
    }
    let hash = id
        .bytes()
        .fold(2166136261u32, |h, b| (h ^ b as u32).wrapping_mul(16777619));
    config::Config::set_id(&(SHORT_ID_MIN + hash % SHORT_ID_SPAN).to_string());
}

/// Replaces the ID after the server reports it is taken by another PC.
pub fn regenerate_short_id() {
    use hbb_common::rand::Rng;
    let old = config::Config::get_id();
    let new = hbb_common::rand::thread_rng()
        .gen_range(SHORT_ID_MIN..SHORT_ID_MIN + SHORT_ID_SPAN)
        .to_string();
    config::Config::set_id(&new);
    log::info!("id updated from {} to {}", old, new);
}

// No password ships in the binary: the first session is approved by a click on the
// controlled side, and only the user of that PC can set the permanent password.
pub fn apply_builtin() {
    *config::APP_NAME.write().unwrap() = APP_NAME.to_owned();
    let relay = format!("{}:{}", RENDEZVOUS_SERVER, config::RELAY_PORT);
    let overwrite = [
        (keys::OPTION_CUSTOM_RENDEZVOUS_SERVER, RENDEZVOUS_SERVER),
        (keys::OPTION_RELAY_SERVER, relay.as_str()),
        (keys::OPTION_KEY, RS_PUB_KEY),
        (keys::OPTION_ENABLE_CHECK_UPDATE, "N"),
        (keys::OPTION_ALLOW_AUTO_UPDATE, "N"),
        // The session window on the controlled side must always be visible.
        ("allow-hide-cm", "N"),
        (keys::OPTION_HIDE_TRAY, "N"),
    ];
    let mut settings = config::OVERWRITE_SETTINGS.write().unwrap();
    for (k, v) in overwrite {
        settings.insert(k.to_owned(), v.to_owned());
    }
    drop(settings);
    // No "Powered by" link to the upstream project in the interface.
    config::BUILTIN_SETTINGS
        .write()
        .unwrap()
        .insert("hide-powered-by-me".to_owned(), "Y".to_owned());
    // Defaults the user can still change in Settings > Security.
    let mut defaults = config::DEFAULT_SETTINGS.write().unwrap();
    defaults.insert("allow-remote-config-modification".to_owned(), "Y".to_owned());
    // Only the permanent password by default; the user may enable the one-time
    // password, or both, in Settings.
    defaults.insert(
        keys::OPTION_VERIFICATION_METHOD.to_owned(),
        "use-permanent-password".to_owned(),
    );
}

const SAVED_PASSWORD_FILE: &str = "velora_saved_password";

/// The permanent password is stored as a hash, so a copy is kept, encrypted, to let
/// the user of this PC see the password again. It is written by whichever local
/// process set the password (main window or session window), so it lives in its own
/// file instead of the per-process local config.
pub fn remember_password(password: &str) {
    let path = config::Config::path(SAVED_PASSWORD_FILE);
    if password.is_empty() {
        std::fs::remove_file(&path).ok();
        return;
    }
    let enc = hbb_common::password_security::encrypt_str_or_original(password, "00", 128);
    if let Err(e) = std::fs::write(&path, enc) {
        log::warn!("Failed to keep the saved password: {e}");
    }
}

/// Empty when no local permanent password is set or it was set before this copy existed.
pub fn saved_password() -> String {
    if !crate::ui_interface::is_local_permanent_password_set() {
        return String::new();
    }
    match std::fs::read_to_string(config::Config::path(SAVED_PASSWORD_FILE)) {
        Ok(enc) => hbb_common::password_security::decrypt_str_or_original(enc.trim(), "00").0,
        Err(_) => String::new(),
    }
}

/// Folder chosen in Settings for files received through the session chat.
pub const OPTION_CHAT_FILES_DIR: &str = "velora-chat-files-dir";
/// Destination the controlling side sends for a chat file; this device decides the folder.
pub const CHAT_FILE_PREFIX: &str = "velora-chat:";

/// The configured folder, or the Downloads folder of the user of this device.
pub fn chat_files_dir() -> std::path::PathBuf {
    let custom = config::Config::get_option(OPTION_CHAT_FILES_DIR);
    if !custom.trim().is_empty() {
        return std::path::PathBuf::from(custom.trim());
    }
    #[cfg(any(target_os = "android", target_os = "ios"))]
    {
        config::Config::get_home().join("Download")
    }
    #[cfg(not(any(target_os = "android", target_os = "ios")))]
    {
        crate::platform::get_active_user_home()
            .unwrap_or_else(config::Config::get_home)
            .join("Downloads")
    }
}

/// Full path for a chat file named by the peer. Only the file name is kept, so the peer
/// cannot write outside the folder, and an existing file is never overwritten.
pub fn chat_file_target(peer_name: &str) -> Option<String> {
    let name = peer_name
        .rsplit(|c| c == '/' || c == '\\')
        .next()
        .unwrap_or_default()
        .trim();
    if name.is_empty() || name == "." || name == ".." {
        return None;
    }
    let dir = chat_files_dir();
    if let Err(e) = std::fs::create_dir_all(&dir) {
        log::warn!("Failed to create the chat files folder {:?}: {e}", dir);
        return None;
    }
    let candidate = dir.join(name);
    if !candidate.exists() {
        return Some(candidate.to_string_lossy().into_owned());
    }
    let path = std::path::Path::new(name);
    let stem = path.file_stem().map(|s| s.to_string_lossy().into_owned());
    let ext = path.extension().map(|s| s.to_string_lossy().into_owned());
    for n in 1..1000 {
        let numbered = match (&stem, &ext) {
            (Some(s), Some(e)) => format!("{s} ({n}).{e}"),
            _ => format!("{name} ({n})"),
        };
        let candidate = dir.join(numbered);
        if !candidate.exists() {
            return Some(candidate.to_string_lossy().into_owned());
        }
    }
    None
}

/// True when this copy runs from somewhere else than the installation of this PC. Such a
/// copy cannot talk to the installed service (it rejects other binaries), so the screen
/// would stay "not ready" until the installation is updated with this copy.
pub fn running_outside_installation() -> bool {
    #[cfg(windows)]
    {
        let (_, _, _, installed_exe) = crate::platform::windows::get_install_info();
        if std::fs::metadata(&installed_exe).is_err() {
            return false;
        }
        let norm = |p: &std::path::Path| {
            p.canonicalize()
                .unwrap_or_else(|_| p.to_path_buf())
                .to_string_lossy()
                .to_lowercase()
        };
        match std::env::current_exe() {
            Ok(cur) => norm(&cur) != norm(std::path::Path::new(&installed_exe)),
            Err(_) => false,
        }
    }
    #[cfg(not(windows))]
    {
        false
    }
}
