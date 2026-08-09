# PowerModeMenu 项目规则

这是一个会调用 `pmset`、`caffeinate`、管理员授权、PAM 和 LaunchAgent 的 macOS 本地工具。

## 修改边界

- 构建和静态验证可以直接执行；安装、启动常驻服务、修改 `/private/etc/pam.d/` 或更改系统电源设置前必须获得明确授权。
- 不把管理员密码、Touch ID 数据或系统凭证写入项目。
- `build/` 与 `work/` 是本地产物，不进入 Git。
- `出门睡眠` 使用固定参数，不等同于恢复用户修改前的全部 `pmset` 设置；README 必须保持这一点明确。

## 最低验证

```bash
zsh -n build.sh
plutil -lint Info.plist local.gekyume.powermodemenu.plist
./build.sh
```

构建验证不得自动复制应用到 `/Applications`、加载 LaunchAgent 或修改 PAM。
