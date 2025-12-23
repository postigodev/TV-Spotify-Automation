import os
import sys
import time
import spotipy
from dotenv import load_dotenv
from spotipy.oauth2 import SpotifyOAuth

load_dotenv()
sys.stdout.reconfigure(line_buffering=True)

TARGET_NAME_HINTS = ["fire", "tv", "amazon", "spotify", "insignia", "toshiba", "osint"]

START = time.time()

def log(msg):
    print(f"[{time.time() - START:6.2f}s] {msg}")


def pick_device(devices, hints):
    for d in devices:
        name = (d.get("name") or "").lower()
        if any(h in name for h in hints):
            return d
    return None


def ensure_playing_on_device(sp, target_id, tries=5, delay=0.25):
    """
    Faster: avoid spamming current_playback() every loop.
    Do one check, then a few start_playback nudges, then one final check.
    """
    # quick initial check
    try:
        pb = sp.current_playback()
        if pb and pb.get("device", {}).get("id") == target_id and pb.get("is_playing"):
            return True
    except Exception:
        pass

    # nudge playback a few times
    for i in range(tries):
        try:
            sp.start_playback(device_id=target_id)
        except Exception:
            pass
        time.sleep(delay)

    # final confirmation
    try:
        pb = sp.current_playback()
        return bool(pb and pb.get("device", {}).get("id") == target_id and pb.get("is_playing"))
    except Exception:
        return False


def main():
    client_id = os.environ.get("SPOTIPY_CLIENT_ID")
    client_secret = os.environ.get("SPOTIPY_CLIENT_SECRET")
    redirect_uri = os.environ.get("SPOTIPY_REDIRECT_URI", "http://127.0.0.1:8888/callback")

    if not client_id or not client_secret:
        print("Missing SPOTIPY_CLIENT_ID / SPOTIPY_CLIENT_SECRET.")
        sys.exit(1)

    scope = "user-read-playback-state user-modify-playback-state user-read-currently-playing"

    sp = spotipy.Spotify(
        auth_manager=SpotifyOAuth(
            client_id=client_id,
            client_secret=client_secret,
            redirect_uri=redirect_uri,
            scope=scope,
            open_browser=True,
            cache_path=os.path.join(os.path.dirname(__file__), ".spotify_cache"),
        ),
        requests_timeout=4,
        retries=0,
    )
    log("Spotify client ready")

    # Current playback (may be None)
    playback = sp.current_playback()
    log("Fetched current_playback")

    is_playing = bool(playback and playback.get("is_playing"))
    current_device_id = playback.get("device", {}).get("id") if playback else None

    # Find TV device (retry a bit because it can appear late)
    chosen = None
    hints = [h.lower() for h in TARGET_NAME_HINTS]
    for i in range(8):
        log(f"devices() attempt {i+1}")
        resp = sp.devices()
        devices = resp.get("devices", [])
        chosen = pick_device(devices, hints)
        if chosen:
            break
        time.sleep(1)

    if not chosen:
        print("TV device not found.")
        log("Target device found")
        sys.exit(2)

    target_id = chosen["id"]

# ---- TOGGLE LOGIC (device-aware) ----

# Case 1: TV is active and playing → PAUSE
    if is_playing and current_device_id == target_id:
        sp.pause_playback()
        print("Paused (TV was playing).")
        log("About to exit (paused)")
        sys.exit(10)

    # Case 2: TV is active but PAUSED → RESUME (no transfer)
    if (not is_playing) and current_device_id == target_id:
        sp.start_playback(device_id=target_id)
        print("Resumed on TV.")
        log("About to exit (resume on TV)")
        sys.exit(0)

    # Case 3: Not on TV → TRANSFER + PLAY
    log("Calling transfer_playback (force_play=False)")
    sp.transfer_playback(device_id=target_id, force_play=False)
    log("transfer_playback done")

    log("Calling start_playback on TV")
    try:
        sp.start_playback(device_id=target_id)
    except Exception:
        pass
    log("start_playback done (or ignored)")

    print("Transferred to TV and playing/resumed.")
    log("About to exit")
    sys.exit(0)




if __name__ == "__main__":
    main()
