use anyhow::Context;
use dotenvy::dotenv;
use rspotify::prelude::BaseClient;
use rspotify::{
    AuthCodeSpotify, Config, Credentials, OAuth, Token, clients::OAuthClient,
    model::AdditionalType, scopes,
};
use serde_json;
use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::Command;
use std::time::Instant;

struct AppConfig {
    client_id: String,
    client_secret: String,
    redirect_uri: String,
    firetv_ip: String,
}

//init_client
fn init_config() -> Result<AppConfig, env::VarError> {
    Ok(AppConfig {
        client_id: env::var("RSPOTIFY_CLIENT_ID")?,
        client_secret: env::var("RSPOTIFY_CLIENT_SECRET")?,
        redirect_uri: env::var("RSPOTIFY_REDIRECT_URI")?,
        firetv_ip: env::var("FIRETV_IP")?,
    })
}

// Return stdout as String so callers can parse it
fn call_adb_stdout(args: &[&str]) -> anyhow::Result<String> {
    let output = Command::new("adb").args(args).output()?;
    if !output.status.success() {
        anyhow::bail!(
            "adb {:?} failed: {}",
            args,
            String::from_utf8_lossy(&output.stderr).trim()
        );
    }
    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

fn connect_tv(ip: &str) -> anyhow::Result<()> {
    let needle = format!("{}:5555", ip);
    let devices = call_adb_stdout(&["devices"])?;
    if devices.contains(&needle) {
        return Ok(());
    }
    call_adb_stdout(&["connect", &needle])?;
    let devices2 = call_adb_stdout(&["devices"])?;
    if devices2.contains(&needle) {
        return Ok(());
    } else {
        anyhow::bail!("Could not connect to TV at {}", needle);
    }
}
// detects if TV on or off
fn screen_is_on() -> anyhow::Result<bool> {
    let output = call_adb_stdout(&["shell", "dumpsys", "power"])?;
    let s = output.to_lowercase();
    return Ok(s.contains("minteractive=true")
        || s.contains("mscreenon=true")
        || s.contains("state=on")
        || s.contains("mwakefulness=awake")
        || s.contains("mwakefulness=dreaming"));
}

// turns on the tv
async fn ensure_awake(max_tries: u32) -> anyhow::Result<bool> {
    for _ in 0..max_tries {
        if screen_is_on()? {
            return Ok(true);
        }
        call_adb_stdout(&["shell", "input", "keyevent", "224"])?;
        tokio::time::sleep(std::time::Duration::from_millis(800)).await;
    }
    screen_is_on()
}

fn open_spotify() -> anyhow::Result<()> {
    call_adb_stdout(&["shell", "monkey", "-p", "com.spotify.tv.android", "1"])?;
    Ok(())
}

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
        token_refreshing: true,
        cache_path: PathBuf::from(
            r"C:\Users\akuma\OneDrive\Desktop\launch-spotifytv\launcher-rs\.spotify_cache\token.json",
        ),
        ..Default::default()
    };

    AuthCodeSpotify::with_config(creds, oauth, config)
}

async fn ensure_token(spotify: &AuthCodeSpotify) -> anyhow::Result<()> {
    let _ = spotify.read_token_cache(true).await;

    let has_token = spotify
        .get_token()
        .lock()
        .await
        .map_err(|e| anyhow::anyhow!("{e:?}"))?
        .is_some();

    if !has_token {
        let token_path = spotify.get_config().cache_path.clone();
        let raw = fs::read_to_string(&token_path)
            .with_context(|| format!("failed to read token cache at {:?}", token_path))?;
        let token: Token = serde_json::from_str(&raw)
            .context("failed to parse token cache JSON into rspotify::Token")?;

        let token_mutex = spotify.get_token();

        let mut guard = token_mutex
            .lock()
            .await
            .map_err(|e| anyhow::anyhow!("{e:?}"))?;

        *guard = Some(token);
    }

    spotify
        .refresh_token()
        .await
        .context("refresh_token failed")?;
    Ok(())
}

async fn playback_status(spotify: &AuthCodeSpotify) -> anyhow::Result<Option<(String, bool)>> {
    let playback = spotify
        .current_playback(None, Some(&[AdditionalType::Episode]))
        .await?;

    Ok(playback.and_then(|ctx| {
        let is_playing = ctx.is_playing;
        let device_id = ctx.device.id?.to_string(); // <- DeviceId -> String
        Some((device_id, is_playing))
    }))
}

async fn transfer_session(spotify: &AuthCodeSpotify) -> anyhow::Result<()> {
    let status = playback_status(spotify).await?;
    let (current_device, is_playing) = match status {
        Some((id, playing)) => (Some(id), playing),
        None => (None, false),
    };

    println!(
        "Current device: {:?}, is_playing: {}",
        current_device, is_playing
    );

    let target = spotify
        .device()
        .await?
        .into_iter()
        .find(|d| d.name.contains("TV"))
        .ok_or_else(|| anyhow::anyhow!("Could not find target device containing 'TV'"))?;

    let target_id = target
        .id
        .clone()
        .ok_or_else(|| anyhow::anyhow!("Target device found but has no id"))?
        .to_string();

    if current_device.as_deref() == Some(target_id.as_str()) {
        // Toggle on target
        if is_playing {
            spotify.pause_playback(Some(target_id.as_str())).await?;
            println!("Paused playback on target device");
        } else {
            spotify
                .resume_playback(Some(target_id.as_str()), None)
                .await?;
            println!("Resumed playback on target device");
        }
    } else {
        // Transfer to target and start playing
        spotify.transfer_playback(&target_id, Some(true)).await?;
        println!("Transferred playback to target device");
    }

    Ok(())
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let start = Instant::now();
    dotenv().ok();
    let cfg = init_config()?;

    // ---- TV ----
    connect_tv(&cfg.firetv_ip)?;
    ensure_awake(4).await?;
    open_spotify()?;

    // ---- Spotify client ----
    let spotify = build_spotify(&cfg);

    // Ensure cache directory exists (parent of cache file)
    if let Some(parent) = spotify.get_config().cache_path.parent() {
        std::fs::create_dir_all(parent)?;
    }

    // Garantee auth was done
    ensure_token(&spotify).await?;

    // ---- Transfer session ----
    transfer_session(&spotify).await?;
    println!("Done. Elapsed: {:.2?}", start.elapsed().as_secs_f64());
    Ok(())
}
