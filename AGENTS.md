# AGENTS.md

## Project Overview

This project manages a home media server running on Ubuntu.

Services are containerized with Docker Compose.

Primary services:

- Jellyfin
- qBittorrent
- Sonarr
- Radarr
- Jackett
- Watchtower

Target environment:

- Ubuntu 24.04 LTS
- Docker Engine
- Docker Compose
- Samsung Smart TV clients
- Local network only

## Architecture

Host media directories:

/mnt/data/media
├── downloads
├── incomplete
├── movies
└── tv

Container media directories:

Jellyfin:

/media/movies
/media/tv

Sonarr and Radarr:

/media

qBittorrent:

/downloads
/incomplete

Containers must use bind mounts and never store persistent data inside containers.

## Coding Rules

- Prefer Docker Compose over manual docker commands.
- Prefer official container images.
- Use environment variables instead of hardcoded values.
- Keep compose files readable and commented.
- Do not expose services directly to the internet.
- Do not add unnecessary dependencies.
- Use explicit image tags instead of "latest".

## Security Rules

- Run containers as non-root users when possible.
- Use read-only mounts where practical.
- Do not mount the entire host filesystem.
- Do not expose qBittorrent outside the LAN.
- Never disable authentication.
- Prefer least-privilege configurations.
- Treat `.env` and `config/` as private runtime state.
- Do not print, commit, or share passwords, API keys, cookies, or app databases.

## Networking

- Services communicate through Docker networks.
- Jellyfin port: 8096
- qBittorrent WebUI port: 8080
- Sonarr port: 8989
- Radarr port: 7878
- Jackett port: 9117
- Internal container communication preferred.

## Storage Rules

Movies:

/mnt/data/media/movies

TV:

/mnt/data/media/tv

Downloads:

/mnt/data/media/downloads

Incomplete:

/mnt/data/media/incomplete

Never change these paths unless explicitly requested.

## When Making Changes

Before modifying files:

1. Explain the proposed change.
2. Show the affected files.
3. Generate complete code.
4. Validate Docker Compose syntax.
5. Check for port conflicts.

## Preferred Output

When creating Docker Compose files:

- Use compose version compatible with Docker Compose v2.
- Include comments.
- Include health checks.
- Include restart policies.
- Include example .env values.

## Documentation

Whenever infrastructure changes:

- Update README.md
- Update docker-compose.yml examples
- Document required environment variables
