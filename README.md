# TV Spotify Automation (Windows)

Automates controlling a **Fire TV–based smart TV** from Windows and transferring the
**currently playing Spotify session** to the TV using **Spotify Connect**.

Designed to run **fully headless** and be triggered via a **single global keyboard shortcut**.

---

## Features

### 🎛️ Smart Spotify Toggle (device-aware)

* If Spotify is **playing on the TV** → **pauses playback**
* If Spotify is **paused on the TV** → **resumes instantly** (no transfer)
* If Spotify is **playing on another device** (PC / phone) → **transfers playback to the TV**
* If the TV is **off or asleep** → wakes it up and continues automatically

No unnecessary transfers. No playback spam.

---

### ⚡ Fast & Reliable Playback Transfer

* Uses **Spotify Web API (Spotify Connect)** for playback control
* Avoids `force_play` latency issues on TVs
* Explicit `start_playback` for faster and more consistent resumes
* Minimal API calls, no busy polling

---

### 📺 Fire TV Control (ADB over TCP)

* Wake Fire TV from sleep
* Detect screen/power state
* Launch Spotify on the TV
* Works on **restricted networks** (campus Wi-Fi, no multicast / mDNS)

---

### 🧠 Robust Execution Model

* Runs **fully headless**
* **Single execution by default**
* Retries Spotify device discovery **only when needed**

  * Max **2 retries** (device not found)
* Prevents toggle loops or API spam

---

### 🔔 UX & Integration

* Native **Windows toast notifications** for errors
* Designed for **PowerToys global keyboard shortcuts**
* No terminal windows
* No hardcoded paths, IPs, or credentials

---

### 🐞 Debug Mode (Optional)

* Enable verbose logs with:

  ```bash
  run.bat --debug
  ```
* Shows timing logs, ADB steps, and Python output
* Default mode is completely silent

---

## Requirements

* Windows 10 / 11
* Spotify Premium
* Fire TV (integrated or stick)
* Python 3.x (via `py` launcher)
* Android Platform Tools (`adb`)
* Spotify Developer App credentials
* PowerShell 5.1 (Windows built-in)
* BurntToast PowerShell module (for notifications)

---

## Configuration Overview

This project cleanly separates **device configuration** from **Spotify credentials**:

* **Fire TV settings**

  * Stored in a local `env.bat` file (Windows-friendly)
* **Spotify API credentials**

  * Loaded from environment variables
  * Optional local `.env` file supported

No secrets are hardcoded or committed.

---

## Setup

### 1. Fire TV

* Enable **ADB Debugging** in Developer Options
* Ensure the Fire TV is reachable over the network
* Accept the ADB authorization prompt on first connection

---

### 2. Install dependencies

* Install **Android Platform Tools** (adb)
* Install Python dependencies:

```bash
py -m pip install spotipy python-dotenv
```

---

### 3. Spotify Developer App

* Create a Spotify app in the Spotify Developer Dashboard
* Set Redirect URI:

```text
http://127.0.0.1:8888/callback
```

---

### 4. Configure Fire TV IP (required)

Copy the example file:

```text
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

Best option for headless execution and keyboard shortcuts.

---

#### Option B — Local `.env` file (optional)

Copy:

```text
env.example → .env
```

Fill in your Spotify credentials.

The script automatically loads `.env` if present using `python-dotenv`.

> `.env` is optional and never required if environment variables are already set.

---

### 6. Keyboard shortcut (recommended)

Configure **PowerToys → Keyboard Manager → Run Program**
to trigger `run.bat` with a global shortcut.

Recommended settings:

* Run normally (not elevated)
* Visibility: **Hidden**

---

## Usage

Trigger the configured global shortcut:

### TV off or asleep

* TV is woken up automatically
* Spotify is launched on the TV
* Playback is transferred and starts playing

### TV on

* Playing on TV → **pause**
* Paused on TV → **resume**
* Playing elsewhere → **transfer to TV**

All operations run **fully headless**.
Errors are reported exclusively via **native Windows toast notifications**.

---

## Notes

* Fire TV discovery does **not** rely on multicast
* ADB is used only for power state and app launch
* Playback control is handled entirely by Spotify Connect
* If the TV is fully powered off (no network), software-only wake is not possible
* Designed as a fast, personal automation tool

---

## License

MIT

