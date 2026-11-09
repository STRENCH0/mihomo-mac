# Releasing

## Prepare the source

1. Review the changes and run the relevant tests, then the complete test suite when preparing a release.
2. Check startup, profile switching, proxy-provider groups, and normal shutdown in a local build.
3. Choose the next version. Automated releases take the app version from the tag and the build number from the workflow run number. Update `project.yml` when changing the default local build version.
4. Move the relevant `Unreleased` changelog entries into the version being published and use the actual release date.
5. Regenerate the Xcode project with `xcodegen generate`.
6. Review all files selected for the release. Exclude local profiles, logs, account details, signing files, build outputs, and unredacted screenshots.

Before the first public push, check commit author and committer addresses. Use your GitHub-provided noreply address if you want to keep your personal email private. Changing Git configuration does not remove addresses already stored in existing commits.

## Automated GitHub releases

The `Release` workflow runs when a tag such as `0.1.1` or `v0.1.1` is pushed. Versions must contain three numeric components without leading zeroes or a prerelease suffix. It tests the app on a standard GitHub-hosted macOS runner, builds a universal Release for Apple Silicon and Intel, includes dependency licenses, signs with Developer ID Application, and notarizes with Apple before publishing a GitHub Release. The assets are `MihomoMac-<version>-universal.zip` and its `.sha256` checksum.

The workflow uses the built-in `GITHUB_TOKEN` to publish releases. No personal GitHub token is required. Checkout and artifact actions are pinned to commit hashes; update those pins when upgrading the actions.

The app includes available dependency license and notice files fetched from GitHub at the resolved revisions, plus a dependency manifest. When a package has no separate license file, its README is included as source attribution; this does not replace reviewing notices for bundled binary resources.

### Signing configuration

Create these repository settings under **Settings → Secrets and variables → Actions**:

| Kind | Name | Value |
| --- | --- | --- |
| Secret | `MACOS_CERTIFICATE_P12_BASE64` | Base64-encoded `.p12` containing one Developer ID Application certificate and its private key |
| Secret | `MACOS_CERTIFICATE_PASSWORD` | Password protecting the `.p12` |
| Variable | `APPLE_TEAM_ID` | Apple Developer team ID |

Use a locally managed Developer ID Application identity. Cloud-managed certificates cannot be exported with their private keys. The workflow imports the identity into a temporary keychain and removes the keychain after the job, including when a build fails.

Configure one of these notarization methods as repository secrets:

| Method | Required secrets |
| --- | --- |
| App Store Connect team API key | `APPLE_API_KEY_P8` (the complete `.p8` contents), `APPLE_API_KEY_ID`, `APPLE_API_ISSUER_ID` |
| Apple Account | `APPLE_ID`, `APPLE_APP_PASSWORD` (an app-specific password) |

The workflow prefers the API key when all three API secrets are present. Tag releases require notarization credentials and fail without them. Store certificate material and passwords only in Actions Secrets.

### Verify without publishing

Under **Actions → Release → Run workflow**, enter a version and run the workflow on `main`. Manual runs upload a ZIP and checksum as a workflow artifact and never create a GitHub Release. Leave notarization enabled for a complete distribution check. Disable it only to test certificate import and signed builds while configuring Apple credentials; that artifact is signed but not notarized.

```sh
gh workflow run release.yml --ref main -f version=0.1.1 -f notarize=true
```

### Publish a version

After updating the changelog, committing, and pushing the source:

```sh
git tag -a 0.1.1 -m "Release 0.1.1"
git push origin 0.1.1
```

The workflow publishes only after tests, signature verification, notarization, ticket stapling, and Gatekeeper assessment succeed. Its release notes state the minimum macOS version, architectures, and signing status, followed by GitHub-generated change notes. Download the ZIP and verify its checksum before distributing it further. The mihomo kernel remains a separate installation.

## Build locally

```sh
xcodegen generate
xcodebuild build \
  -project MihomoMac.xcodeproj \
  -scheme MihomoMac \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGN_STYLE=Manual
```

This command requests local ad-hoc signing and does not select a personal signing certificate. Check the produced architectures and signature before sharing a binary. An ad-hoc signature is not Developer ID signing or Apple notarization and does not provide the same Gatekeeper distribution experience.

For certificate-signed distribution, follow Apple's [macOS distribution-signing documentation](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac). Pass your signing identity and team locally, or select them in an untracked generated project. Never store their values in `project.yml` or a committed build script.

Certificate signatures expose the public identity of the signer. Do not publish a personally signed development build when the release must keep that identity private. Use an appropriate organizational identity or publish source only.

## Verify and package

For the application built in `build/DerivedData`:

```sh
codesign --verify --deep --strict --verbose=2 \
  build/DerivedData/Build/Products/Release/MihomoMac.app
codesign --display --verbose=4 \
  build/DerivedData/Build/Products/Release/MihomoMac.app
lipo -archs \
  build/DerivedData/Build/Products/Release/MihomoMac.app/Contents/MacOS/MihomoMac
```

Resolve verification failures before describing a release as verified. Include all notices required by the resolved dependencies and bundled resources; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Keep generated archives, ZIPs, certificates, provisioning profiles, and debug symbols out of Git. Debug symbols and compiled strings can reveal local paths even when source files are clean.

## Publish

- Use a version tag that matches the app version and changelog.
- Attach only the artifacts you have reviewed and verified.
- State the minimum macOS version, supported architectures, and signing/notarization status accurately.
- Use only an Overview screenshot with private information removed.
- Verify that a clean checkout can generate and build the project.

Publishing a repository, tag, or release is a separate action from preparing the local files.
