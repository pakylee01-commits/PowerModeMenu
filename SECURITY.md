# Security Policy

## Supported versions

Security fixes are applied to the latest source on the default branch. The project currently distributes source only; locally built applications are ad-hoc signed and are not notarized releases.

## Reporting a vulnerability

Do not open a public issue for a vulnerability that could change privileged `pmset` arguments, weaken lock-screen settings, persist code through the LaunchAgent, alter PAM guidance, or signal unrelated processes.

Use GitHub's private vulnerability reporting feature when it is available for this repository. Include:

- the affected commit and macOS version;
- the exact privilege, process, file, or setting boundary involved;
- a minimal reproduction that does not expose credentials or damage user data;
- the expected safe behavior;
- whether exploitation requires a malicious local user, modified build, or accepted pull request.

Never include passwords, Touch ID data, API keys, private power snapshots, or account exports.

## Security guarantees and non-guarantees

- The application executes only fixed system binaries and fixed policy arguments from source.
- It does not make network requests, collect telemetry, or store credentials.
- Touch ID support depends on the user's system-wide `sudo` PAM configuration and is optional.
- `pmset disablesleep` is undocumented and may change in future macOS releases.
- The project cannot prevent thermal emergency sleep and must not be used to bypass hardware protection.
- Deleting or quitting the application does not restore prior power or lock-screen settings.

See [THREAT_MODEL.md](THREAT_MODEL.md) for the detailed trust boundaries.
