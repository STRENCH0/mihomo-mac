# Releasing

## Prepare the source

1. Review the changes and run the relevant tests, then the complete test suite when preparing a release.
2. Check startup, profile switching, proxy-provider groups, and normal shutdown in a local build.
3. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml` as appropriate.
4. Move the relevant `Unreleased` changelog entries into the version being published and use the actual release date.
5. Regenerate the Xcode project with `xcodegen generate`.
6. Review all files selected for the release. Exclude local profiles, logs, account details, signing files, build outputs, and unredacted screenshots.

Before the first public push, check commit author and committer addresses. Use your GitHub-provided noreply address if you want to keep your personal email private. Changing Git configuration does not remove addresses already stored in existing commits.

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
