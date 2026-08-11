# Codex for Open Source application draft

Official program: <https://developers.openai.com/community/codex-for-oss>

Official form: <https://openai.com/form/codex-for-oss/>

This file is a maintainer draft, not proof that an application has been submitted or accepted. Recheck all public repository metrics immediately before submission.

## Repository facts to verify at submission time

- GitHub username: `pakylee01-commits`
- Repository: `https://github.com/pakylee01-commits/PowerModeMenu`
- Role: Primary maintainer
- Default branch: `main`
- Application-preparation branch: `codex-for-oss-application`
- Initial public snapshot on 2026-08-11: 0 stars, 0 forks, 1 contributor, 0 issues
- Default-branch CI: `macos` passed on run `31473405590` after the public roadmap was added
- Application-branch CI: `macos` passed on run `31473106460`
- Latest release: source-only `v1.2.0`, published 2026-08-11
- Security controls: Secret Scanning, Push Protection, private vulnerability reporting, and protected `main`

These are time-specific facts. Recheck Stars, Forks, Contributors, Issues, CI, and the latest release immediately before submission instead of copying this snapshot as current forever.

Do not submit private power snapshots, credentials, private contact data, or unverifiable download numbers.

## Describe your role

English, 374 characters:

> I am the creator and primary maintainer. I designed the two-mode workflow and implemented the AppKit app, privileged authorization path, watchdog and process-group cleanup, LaunchAgent integration, tests, CI, and documentation. I am responsible for issue triage, pull-request review, releases, security fixes, and long-term compatibility with macOS power-management changes.

Chinese reference:

> 我是项目创建者和主要维护者。我设计了两档工作流，并实现了 AppKit 应用、特权授权链、看门器与进程组清理、LaunchAgent、测试、CI 和文档。我负责 issue 分类、PR 审查、发布、安全修复，以及对 macOS 电源管理变化的长期兼容。

## Why does this repository qualify?

English, 411 characters:

> PowerModeMenu is a dependency-free macOS menu-bar utility for safely switching between closed-display long-task operation and normal lid sleep. It combines visible power controls with bounded Touch ID/admin authorization and fail-closed process cleanup. It serves MacBook users running compiles, downloads, and local agents. It is newly open sourced, so I am not claiming adoption metrics that do not yet exist.

Chinese reference:

> PowerModeMenu 是一个无运行时依赖的 macOS 菜单栏工具，用于在合盖长任务运行和正常合盖睡眠之间安全切换。它将可见的电源控制、有限时的 Touch ID/管理员授权和 fail-closed 进程清理结合起来，面向运行编译、下载和本地 Agent 的 MacBook 用户。项目刚刚开源，因此不会声称尚不存在的采用指标。

## Why does the project need Codex Security?

English, 447 characters:

> PowerModeMenu launches privileged pmset changes through sudo/osascript, ships a PAM example and LaunchAgent, and uses a shell watchdog to terminate authorization process groups. A malicious PR could alter fixed arguments, abuse fallback logic, weaken lock settings, persist code at login, or kill unrelated processes. Codex Security could trace these privilege paths, flag command injection or unsafe signal scope, and review supply-chain changes.

Chinese reference:

> PowerModeMenu 通过 sudo/osascript 执行特权 pmset 修改，提供 PAM 示例和 LaunchAgent，并使用 Shell 看门器终止授权进程组。恶意 PR 可能篡改固定参数、滥用授权回退、削弱锁屏、植入登录持久化，或终止无关进程。Codex Security 可追踪这些权限路径，发现命令注入、错误信号范围和供应链变更。

## How will API credits be used?

English, 429 characters:

> I will use API credits for maintainer automation: classify issues by macOS version and power-state evidence; summarize crash and authorization-timeout reports; draft reproduction checklists; review PRs against fixed command allowlists and safety invariants; generate release notes from merged changes; and propose tests for pmset parsing, timeout cleanup, and LaunchAgent behavior. No user content will be executed automatically.

Chinese reference:

> API 额度将用于维护自动化：按照 macOS 版本和电源状态证据分类 issue；总结崩溃和授权超时报告；生成复现清单；根据固定命令白名单和安全不变量审查 PR；从合并记录生成发布说明；为 pmset 解析、超时清理和 LaunchAgent 行为提出测试。不会自动执行用户内容。

## Anything else?

English, 369 characters:

> I use the project for real long-running work on macOS. It has no runtime dependencies, telemetry, network requests, or credential collection. Universal arm64/x86_64 builds are checked in CI for scripts, plists, lifecycle tests, architecture, and signing. Releases are currently source-only and ad-hoc signed; I will not claim download numbers until they are verifiable.

Chinese reference:

> 我实际使用该项目运行 macOS 长任务。项目没有运行时依赖、遥测、网络请求或凭证收集。CI 会检查 universal arm64/x86_64 构建、脚本、plist、生命周期测试、架构和签名。目前仅发布源码并使用临时签名；在下载数据可验证前，不会声称下载量。

## Submission gate

- [ ] GitHub profile is public.
- [ ] Repository is public and controlled by the applicant.
- [ ] Default-branch CI is green.
- [ ] Public metrics above were refreshed immediately before submission.
- [ ] The ChatGPT account email is correct.
- [ ] The OpenAI Organization ID was copied from the applicant's own API Platform account.
- [ ] Codex Security and API credits are selected only if still desired.
- [ ] The maintainer has personally reviewed the final form and Program Terms.
- [ ] The maintainer, not automation, performs the final form submission.
