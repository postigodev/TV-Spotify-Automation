import os
import sys
import time
import spotipy
from dotenv import load_dotenv
from spotipy.oauth2 import SpotifyOAuth

load_dotenv()

TARGET_NAME_HINTS = ["fire", "tv", "amazon", "spotify", "insignia", "toshiba", "osint"]


def pick_device(devices, hints):
    for d in devices:
        name = (d.get("name") or "").lower()
        if any(h in name for h in hints):
            return d
    return None


def ensure_playing_on_device(sp, target_id, tries=6, delay=0.6):
    """
    After transfer, Spotify sometimes ends up paused depending on timing/device.
    We poll and if it's not playing, we try to start playback on the target device.
    """
    for _ in range(tries):
        pb = sp.current_playback()
        if pb and pb.get("device", {}).get("id") == target_id and pb.get("is_playing"):
            return True
        try:
            # This usually resumes the last context/queue on that device
            sp.start_playback(device_id=target_id)
        except Exception:
            pass
        time.sleep(delay)
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
        )
    )

    # Current playback (may be None)
    playback = sp.current_playback()
    is_playing = bool(playback and playback.get("is_playing"))
    current_device_id = playback.get("device", {}).get("id") if playback else None

    # Find TV device (retry a bit because it can appear late)
    chosen = None
    hints = [h.lower() for h in TARGET_NAME_HINTS]
    for _ in range(8):
        resp = sp.devices()
        devices = resp.get("devices", [])
        chosen = pick_device(devices, hints)
        if chosen:
            break
        time.sleep(1)

    if not chosen:
        print("TV device not found.")
        sys.exit(2)

    target_id = chosen["id"]

    # ---- TOGGLE LOGIC (device-aware) ----
    if is_playing and current_device_id == target_id:
        # Only pause if the TV is the active playing device
        sp.pause_playback()
        print("Paused (TV was playing).")
        sys.exit(10)

    # Otherwise: transfer to TV and play/resume
    sp.transfer_playback(device_id=target_id, force_play=True)

    # Safety: if Spotify ends up paused after transfer, force play on target
    ensure_playing_on_device(sp, target_id)

    print("Transferred to TV and playing/resumed.")
    sys.exit(0)


if __name__ == "__main__":
    main()
