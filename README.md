# NetProxy Config

> 🚀 网络代理配置方案 | mihomo & sing-box

## Changelog

mihomo 内核支持到 Clash Verge Rev v2.4.2 后续版本暂不支持，节点无法获取。

sing-box 内核支持 1.12.14。

## sing-box 本地拼装配置

在 `sing-box/config_sub.json` 里维护你的基础配置模板（路由、DNS、策略组等），订阅节点仍然由 sub-store 转成 sing-box JSON，然后在本地把两者拼成最终配置。

- 生成命令（PowerShell 7+）：
  - `pwsh -NoProfile -File .\sing-box\generate-config.ps1 -SubscriptionUrl '<你的 sub-store download URL>'`
- 输出文件：默认写到 `sing-box/config.final.json`（可用 `-OutputPath` 改）
- 可选：如果你已经自己拉取了订阅内容，也可以直接传入：
  - `pwsh -NoProfile -File .\sing-box\generate-config.ps1 -SubscriptionJson (Get-Content -Raw .\sub.json)`
