# PowerModeMenu

[![Build](https://github.com/pakylee01-commits/PowerModeMenu/actions/workflows/build.yml/badge.svg)](https://github.com/pakylee01-commits/PowerModeMenu/actions/workflows/build.yml)

一个只有两档的 macOS 菜单栏电源开关。适合让 MacBook 在家接电时合盖继续跑 Codex、下载、编译或其他长任务，出门时再恢复正常合盖睡眠。可选的自动时间设置会让锁屏与睡眠时长跟随模式一起切换。

> **English:** PowerModeMenu is a dependency-free macOS menu-bar utility for switching between closed-display long-running work and normal lid sleep. It uses fixed `pmset` policies, bounded authorization, fail-closed process cleanup, and no network access or telemetry.

## 两种模式

| 模式 | 自动时间开启时写入的 `pmset -a` 参数 | 锁屏与额外行为 |
| --- | --- | --- |
| 在家常开 | `disablesleep 1 sleep 0 disksleep 0 displaysleep 0 lowpowermode 0` | 自动锁屏设为永不；启动绑定 App PID 的 `caffeinate -dimsu` |
| 出门睡眠 | `disablesleep 0 sleep 10 disksleep 10 displaysleep 5 lowpowermode 0` | 闲置 5 分钟启动屏保并立即要求密码；停止 App 管理的 `caffeinate` |

“切换时同步锁屏与睡眠时间”默认开启，可在菜单中关闭。关闭后，模式切换只写入 `disablesleep` 与 `lowpowermode`，不会修改现有的系统睡眠、显示器睡眠、磁盘睡眠或屏保锁定时间。应用会根据开关状态验证相应字段；只匹配部分参数时显示“状态未知”，不会误报为某个模式。

## 重要风险

- 合盖运行会降低散热能力。不要把仍在运行的 MacBook 放进包、被褥、沙发或其他不通风环境。
- `pmset disablesleep` 没有出现在公开的 `pmset` 手册中，未来 macOS 版本可能改变或移除它。
- 两种模式都使用 `pmset -a`，会同时修改电池和电源适配器配置。
- 自动时间设置使用当前用户的 `com.apple.screensaver` 偏好；出门模式会开启屏保后立即要求密码，但不会削弱用户已有的手动锁屏保护。
- “出门睡眠”写入固定值，不会自动恢复安装前的全部设置。首次使用前务必保存快照。
- 退出应用会停止它管理的 `caffeinate`，但不会自动恢复已经写入的 `pmset` 或锁屏设置。退出前会显示确认提示；若当前为“在家常开”，应先切换到“出门睡眠”。
- 本仓库目前只提供源码构建。产物是本机临时签名，没有 Developer ID 签名或 Apple 公证，不应把本地构建包冒充正式发行版分发。

## 系统要求

- macOS 13 或更高版本
- Xcode Command Line Tools
- 管理员权限用于切换 `pmset`

构建脚本生成包含 `arm64` 与 `x86_64` 的 universal App。

## 使用前保存电源快照

```bash
mkdir -p "$HOME/.local/state/PowerModeMenu"
pmset -g custom > "$HOME/.local/state/PowerModeMenu/pmset-custom-before-install.txt"
pmset -g > "$HOME/.local/state/PowerModeMenu/pmset-before-install.txt"
defaults -currentHost read com.apple.screensaver > "$HOME/.local/state/PowerModeMenu/screensaver-current-host-before-install.txt" 2>/dev/null || true
defaults read com.apple.screensaver > "$HOME/.local/state/PowerModeMenu/screensaver-before-install.txt" 2>/dev/null || true
```

这些文件用于人工回滚。不要公开上传，其中可能包含本机电源配置细节。

## 构建

```bash
git clone https://github.com/pakylee01-commits/PowerModeMenu.git
cd PowerModeMenu
./build.sh
```

产物位于 `build/PowerModeMenu.app`。构建脚本不会安装 App、加载 LaunchAgent、修改 PAM 或切换电源模式。

## 安装

先完成上面的快照和构建，然后执行：

```bash
sudo ditto --rsrc --extattr build/PowerModeMenu.app /Applications/PowerModeMenu.app
mkdir -p "$HOME/Library/LaunchAgents"
cp io.github.pakylee01-commits.powermodemenu.plist "$HOME/Library/LaunchAgents/"
launchctl bootout "gui/$(id -u)/io.github.pakylee01-commits.powermodemenu" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/io.github.pakylee01-commits.powermodemenu.plist"
```

从 1.1 或更早的本地版本升级时，先卸载旧标识，避免两个 LaunchAgent 同时启动：

```bash
launchctl bootout "gui/$(id -u)/local.gekyume.powermodemenu" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/local.gekyume.powermodemenu.plist"
```

LaunchAgent 会在登录时启动应用，并在异常退出时重启；通过菜单中的“退出电源模式菜单”正常退出后，本次登录期间不会立即重启。

## Touch ID 授权（可选）

默认会在 Touch ID 路径不可用时回退到 macOS 管理员密码。`config/sudo_local.example` 只是参考片段，**不要直接覆盖** `/private/etc/pam.d/sudo_local`。

启用前请注意：

- `pam_tid.so` 会影响本机所有 `sudo` 命令，不只影响 PowerModeMenu。
- 先备份已有 `sudo_local`；若文件已经包含其他规则，只追加所需行。
- Touch ID 在远程会话、合盖状态或部分系统环境中可能不可用。
- 不熟悉 PAM 时，保留默认密码授权更安全。

参考行：

```text
auth       sufficient     pam_tid.so
```

Touch ID 最长等待 30 秒；明确失败且旧授权进程组已经结束时，应用会回退到可见的管理员授权窗口。超时不会自动启动第二次授权，需要用户重试；管理员窗口最长等待 120 秒。成功、取消、失败或超时后，菜单都会恢复可点击。授权等待期间选择退出时，应用也会先停止整个独立授权进程组，再正常退出。

每个授权进程组还带有一个只监视 App PID 的本地看门器。即使 App 崩溃或被强制结束，看门器也会终止该授权进程组；若系统报告进程组无法安全结束，模式按钮会保持禁用，避免并发启动第二次特权修改。

## 验证

静态与构建检查：

```bash
zsh -n build.sh
plutil -lint Info.plist io.github.pakylee01-commits.powermodemenu.plist
./build.sh
xcrun clang --analyze -fobjc-arc -Wall -Wextra Source/PowerModeMenu.m -o /dev/null
xcrun clang -fobjc-arc -framework Cocoa Tests/CommandRunnerTests.m -o work/CommandRunnerTests
work/CommandRunnerTests
xcrun clang -fobjc-arc -framework Cocoa Tests/PolicyTests.m -o work/PolicyTests
work/PolicyTests
lipo -archs build/PowerModeMenu.app/Contents/MacOS/PowerModeMenu
codesign --verify --deep --strict build/PowerModeMenu.app
```

安装后的只读检查：

```bash
launchctl print "gui/$(id -u)/io.github.pakylee01-commits.powermodemenu"
pmset -g
pmset -g assertions
```

## 卸载与回滚

先卸载 LaunchAgent，再删除文件：

```bash
launchctl bootout "gui/$(id -u)/io.github.pakylee01-commits.powermodemenu" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/io.github.pakylee01-commits.powermodemenu.plist"
sudo rm -rf /Applications/PowerModeMenu.app
```

然后参照使用前保存的 `pmset-custom-before-install.txt`，用管理员权限逐项恢复原值。删除 App 本身不会自动恢复电源设置。

如果使用过自动时间设置，还应在“系统设置 > 锁定屏幕”中恢复原来的显示器关闭和密码要求，或参照安装前保存的两个 `screensaver` 快照恢复。项目不会猜测安装前的锁屏值，也不会自动回写快照。

如果手动修改过 `/private/etc/pam.d/sudo_local`，只撤销你添加的 `pam_tid.so` 行，或从安装前备份恢复；不要删除或覆盖不属于本项目的 PAM 规则。

## 项目结构

- `Source/PowerModeMenu.m`：AppKit 菜单栏应用
- `build.sh`：本地 universal 构建与临时签名
- `io.github.pakylee01-commits.powermodemenu.plist`：用户级 LaunchAgent
- `config/sudo_local.example`：可选 Touch ID PAM 参考片段
- `.github/workflows/build.yml`：GitHub Actions 构建验证
- `Tests/CommandRunnerTests.m`：无特权的授权超时与后台子进程清理回归测试
- `Tests/PolicyTests.m`：固定 `pmset` 参数白名单与状态解析测试
- `SECURITY.md` / `THREAT_MODEL.md`：漏洞报告方式与权限边界

## 设计边界

- 手动两档切换，不自动根据 Wi-Fi、位置或是否接电切换。
- 锁屏与睡眠时间目前采用两组固定值；不提供任意分钟数编辑器。
- 不保存、迁移或恢复用户原有 `pmset` 配置。
- 不修改 SIP，不安装内核扩展，不使用第三方依赖。
- 不保证所有未来 macOS 版本继续支持合盖常开。

## 参与贡献

提交 issue 或 PR 前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)、[SECURITY.md](SECURITY.md) 和 [THREAT_MODEL.md](THREAT_MODEL.md)。涉及 `sudo`、`pmset`、PAM、LaunchAgent、Shell 或进程组信号的变更必须同时提供安全影响说明和无特权回归测试。

## License

[MIT](LICENSE)
