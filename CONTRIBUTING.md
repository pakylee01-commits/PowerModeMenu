# Contributing

PowerModeMenu intentionally has only two primary modes. Please open an issue before proposing new modes, automatic location/Wi-Fi switching, a privileged helper, networking, telemetry, or third-party dependencies.

## Development setup

Requirements: macOS 13 or later and Xcode Command Line Tools.

Run the complete unprivileged validation suite:

```bash
zsh -n build.sh
plutil -lint Info.plist io.github.pakylee01-commits.powermodemenu.plist
./build.sh
xcrun clang --analyze -fobjc-arc -Wall -Wextra Source/PowerModeMenu.m -o /dev/null
xcrun clang -fobjc-arc -framework Cocoa Tests/CommandRunnerTests.m -o work/CommandRunnerTests
work/CommandRunnerTests
xcrun clang -fobjc-arc -framework Cocoa Tests/PolicyTests.m -o work/PolicyTests
work/PolicyTests
codesign --verify --deep --strict build/PowerModeMenu.app
```

These checks must not install the app, load a LaunchAgent, modify PAM, or change system power settings.

## Pull requests

- Keep changes focused and preserve the two-mode design.
- Do not add dynamic shell commands or execute issue/PR text.
- Update tests and README whenever fixed power or lock-screen values change.
- Describe security impact for authorization, process, PAM, LaunchAgent, or CI changes.
- Never commit power snapshots, credentials, build artifacts, or local state.

Security-sensitive reports should follow [SECURITY.md](SECURITY.md), not a public issue.
