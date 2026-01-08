# NetProxy Config

> 🚀 网络代理配置方案 | mihomo & sing-box

## Changelog

- mihomo 内核支持到 Clash Verge Rev v2.4.2，后续版本暂不支持，节点无法获取。
- sing-box 内核支持 1.12.14。

## sing-box

本仓库的 `sing-box/` 目录提供一个可直接分享的 PowerShell 脚本 `singbox.ps1`，用于管理基于 WinSW（或同类 wrapper）的 Windows 服务。

### 用法

推荐在项目根目录执行（或先 `cd sing-box`）：

```powershell
.\sing-box\singbox.ps1
.\sing-box\singbox.ps1 start
.\sing-box\singbox.ps1 stop
.\sing-box\singbox.ps1 restart
.\sing-box\singbox.ps1 log
.\sing-box\singbox.ps1 log 关键字
.\sing-box\singbox.ps1 config https://example.com/config.json
```

如果你的执行策略不允许直接运行脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\sing-box\singbox.ps1 restart
```

### 目录约定

- `singbox.ps1` 默认把脚本所在目录当作服务目录（不写死盘符）。
- 同目录需要有服务 wrapper（例如 `sing-box-service.exe` 或 `WinSW-x64.exe`）。
- 日志从 `logs\*.err.log` 里找；没有就退化为 `logs\*.log`。

如需管理其他目录的服务：

```powershell
.\sing-box\singbox.ps1 restart -ServiceDir "D:\MyService\sing-box"
```

### 日常技巧

如果想在任意目录执行脚本，打开你的配置文件：

```powershell
notepad $PROFILE
```

加入这一行（注意修改为你的实际路径）：

```powershell
Set-Alias singbox "D:\你的软件目录\singbox\singbox.ps1"
```
