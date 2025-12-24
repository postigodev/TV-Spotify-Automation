use dotenvy::dotenv;
use rspotify::{AuthCodeSpotify, Config, Credentials, OAuth, clients::OAuthClient, scopes};
use std::env;
use std::io;
use std::path;
use std::process::Command;

struct AppConfig {
    client_id: String,
    client_secret: String,
    redirect_uri: String,
    firetv_ip: String,
}

//init_client
fn init_config() -> Result<AppConfig, env::VarError> {
    dotenv().ok();
    Ok(AppConfig {
        client_id: env::var("RSPOTIFY_CLIENT_ID")?,
        client_secret: env::var("RSPOTIFY_CLIENT_SECRET")?,
        redirect_uri: env::var("RSPOTIFY_REDIRECT_URI")?,
        firetv_ip: env::var("FIRETV_IP")?,
    })
}

// Return stdout as String so callers can parse it
fn call_adb_stdout(args: &[&str]) -> Result<String, std::io::Error> {
    let output = Command::new("adb").args(args).output()?;
    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

fn connect_tv(ip: &str) -> bool {
    let needle = format!("{}:5555", ip);
    let devices = call_adb_stdout(&["devices"]).expect("adb devices failed");
    let mut is_connected = devices.contains(&needle);
    if !is_connected {
        call_adb_stdout(&["connect", &needle]).expect("connection fail");
        let devices2 = call_adb_stdout(&["devices"]).expect("adb devices failed");
        is_connected = devices2.contains(&needle);
    }
    return is_connected;
}

// detects if TV on or off
fn screen_is_on() -> bool {
    if let Ok(out) = call_adb_stdout(&["shell", "dumpsys", "power"]) {
        let s = out.to_lowercase();
        return s.contains("minteractive=true")
            || s.contains("mscreenon=true")
            || s.contains("state=on")
            || s.contains("mwakefulness=awake")
            || s.contains("mwakefulness=dreaming");
    }
    false
}

// turns on the tv
fn ensure_awake(max_tries: u32) -> bool {
    for _ in 0..max_tries {
        if screen_is_on() {
            return true;
        }
        let _ = call_adb_stdout(&["shell", "input", "keyevent", "224"]);
        std::thread::sleep(std::time::Duration::from_millis(800));
    }
    screen_is_on()
}

fn open_spotify() {
    call_adb_stdout(&["shell", "monkey", "-p", "com.spotify.tv.android", "1"])
        .expect("failed to open spotify");
}

/*
fn build_spotify(cfg: &AppConfig) -> AuthCodeSpotify {
    let creds = Credentials::new(&cfg.client_id, &cfg.client_secret);

    let oauth = OAuth {
        redirect_uri: cfg.redirect_uri.clone(),
        scopes: scopes!(
            "user-read-playback-state",
            "user-modify-playback-state",
            "user-read-currently-playing"
        ),
        ..Default::default()
    };

    let config = Config {
        token_cached: true,
        cache_path: ".spotify_cache_rust.json".into(),
        ..Default::default()
    };

    AuthCodeSpotify::with_config(creds, oauth, config)
} */

fn call_python() -> io::Result<()> {
    let current_dir = env::current_dir()?;
    let path = current_dir.join("src").join("spotify_transfer.py");
    let output = Command::new("python3").arg(&path).output()?;

    println!("stdout:\n{}", String::from_utf8_lossy(&output.stdout));
    eprintln!("stderr:\n{}", String::from_utf8_lossy(&output.stderr));

    Ok(())
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let cfg = init_config()?;
    println!("adb connected? {}", connect_tv(&cfg.firetv_ip));
    ensure_awake(4);
    open_spotify();
    call_python()?;
    println!("Done.");
    Ok(())

    // SPOTIFY UNDER DEVELOPMENT
    /*let spotify = build_spotify(&cfg);
    let auth_url = spotify.get_authorize_url(false)?;
    println!("Authorize URL:\n{auth_url}");

    spotify.prompt_for_token(&auth_url).await?;

    // ya tienes token
    let devices = spotify.device().await?;
    println!("Devices: {:#?}", devices);
    /*let target = devices
    .devices
    .iter()
    .find(|d| {
        d.name.to_lowercase().contains("tv")
            || d.name.to_lowercase().contains("fire")
            || d.name.to_lowercase().contains("spotify")
    })
    .or_else(|| devices.devices.first())
    .map(|d| d.id.clone())
    .flatten();*/
    Ok(()) */
}
