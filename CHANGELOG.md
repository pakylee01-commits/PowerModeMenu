# Changelog

All notable changes are documented here. The project follows source releases while Developer ID signing and notarization are unavailable.

## Unreleased

- Updated the pinned checkout Action to v5 to use the supported Node.js runtime.

## 1.2.0 - 2026-08-11

- Removed machine-specific menu-bar position forcing.
- Added an explicit warning before quitting without restoring power settings.
- Adopted public bundle and LaunchAgent identifiers.
- Added fixed-policy parsing tests, a threat model, security policy, and contribution guidance.
- Restricted GitHub Actions permissions and pinned the checkout Action by commit SHA.

## 1.1.0 - 2026-08-10

- Added optional lock-screen and sleep timing synchronization.
- Added bounded Touch ID and administrator authorization paths.
- Added fail-closed process-group cleanup and a parent-death watchdog.
- Added lifecycle regression tests and universal `arm64`/`x86_64` builds.
