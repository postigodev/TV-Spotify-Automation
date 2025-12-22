# TV Spotify Automation (Windows)

Automates controlling a Fire TV–based smart TV from Windows and transferring the
**currently playing Spotify session** to the TV using **Spotify Connect**.

Designed to run **fully headless** and be triggered via a **single global keyboard shortcut**.

---

## Features

- **Smart power toggle**
  - If the TV is **off / asleep** → wakes it up and continues
  - If the TV is **already on** → turns it off and exits
- Wake Fire TV via **ADB over TCP**
- Launch Spotify on the TV
- Transfer current playback using **Spotify Web API (Spotify Connect)**
- Automatic retries until the TV appears in Spotify Connect
- One-key shortcut integration with **PowerToys**
- Runs fully hidden (no terminal windows)
- **Error notifications via native Windows toasts**
- Works on restricted networks (e.g. campus Wi-Fi, no multicast)
- No hardcoded paths, IPs, or credentials

---

## Requirements

- Windows 10 / 11
- Spotify Premium
- Fire TV (integrated or stick)
- Python 3.x (via `py` launcher)
- Android Platform Tools (`adb`)
- Spotify Developer App credentials
- PowerShell 5.1 (Windows built-in)
- BurntToast PowerShell module (for native Windows notifications)

---

## Configuration Overview

This project cleanly separates **device configuration** from **Spotify credentials**:

- **Fire TV settings**
  - Handled via a local `env.bat` file (Windows-friendly)
- **Spotify API credentials**
  - Loaded from environment variables
  - Supports both **system-wide env vars** and an optional local `.env` file

No secrets are hardcoded or committed.

---

## Setup

### 1. Fire TV

- Enable **ADB Debugging** in Developer Options
- Ensure the Fire TV is reachable over the network
- Accept the ADB authorization prompt on first connection

---

### 2. Install dependencies

- Install **Android Platform Tools** (adb)
- Install Python dependencies:

```bash
py -m pip install spotipy python-dotenv
````

---

### 3. Spotify Developer App

* Create a Spotify app in the Spotify Developer Dashboard
* Set Redirect URI:

```
http://127.0.0.1:8888/callback
```

---

### 4. Configure Fire TV IP (required)

Copy the example file:

```bash
env.example.bat → env.bat
```

Edit `env.bat` and set:

```bat
set FIRETV_IP=YOUR_FIRE_TV_IP
```

This file is **not committed** and is Windows-specific by design.

---

### 5. Configure Spotify credentials (choose ONE)

#### Option A — System environment variables (recommended)

Set the following variables in your OS:

* `SPOTIPY_CLIENT_ID`
* `SPOTIPY_CLIENT_SECRET`
* `SPOTIPY_REDIRECT_URI`

This is the most robust option for headless execution and keyboard shortcuts.

---

#### Option B — Local `.env` file (optional)

Copy:

```bash
env.example → .env
```

Fill in your Spotify credentials.

The script automatically loads `.env` if present using `python-dotenv`.

> `.env` is optional and never required if environment variables are already set.

---

### 6. Keyboard shortcut (optional but recommended)

Configure **PowerToys → Keyboard Manager → Run Program**
to trigger `run.bat` with a global shortcut.

Recommended settings:

* Run normally (not elevated)
* Visibility: **Hidden**

---

## Usage

Trigger the configured global shortcut:

### When the TV is off or asleep
- The TV is woken up automatically
- Spotify is launched on the TV
- The current Spotify session is transferred to the TV

### Smart Spotify Connect toggle
- If Spotify is **playing on the TV** → playback is **paused**
- If Spotify is **playing on another device** (PC / phone) → playback is **transferred to the TV and continues playing**
- If playback is **paused or inactive** → playback is **transferred to the TV and starts automatically**

All operations run **fully headless**.
Errors and status updates are reported exclusively via **native Windows toast notifications**.

---

## Notes

* Fire TV discovery does not rely on multicast; works on restricted networks
* ADB is used only for power state and app launch
* Playback control is handled entirely by Spotify Connect
* If the TV is fully powered off (no network), software-only wake is not possible
* Designed for portability and long-running personal automation

---

## License

MIT
