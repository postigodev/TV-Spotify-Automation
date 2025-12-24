use dotenvy::dotenv;
use std::env;
use std::process::Command;
struct Client {
    spotipy_client_id: String,
    spotipy_client_secret: String,
    spotipy_redirect_uri: String,
    firetv_ip: String,
}

impl Client {
    fn new(
        spotipy_client_id: String,
        spotipy_client_secret: String,
        spotipy_redirect_uri: String,
        firetv_ip: String,
    ) -> Client {
        Client {
            spotipy_client_id,
            spotipy_client_secret,
            spotipy_redirect_uri,
            firetv_ip,
        }
    }
}

//init_client
fn init_client() -> Result<Client, env::VarError> {
    dotenv().ok();

    Ok(Client::new(
        env::var("RSPOTIFY_CLIENT_ID")?,
        env::var("RSPOTIFY_CLIENT_SECRET")?,
        env::var("RSPOTIFY_REDIRECT_URI")?,
        env::var("FIRETV_IP")?,
    ))
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
fn pick_device(devices: &[&str]) {
    let target_name_hints = ["fire", "tv", "amazon", "spotify", "insignia", "toshiba", "osint"];
    for i in devices {
        println!("{}", i);
    }
}*/

fn main() {
    let _client = init_client().expect("Failed to load env vars");
    let hola = connect_tv(&_client.firetv_ip);
    println!("{}", hola);
    println!("{}", ensure_awake(4));
    open_spotify();
    //pick_device("");
    println!("Hello, world!");
}
