# Roadmap

PowerModeMenu keeps exactly two primary modes. Roadmap items must improve safety, portability, verification, or maintainability without turning the app into a general power-profile editor.

## Completed for the first public release

- [x] Bounded Touch ID and administrator authorization.
- [x] Fail-closed authorization process-group cleanup and parent-death watchdog.
- [x] Fixed `pmset` policy arrays and exact state parsing.
- [x] Universal `arm64` and `x86_64` source build.
- [x] Strict compiler warnings, Clang static analysis, lifecycle tests, and policy tests.
- [x] Portable public bundle and LaunchAgent identifiers.
- [x] Removal of machine-specific menu-bar positioning.
- [x] Explicit warning that quitting does not restore power or lock-screen settings.
- [x] Security policy, threat model, contribution rules, templates, pinned read-only CI, secret scanning, push protection, private vulnerability reporting, and protected `main`.
- [x] Source-only `v1.2.0` release with no unnotarized binary attachment.

## Next safety work

- [ ] Design and test a local pre-change snapshot format before offering automatic restore. Do not parse and replay arbitrary shell text.
- [ ] Decide whether charger-only policies are reliable for the undocumented `disablesleep` setting across supported macOS versions; retain `pmset -a` until verified evidence supports a change.
- [ ] Add tests for partial success when `pmset` succeeds but lock-screen preference writes fail.
- [ ] Add tests for cancellation text variants and authorization teardown during application exit.
- [ ] Verify menu visibility, Touch ID success, password fallback, and thermal-warning documentation on additional macOS versions and both Apple Silicon and Intel hardware.

## Distribution and maintenance

- [ ] Add a sanitized menu screenshot and a complete English usage guide.
- [ ] Publish notarized binaries only after a maintainer-controlled Apple Developer ID signing and notarization workflow exists. Until then, remain source-only.
- [ ] Record real user reports, issues, contributors, Stars, Forks, and release downloads without inventing or combining metrics.
- [ ] Add API-assisted issue triage and PR review only after there is real maintenance volume; never execute issue or PR text as code.

## Explicit non-goals

- Automatic switching based on Wi-Fi, location, or presence.
- Arbitrary custom command execution or plugin loading.
- Kernel extensions, SIP changes, hidden privileged helpers, telemetry, or background networking.
- Additional primary power modes without evidence that the two-mode model is insufficient.
