# Changelog

## 1.0.0-rc.1

Initial packaged release candidate of the Ubuntu home media server stack.

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
