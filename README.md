# 电源模式菜单

macOS 菜单栏两档电源开关：

- **在家常开**：关闭系统、磁盘和显示器睡眠，启动 `caffeinate`，允许合盖继续运行，并关闭低功耗模式。
- **出门睡眠**：应用一组固定的睡眠参数，包括恢复合盖睡眠、系统睡眠 1 分钟、显示器和磁盘睡眠 10 分钟。

`出门睡眠` 不是“恢复修改前的全部设置”。安装或首次使用前，应保存当前 `pmset` 配置作为人工回滚依据。

切换电源策略优先使用 Touch ID 授权；不可用时回退到 macOS 管理员密码。应用可由用户级 LaunchAgent 常驻托管。

## 构建

```bash
./build.sh
```

构建产物位于 `build/PowerModeMenu.app`。构建脚本只生成并临时签名 App，不安装、不加载 LaunchAgent，也不修改系统设置。

## 安装涉及的系统位置

项目本身不自动执行以下操作：

- App：`/Applications/PowerModeMenu.app`
- LaunchAgent：`~/Library/LaunchAgents/local.gekyume.powermodemenu.plist`
- Touch ID sudo 配置：`/private/etc/pam.d/sudo_local`

Touch ID 配置模板位于 `config/sudo_local.example`。修改 PAM 前必须备份现有文件，并单独确认。

## 验证

```bash
zsh -n build.sh
plutil -lint Info.plist local.gekyume.powermodemenu.plist
./build.sh
```

构建后检查：

```bash
codesign --verify --deep --strict build/PowerModeMenu.app
```

这些命令不会切换电源模式。

## 卸载与回滚原则

卸载时应按顺序处理：

1. 退出菜单栏 App；
2. 卸载用户 LaunchAgent；
3. 删除 `/Applications/PowerModeMenu.app`；
4. 根据安装前保存的 `pmset` 快照恢复电源参数；
5. 只有在确认不再需要 Touch ID sudo 时，才处理 `sudo_local`。

删除 App 本身不会自动恢复之前的电源设置。
