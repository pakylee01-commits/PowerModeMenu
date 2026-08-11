## Summary

Describe the user-visible change and why it is needed.

## Verification

- [ ] Full unprivileged validation suite passes.
- [ ] No installation, PAM, LaunchAgent, or power-setting change was required for tests.
- [ ] Documentation matches any changed system behavior.

## Security impact

- Does this change touch `sudo`, `osascript`, `pmset`, Shell, PAM, LaunchAgent, signals, process groups, lock-screen preferences, CI, or release artifacts?
- Can any user-controlled text reach an executable or shell?
- Do timeout and failure paths remain fail-closed?
