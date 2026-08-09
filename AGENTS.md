# PowerModeMenu 项目规则

这是一个会调用 `pmset`、`caffeinate`、管理员授权、PAM 和 LaunchAgent 的 macOS 本地工具。

## 修改边界

- 构建和静态验证可以直接执行；安装、启动常驻服务、修改 `/private/etc/pam.d/` 或更改系统电源设置前必须获得明确授权。
- 不把管理员密码、Touch ID 数据或系统凭证写入项目。
- `build/` 与 `work/` 是本地产物，不进入 Git。
- `出门睡眠` 使用固定参数，不等同于恢复用户修改前的全部 `pmset` 设置；README 必须保持这一点明确。
- 菜单保持两种主模式；自动时间开关默认开启，在家为永不自动锁屏/睡眠，出门为 5 分钟锁屏、10 分钟睡眠。修改这些默认值时必须同步更新状态验证和 README。

## 最低验证

```bash
zsh -n build.sh
plutil -lint Info.plist local.gekyume.powermodemenu.plist
./build.sh
xcrun clang -fobjc-arc -framework Cocoa Tests/CommandRunnerTests.m -o work/CommandRunnerTests
work/CommandRunnerTests
```

构建验证不得自动复制应用到 `/Applications`、加载 LaunchAgent 或修改 PAM。
