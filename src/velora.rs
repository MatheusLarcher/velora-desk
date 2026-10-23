use base::config::keys;
use hbb_common::config;

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
        (keys::OPTION_VERIFICATION_METHOD, "use-permanent-password"),
        // The session window on the controlled side must always be visible.
        ("allow-hide-cm", "N"),
        (keys::OPTION_HIDE_TRAY, "N"),
    ];
    let mut settings = config::OVERWRITE_SETTINGS.write().unwrap();
    for (k, v) in overwrite {
        settings.insert(k.to_owned(), v.to_owned());
    }
}
