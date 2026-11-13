# Changelog

## Unreleased

### Maintenance 2026-11-13

- Update Jellyfin to 12.4, qBittorrent to 5.3.0-2, Jackett to v0.24.3055-ls35,
  and Watchtower to 1.24.0.
- Refresh Sonarr and Radarr container builds to 4.0.20.3014-ls4 and
  6.4.4.10685-ls326; update stable nginx to 1.30.6-alpine and the updater
  Docker CLI base to 29.9.3-cli.
- Resolve the updater dynamically through Docker DNS so temporary updater
  outages do not prevent nginx startup or leave a stale proxy address.
- Include the boot-reconciliation systemd unit in source release archives.

### Maintenance 2026-09-19

- Upgrade Jellyfin to 12.1 with documented database migration precautions.
- Update Sonarr to 4.0.20.3014-ls325, Radarr to 6.4.4.10685-ls317, and
  Jackett to v0.24.2624-ls33.
- Update Watchtower to 1.22.2, stable nginx to 1.30.5-alpine, and the
  updater Docker CLI base to 29.8.1-cli.
- Retain qBittorrent 5.2.3-1, the current stable official image.

## 1.0.0-rc.1

Initial packaged release candidate of HomeReel, the Ubuntu home media server stack.

- Jellyfin, qBittorrent, Sonarr, Radarr, Jackett, landing page, updater, and Watchtower.
- Explicit container image versions and LAN-bound service ports.
- NVIDIA GPU override and startup health checks.
- Registry pulls skip locally built services; terminal updates build the updater.
- Maintained Watchtower fork with compatible Docker API negotiation.
- Portable launcher and configurable updater installation path.
- User manual, release guide, source archives, checksums, and CI validation.

### Limitations

- Target environment: Ubuntu 24.04, Docker Engine and Compose plugin.
- Launcher and webpage updates require the NVIDIA override. CPU-only users
  must use the manual commands documented in the user manual.
- TV audio and video compatibility depends on the client and connected equipment.
- Images are pinned by tag, not digest; registry tags can change over time.
- Project files use MIT. Third-party services keep their own licenses; their
  images and source code are not bundled.
