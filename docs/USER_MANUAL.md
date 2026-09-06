# Media Server User Manual

Version: 1.0.0-rc.1

This project runs a home media server on Ubuntu using Docker Compose. It
provides streaming, library organization, download management, and a LAN
dashboard. It does not include movies, accounts, API keys, or preconfigured
application databases. Each application requires first-time setup.

## 1. Requirements

- Ubuntu 24.04 LTS; the existing deployment uses an NVIDIA GTX 1080.
- Docker Engine, Compose plugin, Buildx, Bash, curl, and iproute2 (`ss`).
- Internet access for downloading container images and application metadata.
- A stable LAN address, preferably assigned by a router DHCP reservation.
- Mounted media storage at `/mnt/data/media` and sufficient free disk space.
- For the launcher and webpage updater: NVIDIA driver and Container Toolkit.

Install Docker from the [official Ubuntu instructions](https://docs.docker.com/engine/install/ubuntu/).
For NVIDIA setup, follow [Jellyfin's NVIDIA guide](https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/nvidia/).
Docker access grants extensive control of the host; the updater and Watchtower
also use the Docker socket. Keep the services on a trusted LAN.

## 2. Install and configure

Extract the release archive into a directory owned by your user. Open a terminal
in that directory. All commands in this manual run from the project root.
Do not extract over an existing installation until you have a private backup.

```bash
cp .env.example .env
chmod 600 .env
id -u
id -g
pwd -P
```

Edit `.env` in a text editor. Use the UID and GID printed above for `PUID` and
`PGID`, and the absolute installation directory for `MEDIA_SERVER_PROJECT_DIR`.
Do not overwrite an existing `.env` during upgrades.

| Setting | What to enter |
| --- | --- |
| `MEDIA_SERVER_PROJECT_DIR` | Absolute path to this extracted project, without a trailing slash. |
| `LAN_BIND_IP` | This server's LAN address. Default `127.0.0.1` permits host-only access. |
| `JELLYFIN_PUBLISHED_URL` | `http://YOUR_SERVER_IP:8096` using the same LAN address. |
| `PUID`, `PGID` | Your Linux user and group IDs. |
| `TZ` | Your timezone, for example `Asia/Dubai`. |
| `CONFIG_ROOT` | Leave as `./config` for local persistent application state. |
| `MEDIA_ROOT` | Keep `/mnt/data/media`. Confirm the data disk is mounted first. |
| `UPDATE_TOKEN` | A long private random value to protect the update action. Blank allows tokenless updates. |
| `QBT_LEGAL_NOTICE` | Read the URL in `.env.example`, then set `confirm` if accepted. |
| `*_IMAGE` | Keep the supplied explicit image versions for the initial installation. |

Create the required directories after verifying the data disk is mounted:

```bash
findmnt /mnt/data
sudo mkdir -p /mnt/data/media/{downloads,incomplete,movies,tv}
mkdir -p config/jellyfin/{config,cache} config/{qbittorrent,sonarr,radarr,jackett}
```

Ensure the configured user can write these directories. On a new installation,
assign ownership to the UID/GID chosen above. Do not recursively change ownership
of existing shared storage without checking its current permissions.

## 3. Start the server

### NVIDIA installation

Verify `nvidia-smi` on the host, then run:

```bash
bash scripts/start-media-server.sh start
```

The launcher validates Compose, reports listeners, starts containers, and checks
the dashboard, Jellyfin, and GPU visibility. Existing port listeners are normal
if they belong to this stack. Investigate listeners owned by other applications.

In Jellyfin, choose NVIDIA NVENC under Dashboard → Playback → Transcoding.
Enable only decoding formats supported by your GPU. GPU visibility alone does
not prove hardware transcoding: test a video that requires transcoding and
inspect playback information and the FFmpeg log.

### CPU-only installation

Use the base Compose file explicitly:

```bash
docker compose --env-file .env -f docker-compose.yml config --quiet
docker compose --env-file .env -f docker-compose.yml up -d --build
```

Leave Jellyfin hardware acceleration disabled. Do not use the launcher or
webpage update button in this mode; both currently include the NVIDIA override.

## 4. Open and configure applications

Replace `SERVER_IP` with your configured LAN address.

| Application | URL | First task |
| --- | --- | --- |
| Dashboard | `http://SERVER_IP:8090` | Open the service links. |
| Jellyfin | `http://SERVER_IP:8096` | Create an administrator and libraries. |
| qBittorrent | `http://SERVER_IP:8080` | Sign in and set a permanent strong password. |
| Sonarr | `http://SERVER_IP:8989` | Configure authentication, TV root, and download client. |
| Radarr | `http://SERVER_IP:7878` | Configure authentication, movie root, and download client. |
| Jackett | `http://SERVER_IP:9117` | Set protection and configure authorized indexers. |

If qBittorrent prints an initial password, view its container logs locally and
do not share them. API keys and application databases also stay private.

Use the paths seen **inside each container**, not host paths:

| Application | Setting | Container path |
| --- | --- | --- |
| Jellyfin | Movies library | `/media/movies` |
| Jellyfin | TV library | `/media/tv` |
| qBittorrent | Completed downloads | `/downloads` |
| qBittorrent | Incomplete downloads | `/incomplete` |
| Sonarr | TV root | `/media/tv` |
| Radarr | Movie root | `/media/movies` |

Connect Sonarr/Radarr to qBittorrent using host `qbittorrent`, port `8080`, and
its credentials. Because their mount paths differ, configure a Remote Path
Mapping for that host from `/downloads/` to `/media/downloads/`. If needed,
map `/incomplete/` to `/media/incomplete/` too. Use separate `tv` and `movies`
download categories. Jackett's internal address is `http://jackett:9117`;
configure the individual indexer's Torznab URL and API key in Sonarr/Radarr.

## 5. Watch on a TV

Connect the client to `http://SERVER_IP:8096` and sign in using a regular
Jellyfin user account. Set a quality limit suitable for your LAN and display.
Keep transcoding permissions enabled so incompatible files can still play.

- Direct Play sends the original container and streams.
- Remux changes the container without re-encoding the video or audio.
- Transcoding converts incompatible streams; audio-only conversion does not
  necessarily re-encode the video.

Remux is lossless and is suitable when your goal is to avoid re-encoding.
For 7.1 audio, verify both Jellyfin's playback information and the receiver's
incoming channels. A receiver driving seven speakers does not by itself prove
that the source has seven discrete channels. Samsung app support varies by
model, codec, and firmware; eARC alone does not guarantee every codec works.

## 6. Daily operation and updates

Check status without exposing private Compose environment values:

```bash
docker compose ps
```

To update an NVIDIA installation after making a private backup:

```bash
bash scripts/start-media-server.sh update
```

For CPU-only installations:

```bash
docker compose --env-file .env -f docker-compose.yml pull --ignore-buildable
docker compose --env-file .env -f docker-compose.yml up -d --build --remove-orphans
```

These commands pull the configured tags; they do not discover newer version
numbers. Upgrade a service by deliberately changing its `*_IMAGE` tag after
reviewing the upstream release notes. Watchtower checks labeled images on its
schedule, but also does not advance explicit version tags. The web update
action excludes its own updater container; use the terminal to rebuild it.

To stop the stack while preserving bind-mounted data:

```bash
docker compose --env-file .env -f docker-compose.yml down
```

## 7. Backup, restore, and rollback

Before an upgrade, stop the stack for a consistent application-state backup.
Privately copy `.env`, the complete configured `CONFIG_ROOT`, your Compose
files, and the release version to a separate backup location. Back up media
separately. Preserve ownership and permissions. Never upload backups to GitHub.

To restore, stop the stack, preserve the current state separately, restore the
matching release files, `.env`, and application configuration, then start the
stack and verify libraries and downloads. Reverting image tags alone may fail
after an application database migration; restore the matching database backup.
Do not delete application configuration as an update or troubleshooting step.

## 8. Troubleshooting

| Symptom | Check |
| --- | --- |
| Dashboard unavailable | `docker compose ps`; inspect `docker compose logs --tail=50 landing` locally. |
| Container restarting | Read that service's logs; check bind-mount permissions and disk space. |
| TV cannot connect | LAN address, published port, network isolation, and host firewall. |
| Port already occupied | Use `ss -lntu`; compare listeners with `docker compose ps`. |
| GPU check fails | Host driver, Container Toolkit, and GPU override configuration. |
| Downloads will not import | Categories, remote path mapping, ownership, and root folders. |
| Local updater pull fails | Use the supplied script with `pull --ignore-buildable`. |
| Wrong updater project path | Set `MEDIA_SERVER_PROJECT_DIR` to the real absolute project root. |
| No surround audio | Source codec, app support, TV output settings, and AVR input format. |

Redact credentials, tokens, personal filenames, and private addresses before
sharing logs. Do not publish `.env`, `config/`, or full resolved Compose output.

## 9. Uninstall

Stop the containers with the command above. This preserves media and settings.
Keep a verified backup before manually removing the extracted software folder.
Removing that folder also removes `./config` if it is still stored inside it.

## Further reading

- [Advanced project reference](../README.md)
- [Jellyfin documentation](https://jellyfin.org/docs/)
- [Docker installation](https://docs.docker.com/engine/install/ubuntu/)
- [Release and GitHub upload guide](RELEASING.md)
