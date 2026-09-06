# HomeReel

![HomeReel logo](landing/assets/homereel-logo.png)

Your media. At home.

HomeReel is a Docker Compose stack for a local Ubuntu home media server.

Release candidate: **1.0.0-rc.1**. Start with the [User Manual](docs/USER_MANUAL.md)
for installation and daily use. See the [Release Guide](docs/RELEASING.md) to
package the project and upload it to GitHub, and the [Changelog](CHANGELOG.md)
for version history. This is a Docker Compose distribution, not a standalone
desktop installer. Container images are downloaded separately.

## Services

| Service | Purpose | Default URL |
| --- | --- | --- |
| Landing page | Links to all service WebUIs | `http://LAN_BIND_IP:8090` |
| Jellyfin | Media streaming | `http://LAN_BIND_IP:8096` |
| qBittorrent | Download client WebUI | `http://LAN_BIND_IP:8080` |
| Sonarr | TV automation | `http://LAN_BIND_IP:8989` |
| Radarr | Movie automation | `http://LAN_BIND_IP:7878` |
| Jackett | Torrent indexer proxy | `http://LAN_BIND_IP:9117` |
| Watchtower | Labeled container image updates | No WebUI |
| Updater | Fixed update endpoint with optional token authentication | Internal only |

## Storage Layout

The stack stores media under the Data hard drive mounted at `/mnt/data`:

```text
/mnt/data/media
├── downloads
├── incomplete
├── movies
└── tv
```

Persistent application configuration is stored in `./config` by default:

```text
./config
├── jellyfin
├── jackett
├── qbittorrent
├── radarr
└── sonarr
```

`./config` contains service databases, API keys, passwords, logs, sessions, and
indexer settings. Keep it local and back it up privately. Do not commit or
share it.

Containers use bind mounts. Persistent data is not stored inside containers.

Inside the containers, Sonarr and Radarr still see the media root as `/media`;
qBittorrent sees completed downloads at `/downloads` and incomplete downloads
at `/incomplete`.

## Required Environment

Copy the example environment file and edit it:

```bash
cp .env.example .env
```

Set these values before starting:

| Variable | Description |
| --- | --- |
| `MEDIA_SERVER_PROJECT_DIR` | Absolute installation directory for the updater's matching host/container mount. Blank uses `PWD`; run Compose from the project root. The launcher exports its own project path. |
| `LAN_BIND_IP` | Server LAN IP to bind published ports. Use the address your Samsung TV can reach. |
| `PUID` / `PGID` | User and group IDs that own `./config` and `MEDIA_ROOT`. |
| `TZ` | Container timezone. |
| `CONFIG_ROOT` | Host path for service configuration bind mounts. |
| `MEDIA_ROOT` | Host path for media files on the Data hard drive. |
| `LANDING_PORT` | Landing page port. Default is `8090`. |
| `UPDATE_TOKEN` | Optional private token for landing page updates. Leave blank to run updates from the page without a token. |
| `JELLYFIN_PUBLISHED_URL` | Jellyfin URL advertised to LAN clients. |
| `JELLYFIN_NVIDIA_VISIBLE_DEVICES` | NVIDIA GPU IDs exposed to Jellyfin. Use `all` on a single-GPU server. |
| `JELLYFIN_NVIDIA_DRIVER_CAPABILITIES` | NVIDIA driver capabilities exposed to Jellyfin. Use `compute,video,utility` for NVENC/NVDEC. |
| `JELLYFIN_NVIDIA_GPU_COUNT` | Number of NVIDIA GPUs Docker should reserve for Jellyfin. Use `all` on a single-GPU server. |
| `QBT_LEGAL_NOTICE` | Set to `confirm` only after reading the qBittorrent legal notice. |
| `JACKETT_PORT` | Jackett WebUI port. Default is `9117`. |

The compose file uses explicit image tags through environment variables. Avoid changing them to `latest`.

## Project Hygiene

The project files you normally edit are:

| File | Purpose |
| --- | --- |
| `docker-compose.yml` | Defines the media server containers, ports, volumes, and health checks. |
| `docker-compose.gpu.yml` | Optional NVIDIA GPU reservation override for Jellyfin transcoding. |
| `landing/index.html` | Static LAN landing page with links to service WebUIs and the update action. |
| `landing/nginx.conf` | Landing page nginx config, including the internal update API proxy. |
| `updater/Dockerfile` and `updater/update_server.py` | Fixed endpoint with optional token authentication used by the landing page to run stack updates. |
| `scripts/start-media-server.sh` | Starts or updates the GPU-enabled stack, then checks the landing page, Jellyfin, and GPU access. |
| `.env.example` | Safe template for local environment values. |
| `README.md` | Operator guide for setup, use, updates, and troubleshooting. |
| `AGENTS.md` | Notes for future automated edits to this project. |

These local runtime files are intentionally ignored by `.gitignore` and
`.dockerignore`:

| Path | Why it stays local |
| --- | --- |
| `.env` | Contains the real LAN IP, local paths, ports, and update settings. |
| `config/` | Contains app databases, API keys, passwords, logs, and sessions. |
| `jellyfin-web/`, `jellyfin-tizen/` | Local upstream checkouts and Samsung client builds; maintained separately from the server stack. |
| `node_modules/`, `__pycache__/`, `*.wgt`, `*.p12`, `*.pfx` | Generated dependencies, bytecode, TV packages, and private signing credentials. |
| `media/`, `downloads/`, `movies/`, `tv/`, `incomplete/` | May contain downloaded or personal media if created inside the project. |

Before moving this stack to another server, privately back up `.env` and
`config/`. Do not delete `config/` while the services are running unless you
want to reset the applications.

## Host Setup

Install Docker Engine and Docker Compose v2 on Ubuntu, then create the required directories on the Data drive:

```bash
sudo mkdir -p /mnt/data/media/downloads /mnt/data/media/incomplete /mnt/data/media/movies /mnt/data/media/tv
mkdir -p config/jellyfin/config config/jellyfin/cache config/qbittorrent config/sonarr config/radarr config/jackett
```

Make the directories writable by the configured `PUID` and `PGID`:

```bash
sudo chown -R 1000:1000 /mnt/data/media
sudo chown -R 1000:1000 config
```

Replace `1000:1000` if your `.env` uses different IDs.

## Jellyfin GPU Transcoding

The existing installation uses NVIDIA NVENC/NVDEC hardware acceleration.
New installations must configure it in the Jellyfin dashboard; private app
settings are not included in the release. The base Compose file works without
a GPU. The launcher and web updater currently use `docker-compose.gpu.yml`
and require a configured NVIDIA GPU; use manual base-Compose commands for CPU-only operation.

Check the host driver:

```bash
nvidia-smi
```

Install the NVIDIA Container Toolkit using NVIDIA's current installation guide:

```bash
sudo apt-get update && sudo apt-get install -y --no-install-recommends ca-certificates curl gnupg2
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
```

Then configure Docker and restart it:

```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

Check that Docker can create NVIDIA GPU containers:

```bash
sudo docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi
```

If Docker reports that it cannot select the `nvidia` device driver, repair the
NVIDIA Container Toolkit configuration and restart Docker.

The default `.env` values expose all NVIDIA GPUs to Jellyfin:

```text
JELLYFIN_NVIDIA_VISIBLE_DEVICES=all
JELLYFIN_NVIDIA_DRIVER_CAPABILITIES=compute,video,utility
JELLYFIN_NVIDIA_GPU_COUNT=all
```

Start Jellyfin without GPU access:

```bash
sudo docker compose --env-file .env up -d jellyfin
```

Start Jellyfin with GPU access:

```bash
sudo docker compose --env-file .env -f docker-compose.yml -f docker-compose.gpu.yml up -d jellyfin
```

Verify that Jellyfin can see the GPU:

```bash
sudo docker compose --env-file .env -f docker-compose.yml -f docker-compose.gpu.yml exec jellyfin nvidia-smi
```

In Jellyfin, hardware acceleration is set to NVIDIA NVENC in
`config/jellyfin/config/config/encoding.xml`. During a 4K transcode, `nvidia-smi`
should show an `ffmpeg` process using the GPU.

If `nvidia-smi` shows the GPU but says `No running processes found`, that is
normal while Jellyfin is idle. Start playback that requires transcoding, then
check again.

## Validate

Check the rendered Compose configuration:

```bash
docker compose --env-file .env config
```

Check the GPU-enabled configuration used on this server:

```bash
docker compose --env-file .env -f docker-compose.yml -f docker-compose.gpu.yml config
```

Check host port conflicts before starting:

```bash
ss -ltnp
```

The default published ports are `8090`, `8096`, `8080`, `6881`, `8989`,
`7878`, and `9117`.

## Start The System

Run all commands from the project directory:

```bash
cd /home/mrobot/projects/media-server
```

If this is the first start on a new machine, create and edit `.env` first:

```bash
cp .env.example .env
nano .env
```

Confirm these important `.env` values:

```text
LAN_BIND_IP=192.168.2.10
MEDIA_ROOT=/mnt/data/media
LANDING_PORT=8090
JELLYFIN_PUBLISHED_URL=http://192.168.2.10:8096
QBT_LEGAL_NOTICE=confirm
UPDATE_TOKEN=
```

Validate the GPU-enabled Compose file before starting:

```bash
docker compose --env-file .env -f docker-compose.yml -f docker-compose.gpu.yml config
```

Start all services with Jellyfin GPU access:

```bash
docker compose --env-file .env -f docker-compose.yml -f docker-compose.gpu.yml up -d
```

If Docker says permission denied, run the same command with `sudo`:

```bash
sudo docker compose --env-file .env -f docker-compose.yml -f docker-compose.gpu.yml up -d
```

Check service status:

```bash
docker compose --env-file .env -f docker-compose.yml -f docker-compose.gpu.yml ps
```

### Desktop Shortcut

The existing host has a desktop shortcut at the path below. Release packages
do not install desktop shortcuts automatically:

```text
~/Desktop/Start Media Server.desktop
```

It runs:

```text
scripts/start-media-server.sh
```

The shortcut starts the GPU-enabled stack, checks the landing page and Jellyfin
health, verifies that the Jellyfin container can see the NVIDIA GPU, and opens
the landing page in a browser. It opens in a terminal so Ubuntu can ask for the
sudo password if Docker requires it.

If the desktop asks whether to trust or allow launching the shortcut, choose
`Allow Launching`.

Check Jellyfin directly:

```bash
curl http://192.168.2.10:8096/health
```

The expected result is:

```text
Healthy
```

Open the landing page:

```text
http://192.168.2.10:8090
```

The landing page includes an `Update stack` action. It calls the internal
updater service through the landing page nginx proxy. The updater endpoint can
only run the fixed Compose update flow; it does not accept arbitrary shell
commands from the browser. If `UPDATE_TOKEN` is blank, the page does not ask for
a token. The updater auto-discovers Compose services and updates every service
except the internal updater service that is running the update.

Open the services from a browser on the same network:

| Service | URL |
| --- | --- |
| Landing page | `http://192.168.2.10:8090` |
| Jellyfin | `http://192.168.2.10:8096` |
| qBittorrent | `http://192.168.2.10:8080` |
| Sonarr | `http://192.168.2.10:8989` |
| Radarr | `http://192.168.2.10:7878` |
| Jackett | `http://192.168.2.10:9117` |

On the TV, open the Jellyfin app and use:

```text
http://192.168.2.10:8096
```

### Install Jellyfin On An Older Samsung TV

First try the official TV app. Jellyfin publishes an official Samsung Tizen
client, and Samsung Smart TVs install TV apps from the TV's Apps or Smart Hub
store.

1. Connect the Samsung TV to the same LAN or Wi-Fi network as this server.
2. Open `Apps` or `Smart Hub` on the TV.
3. Search for `Jellyfin`.
4. Install and open the Jellyfin app if it appears for the TV model and region.
5. Enter the server address:

```text
http://192.168.2.10:8096
```

If the app is not available in the TV store but the TV runs Tizen, sideload the
official Jellyfin Tizen client from a computer on the same network. This is for
older Tizen TVs where the store listing is missing or unavailable.

Prerequisites on the computer:

- Tizen Studio 4.6 or newer with the TV SDK and Certificate Manager.
- Git.
- Node.js 20 or newer.
- A Samsung/Tizen certificate profile that is allowed to install on the TV.

The `tizen` and `sdb` commands must come from Tizen Studio. Do not install
Ubuntu's `sdb` package with `apt`; that package is Mono's soft debugger and
cannot connect to Samsung TVs.

After installing Tizen Studio, add its command line tools to the shell:

```bash
export TIZEN_STUDIO_HOME="$HOME/tizen-studio"
export PATH="$TIZEN_STUDIO_HOME/tools/ide/bin:$TIZEN_STUDIO_HOME/tools:$PATH"
hash -r
```

Check that the correct tools are being used:

```bash
command -v tizen
command -v sdb
tizen version
sdb devices
```

The expected paths should start with `~/tizen-studio/`, not `/usr/bin/sdb`.

Build the widget:

```bash
git clone -b release-10.11.z https://github.com/jellyfin/jellyfin-web.git
git clone https://github.com/jellyfin/jellyfin-tizen.git

cd jellyfin-web
npm ci --no-audit
USE_SYSTEM_FONTS=1 npm run build:production

cd ../jellyfin-tizen
JELLYFIN_WEB_DIR=../jellyfin-web/dist npm ci --no-audit
tizen build-web -e ".*" -e gulpfile.babel.js -e README.md -e "node_modules/*" -e "package*.json" -e "yarn.lock"
tizen package -t wgt -o . -- .buildResult
```

Enable Developer Mode on the TV:

1. Open `Smart Hub` -> `Apps`.
2. Open `App Settings`.
3. Enter `12345` with the remote or on-screen keypad.
4. Turn `Developer mode` on.
5. Enter the IP address of the computer running Tizen Studio.
6. Reboot the TV.

Install the widget:

```bash
sdb connect TV_IP_ADDRESS
sdb devices
tizen install -n Jellyfin.wgt -t TV_TARGET_NAME
```

Use the target name shown by `sdb devices`. If Tizen Studio uses a Samsung
certificate, allow the TV to install apps from that certificate before running
`tizen install`.

If the Samsung TV is too old to run Tizen apps, use a LAN-only fallback instead
of changing this server's security model:

- Open `http://192.168.2.10:8096` in the TV browser if the browser can play it.
- Use an external Android TV, Fire TV, Roku, Apple TV, or Chromecast device with
  a supported Jellyfin client.
- Keep Jellyfin bound to the LAN IP and do not expose it through the router.

References:

- Jellyfin clients: `https://jellyfin.org/downloads/clients/`
- Jellyfin Tizen source and build steps: `https://github.com/jellyfin/jellyfin-tizen`
- Samsung TV Developer Mode: `https://developer.samsung.com/smarttv/develop/getting-started/using-sdk/tv-device.html`

For qBittorrent 4.6.1 and newer, the initial WebUI password is generated at
first start. Read it from logs:

```bash
docker logs qbittorrent
```

Change the qBittorrent password immediately in the WebUI. Do not disable
authentication.

To restart the system after changing `.env` or `docker-compose.yml`:

```bash
docker compose --env-file .env -f docker-compose.yml -f docker-compose.gpu.yml up -d
```

To update the project with the image tags currently configured in `.env`:

```bash
scripts/start-media-server.sh update
```

You can also open the landing page and click `Update stack`.

The terminal update command validates the GPU-enabled Compose configuration,
checks the configured host ports, pulls registry images while skipping locally
built services, builds local images, recreates containers with `--remove-orphans`,
prints container status, checks the landing
page and Jellyfin health, and verifies Jellyfin GPU visibility. The webpage
update action auto-discovers Compose services, pulls all pullable service
images, recreates the stack services except the internal updater service, and
reports status back to the page. Change the image tag variables in `.env` first
when you want to move a service to a newer pinned version.

To stop the system:

```bash
docker compose --env-file .env -f docker-compose.yml -f docker-compose.gpu.yml down
```

Stopping the system does not delete media or app configuration. The media stays
under `MEDIA_ROOT`, and app configuration stays under `CONFIG_ROOT`.

## Daily Use: From Download To TV

Use this stack only with movies and shows you own, created yourself, or have
permission to download and stream.

Use the `LAN_BIND_IP` value from `.env` when opening services from another
device on the same network. For example, if `LAN_BIND_IP=192.168.2.10`,
the landing page is available at:

```text
http://192.168.2.10:8090
```

### 1. Add Movies And Shows

Jellyfin reads finished media from the library folders, not from the download
folder.

Movies must end up under:

```text
/mnt/data/media/movies
```

Recommended movie layout:

```text
/mnt/data/media/movies/Movie Name (Year)/Movie Name (Year).mkv
```

TV shows must end up under:

```text
/mnt/data/media/tv
```

Recommended TV layout:

```text
/mnt/data/media/tv/Show Name/Season 01/Show Name - S01E01 - Episode Name.mkv
```

Completed downloads from qBittorrent are stored on the host at:

```text
/mnt/data/media/downloads
```

Files left in `downloads` will not appear in Jellyfin until they are moved or
imported into `movies` or `tv`.

### 2. Manual Movie Flow

Use this when you already have a finished movie file.

1. Copy or move the movie into `/mnt/data/media/movies`.
2. Use the movie folder layout shown above.
3. Open Jellyfin at `http://LAN_BIND_IP:8096`.
4. Go to `Dashboard` -> `Libraries` -> `Scan All Libraries`.
5. Open Jellyfin on the TV and play the movie from `Movies`.

Example:

```text
/mnt/data/media/movies/The Example Movie (2026)/The Example Movie (2026).mkv
```

### 3. Download With qBittorrent

Use qBittorrent only for legal downloads.

1. Open the qBittorrent WebUI at `http://LAN_BIND_IP:8080`.
2. Log in and add the legal torrent or download.
3. Let it finish downloading.
4. The completed file appears on the host in `/mnt/data/media/downloads`.
5. Move movies to `/mnt/data/media/movies`.
6. Move TV episodes to `/mnt/data/media/tv`.
7. Scan Jellyfin libraries.

For movies, Radarr can do the move/import step automatically. For TV shows,
Sonarr can do the move/import step automatically.

Radarr and Sonarr connect to qBittorrent through the qBittorrent WebUI/API.
There is no special qBittorrent-side connection toggle to enable. Keep WebUI
authentication enabled, keep the WebUI port at `8080`, and use the same
qBittorrent username and password inside Radarr or Sonarr.

To minimize seeding and upload:

1. Open qBittorrent at `http://LAN_BIND_IP:8080`.
2. Go to `Tools` -> `Options` -> `Speed`.
3. Set the global upload limit to `1 KiB/s`. Do not use `0`; in qBittorrent,
   `0` usually means unlimited.
4. Go to `Tools` -> `Options` -> `BitTorrent` -> `Seeding Limits`.
5. Enable stopping torrents when the share ratio or seeding time limit is reached.
6. Set share ratio to `0` or the lowest value the UI accepts.
7. Set seeding time to `0` minutes or the lowest value the UI accepts.
8. Set the action after reaching the limit to `Stop torrent`.
9. If you use the `radarr` category, edit that category and use the same ratio,
   seeding-time, and `Stop torrent` settings for the category.

BitTorrent may still upload tiny amounts while a file is downloading. These
settings are meant to stop completed torrents from seeding and keep upload
traffic as low as qBittorrent allows.

### 4. Set Up Jackett Indexers

Jackett lets Radarr and Sonarr search legal torrent indexers through the
Torznab API.

Open Jackett at:

```text
http://LAN_BIND_IP:9117
```

For the current example address, use:

```text
http://192.168.2.10:9117
```

Basic Jackett flow:

1. Open Jackett.
2. In Jackett settings, set an admin password before adding indexers.
3. Add a legal indexer/provider.
4. Test the indexer in Jackett.
5. Copy the Jackett API key from the top of the Jackett WebUI.
6. For the added indexer, click `Copy Torznab Feed`.
7. In Radarr, go to `Settings` -> `Indexers` -> `+` -> `Torznab` -> `Custom`.
8. Paste the copied Torznab feed URL into `URL`.
9. Paste the Jackett API key into `API Key`.
10. Enable RSS sync, automatic search, and interactive search.
11. Click `Test`, then `Save`.

When Radarr runs in Docker, use the internal Jackett hostname if you type the
URL manually:

```text
http://jackett:9117/api/v2.0/indexers/INDEXER_NAME/results/torznab/
```

The browser URL `http://LAN_BIND_IP:9117` is for humans on the LAN. The Docker
URL `http://jackett:9117` is for Radarr and Sonarr talking to Jackett inside
the Compose network.

Do not use `localhost:9117` or `127.0.0.1:9117` in Radarr or Sonarr. Inside
those containers, localhost points back to the same container, not to Jackett.
If Jackett copies a Torznab feed URL with `localhost`, replace only the host
part with `jackett` before testing it in Radarr.

Jackett does not download files. It only gives Radarr and Sonarr search/RSS
results. qBittorrent still performs the download.

If Jackett warns that external access is enabled without an admin password,
set an admin password in the Jackett WebUI. Docker needs Jackett reachable
inside the Compose network, so do not rely on no-password access.

### 5. Automatic Movie Imports With Radarr

Radarr manages movies and imports completed downloads into Jellyfin's movie
library.

Open Radarr at:

```text
http://LAN_BIND_IP:7878
```

Use these paths in Radarr:

| Setting | Value |
| --- | --- |
| Movie root folder | `/media/movies` |
| Download client host | `qbittorrent` |
| Download client port | `8080` |
| Completed downloads path, if needed | `/media/downloads` |

Configure the qBittorrent download client in Radarr under `Settings` ->
`Download Clients` -> `+` -> `qBittorrent`:

| Field | Value |
| --- | --- |
| Host | `qbittorrent` |
| Port | `8080` |
| Use SSL | Off |
| URL Base | Blank |
| Username | qBittorrent WebUI username |
| Password | qBittorrent WebUI password |
| Category | `radarr` |

Do not use `localhost` or `127.0.0.1` for the host. Inside the Radarr
container, those addresses point back to Radarr itself. Use the Docker service
name `qbittorrent`.

Basic Radarr flow:

1. Open Radarr.
2. Configure qBittorrent as a download client with host `qbittorrent` and port `8080`.
3. Set the movie root folder to `/media/movies`.
4. Add at least one legal indexer through Jackett under `Settings` -> `Indexers`.
5. Enable RSS sync, automatic search, and interactive search on the Jackett/Torznab indexer.
6. Add and monitor a movie in Radarr.
7. When the download completes, Radarr imports it into `/media/movies`.
8. Jellyfin scans the movie library and shows it on the TV.

If Radarr shows `No indexers available with RSS sync enabled`, add an indexer
or enable RSS sync on an existing indexer. Radarr will not grab new releases
automatically until at least one enabled indexer has RSS sync turned on.

If Radarr sees completed downloads but cannot import them, add a remote path
mapping:

| Field | Value |
| --- | --- |
| Host | `qbittorrent` |
| Remote Path | `/downloads/` |
| Local Path | `/media/downloads/` |

This mapping is required because qBittorrent reports completed files from its
container path, `/downloads`, while Radarr sees the same host directory at
`/media/downloads`.

Do not select `/media/downloads` as a Radarr movie root folder. The Radarr movie
root folder should stay `/media/movies`; the download folder is only a temporary
handoff area.

### 6. Automatic TV Imports With Sonarr

Sonarr manages TV shows and imports completed episodes into Jellyfin's TV
library.

Open Sonarr at:

```text
http://LAN_BIND_IP:8989
```

Use these paths in Sonarr:

| Setting | Value |
| --- | --- |
| Series root folder | `/media/tv` |
| Download client host | `qbittorrent` |
| Download client port | `8080` |
| Completed downloads path, if needed | `/media/downloads` |

If Sonarr cannot import completed downloads, use the same remote path mapping:

| Field | Value |
| --- | --- |
| Host | `qbittorrent` |
| Remote Path | `/downloads/` |
| Local Path | `/media/downloads/` |

### 7. Watch On The TV

1. Connect the TV to the same LAN or Wi-Fi network as the server.
2. Install or open the Jellyfin app on the TV.
3. Enter the Jellyfin server address: `http://LAN_BIND_IP:8096`.
4. Log in.
5. Open `Movies` or `TV Shows`.
6. Press play.

For the current example address, use:

```text
http://192.168.2.10:8096
```

Use the TV browser only if a Jellyfin app is not available. A Jellyfin app on a
Samsung TV, Android TV, Fire TV, Apple TV, or Chromecast usually gives a better
playback experience than the browser.

### 8. Original Quality Playback

To stream with original quality, the TV should Direct Play the file.

1. In the Jellyfin TV app, set playback quality to `Original`, `Maximum`, or the
   highest available bitrate.
2. Prefer Ethernet or strong 5 GHz Wi-Fi for large 4K files.
3. Use TV-compatible files such as H.264 or H.265/HEVC in MP4 or MKV.
4. Prefer SRT subtitles when possible.
5. On Samsung TVs, prefer HDR10 files over Dolby Vision-only files.

During playback, open playback information in Jellyfin. If it says `Direct
Play`, the file is streaming in original quality. If it says `Transcoding`,
Jellyfin is changing the file because the TV, network, subtitles, audio, or
video format needs conversion.

### 9. Troubleshooting

If the TV cannot open Jellyfin:

1. Confirm the TV and server are on the same network.
2. Use `http://`, not `https://`, unless HTTPS has been configured separately.
3. Confirm `LAN_BIND_IP` in `.env` matches the server LAN address.
4. Confirm Jellyfin is reachable from another device at `http://LAN_BIND_IP:8096`.

If a movie does not appear in Jellyfin:

1. Confirm the file is under `/mnt/data/media/movies`, not only in `downloads`.
2. Confirm the folder and file names are clean and include the year.
3. Confirm the Jellyfin Movies library path is `/media/movies`.
4. Run `Dashboard` -> `Libraries` -> `Scan All Libraries`.
5. Confirm the file permissions allow the configured `PUID` and `PGID` to read it.

If Jellyfin uses 100% CPU for a long time:

1. Confirm no Jellyfin library points at `/`, `/media`, `/config`, or `/cache`.
2. Use only `/media/movies` for movies and `/media/tv` for TV.
3. Keep realtime monitoring disabled for large libraries on this bind mount.
4. Check `config/jellyfin/config/root/default/Movies/options.xml` if CPU spikes return; `EnableRealtimeMonitor` and `EnableLUFSScan` should stay `false`.

If Jellyfin starts but does not use the GPU:

1. Start it with `docker-compose.gpu.yml`, not only the base compose file.
2. Verify GPU access with `sudo docker compose --env-file .env -f docker-compose.yml -f docker-compose.gpu.yml exec jellyfin nvidia-smi`.
3. Confirm `config/jellyfin/config/config/encoding.xml` has hardware acceleration set to `nvenc`.
4. Start playback that requires transcoding; direct-play streams do not start an `ffmpeg` GPU process.

If qBittorrent shows `Unauthorized` after opening it from the landing page:

1. Refresh the landing page at `http://LAN_BIND_IP:8090`.
2. Open qBittorrent from the refreshed page.
3. If the old browser tab still shows `Unauthorized`, close it and open `http://LAN_BIND_IP:8080` again.

The landing page uses no-referrer links so qBittorrent's origin checks accept
the WebUI request without disabling qBittorrent authentication.

If Radarr or Sonarr downloads but does not import:

1. Check that qBittorrent is configured as the download client.
2. Check that the root folder is `/media/movies` for Radarr or `/media/tv` for Sonarr.
3. Add the remote path mapping from `/downloads/` to `/media/downloads/`.

If Radarr says qBittorrent places downloads in `/downloads` but that directory
does not exist inside the Radarr container:

1. Add or verify this remote path mapping in `Settings` -> `Download Clients` -> `Remote Path Mappings`.
2. Set `Host` to `qbittorrent`.
3. Set `Remote Path` to `/downloads/`.
4. Set `Local Path` to `/media/downloads/`.
5. Confirm the Radarr root folder is `/media/movies`, not `/media/downloads`.

If Radarr cannot connect to qBittorrent:

1. Confirm qBittorrent opens at `http://LAN_BIND_IP:8080`.
2. In Radarr, set the qBittorrent host to `qbittorrent`, not `localhost`.
3. Use port `8080`, SSL off, and blank URL base.
4. Use the qBittorrent WebUI username and password.
5. Use category `radarr` so Radarr can track the downloads it sends.

If Radarr shows no RSS indexers:

1. Add a legal indexer in Jackett.
2. Copy the indexer's Torznab feed URL and the Jackett API key into Radarr.
3. Replace `localhost:9117` in the copied URL with `jackett:9117` if needed.
4. Enable RSS sync on that Radarr indexer.
5. Enable automatic search and interactive search if Radarr should search it.
6. Run `System` -> `Tasks` -> `RSS Sync` after saving.

## Service Paths

Use these paths when configuring applications:

| App | Path |
| --- | --- |
| Jellyfin movies library | `/media/movies` |
| Jellyfin TV library | `/media/tv` |
| qBittorrent completed downloads | `/downloads` |
| qBittorrent incomplete downloads | `/incomplete` |
| Sonarr root folder | `/media/tv` |
| Radarr root folder | `/media/movies` |
| Sonarr/Radarr download path | `/media/downloads` |

Sonarr and Radarr mount `/media` as one tree so imports can use atomic moves and hardlinks when the underlying filesystem supports them.

## Networking

Published WebUI ports bind to `LAN_BIND_IP`. Do not set `LAN_BIND_IP` to a public interface, and do not publish these services through the router.

Containers communicate over the `media-server` Docker bridge network. Use `qbittorrent:8080` when configuring Sonarr or Radarr to talk to qBittorrent internally. Use `jackett:9117` when configuring Radarr or Sonarr to talk to Jackett internally.

## Watchtower

The stack uses the maintained `nickfedor/watchtower` fork with an explicit image
tag. Rolling-restart mode is intentionally disabled because the landing page
depends on the updater service. Watchtower is configured with
`WATCHTOWER_LABEL_ENABLE=true`, so it only watches containers with this label:

```yaml
com.centurylinklabs.watchtower.enable: "true"
```

The Watchtower container itself is labeled `false`. Because this project uses explicit image tags, updates are controlled by changing the image tag variables in `.env` and then running:

```bash
scripts/start-media-server.sh update
```

The landing page also provides an update action. Set `UPDATE_TOKEN` in `.env`
to require authentication; a blank value permits updates without a token.
The webpage excludes the updater service itself; use the terminal update
command when rebuilding that service.
