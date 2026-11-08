# Security

## Reporting vulnerabilities

Use GitHub's **Security → Report a vulnerability** feature when private vulnerability reporting is available for this repository. If it is unavailable, ask the maintainer for a private reporting channel without posting exploit details or credentials publicly.

Include the affected version, a minimal reproduction using synthetic data, expected behavior, and the impact. Do not attach unredacted profiles, subscription URLs, controller secrets, private keys, or personal traffic logs.

## Operational considerations

- Use `127.0.0.1` for the controller when it is only needed locally. A listener on `0.0.0.0` can expose the controller to other devices.
- Protect controller access with a unique secret and avoid unencrypted remote controller connections.
- Download the mihomo executable from a source you trust. MihomoMac runs the selected executable with your user privileges.
- Profiles can contain plaintext credentials and are stored as ordinary files. Restrict access to the directory and keep backups private.
- System Proxy changes macOS network-service settings. Quitting normally disables it, but forced termination or a crash may require manually reviewing those settings.
- Review package build plug-ins before enabling them in Xcode.

The project does not currently publish a security-support lifetime or a security-response deadline.
