# Threat Model

## Protected assets

- Integrity of system power and lock-screen settings.
- Integrity of administrator authorization and optional PAM configuration.
- Availability of unrelated local processes.
- User control over login persistence.

## Trust boundaries

PowerModeMenu is an unprivileged menu-bar application. It crosses a privilege boundary only when a user selects a mode and macOS authorizes a fixed `/usr/bin/pmset` command. Lock-screen preferences are written as the current user. A user-installed LaunchAgent starts the application at login.

The repository contains no network client, plugin loader, prompt processor, dynamic command input, updater, or third-party runtime dependency.

## Main threats

1. A contribution changes fixed mode arguments into attacker-controlled shell input.
2. Authorization fallback starts a second privileged command while the first is still alive.
3. Timeout cleanup signals a process group outside the one created for the authorization request.
4. A contribution changes the LaunchAgent into broader or hidden persistence.
5. PAM instructions overwrite unrelated rules or weaken authentication system-wide.
6. A partial switch leaves `pmset` and lock-screen settings inconsistent.
7. A CI dependency or release artifact is replaced in a supply-chain attack.

## Current controls

- Mode arguments are created from fixed arrays and covered by policy tests.
- Every authorization request runs in a new process group with bounded timeouts.
- Unsafe cleanup fails closed and disables additional privileged switches.
- The watchdog monitors only the application PID and its authorization group.
- The PAM file is an example only and is never installed by the build.
- CI has read-only repository permissions and pins third-party Actions by commit SHA.
- The build has no package-manager or third-party library dependency.

## Maintainer review rules

Changes to `sudo`, `osascript`, `pmset`, Shell, PAM, LaunchAgent, process groups, signals, or lock-screen preferences require:

- an explicit threat analysis in the pull request;
- tests that run without administrator privileges;
- confirmation that no user-controlled string reaches a shell command;
- confirmation that failure and timeout paths remain fail-closed;
- documentation updates for any changed system effect.
