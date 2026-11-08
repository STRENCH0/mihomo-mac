# Contributing

Bug reports, focused fixes, and documentation improvements are welcome. Check existing issues before opening a new one.

## Development setup

Use macOS 14 or later, full Xcode 16 or later, and XcodeGen. Swift Package Manager resolves Yams and CodeEditSourceEditor from `project.yml`.

```sh
xcodegen generate
open MihomoMac.xcodeproj
```

Regenerate the project after changing `project.yml`, adding source files, or adding test files. The Xcode project is generated and must not be committed.

Use Xcode to review any required package plug-in approval on a fresh machine. Do not work around plug-in validation by disabling it globally.

## Structure

| Directory | Purpose |
| --- | --- |
| `MihomoMac/App` | App lifecycle, shared state, and window management |
| `MihomoMac/Models` | Value types and API response models |
| `MihomoMac/Services` | Kernel process, controller API, WebSockets, and system integration |
| `MihomoMac/Features` | Dashboard, connections, logs, proxies, profiles, and settings |
| `MihomoMac/Views` | Shared views and AppKit menu-bar integration |
| `MihomoMacTests` | XCTest and Swift Testing tests |

`AppState` coordinates the services and exposes state to views through the environment. Keep network and process operations out of view rendering.

## Code conventions

- Use four spaces, descriptive English names, and the style of the surrounding code.
- Use structs for value types and views, and final classes for stateful services.
- Keep observable services on the main actor and use async/await for asynchronous work.
- Handle failures explicitly where they affect user-visible state.
- Prefer small, direct changes over broad refactoring.
- Keep code self-explanatory and avoid adding comments that repeat it.
- Keep documentation, user-facing strings, and commit messages in English.

## Tests

Run the test suite from Xcode with **Product → Test**, or use:

```sh
xcodebuild test \
  -project MihomoMac.xcodeproj \
  -scheme MihomoMac \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData
```

To run a focused suite:

```sh
xcodebuild test \
  -scheme MihomoMac \
  -destination 'platform=macOS' \
  -only-testing:MihomoMacTests/SystemProxyTests
```

Prefer Swift Testing for new test suites. Cover meaningful behavior and failure cases using synthetic configuration and API data. Tests must not depend on personal proxy subscriptions, a running private server, or real credentials.

For UI changes, check the relevant screen in Xcode or a local build. For startup changes, verify manual launch and login-item launch separately. Test System Proxy changes on a machine where modifying network settings is appropriate.

## Pull requests

Explain the problem and resulting behavior, list the checks you actually ran, and call out unverified behavior. For screenshots, use the Overview screen with public or redacted data. Do not include real connection lists, logs, configuration secrets, or system account details.

Do not commit generated projects, build products, local preferences, signing identities, certificates, provisioning profiles, or private keys. The project's MIT license applies to accepted contributions; third-party material must retain its required notices.
