import os
import sys
import time
import spotipy
from dotenv import load_dotenv
load_dotenv()
from spotipy.oauth2 import SpotifyOAuth

# ---- CONFIG: cambia esto ----
TARGET_NAME_HINTS = [
    "fire", "tv", "amazon", "spotify", "insignia", "toshiba", "osint"
]
# -----------------------------

def pick_device(devices, hints):
    # elige el primer device cuyo nombre contenga alguna pista
    for d in devices:
        name = (d.get("name") or "").lower()
        if any(h in name for h in hints):
            return d
    return None

def main():
    client_id = os.environ.get("SPOTIPY_CLIENT_ID")
    client_secret = os.environ.get("SPOTIPY_CLIENT_SECRET")
    redirect_uri = os.environ.get("SPOTIPY_REDIRECT_URI", "http://127.0.0.1:8888/callback")

    if not client_id or not client_secret:
        print("Falta configurar SPOTIPY_CLIENT_ID / SPOTIPY_CLIENT_SECRET (variables de entorno).")
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

    # Reintenta unos segundos porque a veces el device de la TV aparece con delay
    chosen = None
    for _ in range(8):
        resp = sp.devices()
        devices = resp.get("devices", [])
        chosen = pick_device(devices, [h.lower() for h in TARGET_NAME_HINTS])
        if chosen:
            break
        time.sleep(1)

    if not chosen:
        sys.exit(2)

    target_id = chosen["id"]
    sp.transfer_playback(device_id=target_id, force_play=True)

if __name__ == "__main__":
    main()
