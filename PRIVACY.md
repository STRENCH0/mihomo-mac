# Privacy

MihomoMac manages a local mihomo process and its HTTP/WebSocket controller. The application source contains no analytics SDK or application-owned telemetry endpoint.

## Data kept on your Mac

- YAML profiles, including any proxy credentials or subscription URLs you put in them.
- Profile metadata and the active-profile selection.
- The selected mihomo executable path in application preferences.
- In-memory connection information, traffic history, kernel output, and logs while the app is running.
- A macOS login-item registration if you enable Launch at Login.

Profiles and metadata are plain local files under `~/Library/Application Support/MihomoMac/configs/mihomo/`. They are not encrypted or stored in Keychain by the app. Runtime logs may also appear in output captured by Xcode or macOS logging tools.

## Network requests

- The app connects to the controller configured in your active profile. That address can be local or remote; controller secrets are sent to that endpoint as bearer authentication.
- While the kernel is running, network-status probes periodically request `http://cp.cloudflare.com/generate_204`, resolve `google.com`, and make an HTTP request to the detected default gateway. These probes follow the behavior of macOS networking and your network configuration.
- Proxy delay tests use mihomo's controller and request `http://cp.cloudflare.com/generate_204` through the selected node.
- Group icons can be fetched from URLs supplied by the active configuration.
- The mihomo process can make additional requests defined by your YAML, including provider updates, DNS queries, rule downloads, and proxied traffic. Its behavior is controlled by mihomo and your configuration.

## Sharing diagnostics

Review screenshots, logs, and YAML before sharing them. Remove controller secrets, passwords, subscription tokens, private server addresses, usernames, device names, and local home-directory paths. Use invented names and example domains in reproduction data.

Public project screenshots should show only the Overview screen. Do not publish configuration, connection, log, account, or certificate screens.

## Signed binaries

A certificate-signed app contains public signing-certificate information, which can identify the developer or organization. Removing a private key from the repository does not anonymize that app's embedded signature. Review the signer before uploading any compiled app, ZIP, disk image, archive, or debug symbols.
