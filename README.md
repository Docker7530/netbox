# NetProxy Config

## 目录结构

```
netbox/
├── sing-box/
│   ├── sing-box.exe               # sing-box 主程序
│   ├── Manage-SingBox.ps1         # 服务管理脚本
│   ├── sing-box-service.exe       # WinSW 服务 wrapper
│   ├── sing-box-service.xml       # WinSW 服务配置
│   ├── rule_set/                  # sing-box 规则集
│   ├── config/                    # 配置模板与合并工具
│   ├── config.json                # 运行时配置（gitignored）
│   ├── ui/                        # Web UI 面板（gitignored）
│   ├── cache.db                   # 缓存数据库（gitignored）
│   └── logs/                      # 服务日志（gitignored）
├── mihomo/
│   ├── config/tun-config.yaml     # mihomo TUN 模式配置
│   └── rule_set/work.yaml         # mihomo 规则集
└── shadowrocket/
    └── lazy_group.conf            # Shadowrocket 懒人分组配置
```

## sing-box 服务管理

`Manage-SingBox.ps1` 用于管理基于 WinSW 的 sing-box Windows 服务，支持服务控制、日志查看、订阅配置更新和内核自动更新。

### 快速开始

```powershell
.\sing-box\Manage-SingBox.ps1               # 查看状态
.\sing-box\Manage-SingBox.ps1 install       # 安装服务
.\sing-box\Manage-SingBox.ps1 uninstall     # 卸载服务
.\sing-box\Manage-SingBox.ps1 stop          # 停止
.\sing-box\Manage-SingBox.ps1 restart       # 重启
.\sing-box\Manage-SingBox.ps1 log           # 查看日志
.\sing-box\Manage-SingBox.ps1 log 关键字     # 搜索日志
.\sing-box\Manage-SingBox.ps1 config <url>  # 拉取订阅并合并配置
.\sing-box\Manage-SingBox.ps1 update        # 更新至最新版
.\sing-box\Manage-SingBox.ps1 update 1.13.8 # 更新/回退至指定版本
```

> **执行策略受限？**
>
> - 临时绕过（仅本次生效）：`powershell -ExecutionPolicy Bypass -File .\sing-box\Manage-SingBox.ps1 restart`
> - 永久解决（推荐）：`Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`

### 脚本约定

- 默认以脚本所在目录为服务目录（不写死盘符）
- 同目录需包含 `sing-box-service.exe`
- 日志优先读 `logs\*.err.log`，不存在则退化为 `logs\*.log`

### 全局别名

在 PowerShell 配置中添加别名，即可在任意目录使用：

```powershell
notepad $PROFILE
# 添加（修改为实际路径）：
Set-Alias singbox "D:\你的软件目录\sing-box\Manage-SingBox.ps1"
```
