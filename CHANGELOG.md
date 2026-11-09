# Changelog

## Unreleased

### Added

- Tag-triggered GitHub releases with universal builds, Developer ID signing, notarization, and checksums.
- Native macOS menu-bar controls and a SwiftUI dashboard for mihomo.
- Traffic, memory, connection, log, and latency views.
- Proxy selection and individual or group latency tests.
- Local YAML profile management with a syntax-aware editor.
- Separate controls for the kernel process and macOS System Proxy.
- Launch at login with automatic kernel startup and System Proxy left off.
- Proxy environment-variable exports from the menu bar.
- Public contribution, privacy, security, and release documentation under MIT.

### Fixed

- Keep the interface responsive when system DNS is unavailable, and cancel stopped network probes.
- Include proxy-provider nodes when resolving group members.
- Keep group members visible when their details are temporarily unavailable.
- Use provider healthcheck routes when testing provider-node latency.

### Changed

- Use `com.fino-app.MihomoMac` as the application bundle identifier.
