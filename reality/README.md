# Reality SNI 测速与筛选工具

专为 **VLESS-Reality / sing-box / s-ui / Xray** 打造的目标域名（Dest / serverNames）批量测速与合规筛选工具。

在服务器端并发测试目标站点的物理握手延迟，筛选出距离 VPS 最近、且满足 Reality 伪装要求的优质域名。

---

## 功能特性

- **严格协议合规**：检测并验证 `TLS 1.3`、`ALPN: h2 (HTTP/2)` 及公共 CA 证书有效性，确保伪装流量符合现代主流浏览器特征。
- **精选域名池**：内置 180 个高可用大厂域名，涵盖全球 Anycast CDN、科技大厂、跨国金融及美/欧/亚太本土权威机构，已排除不适宜作为伪装的高危站点。
- **高精度测速**：采用传输层连接时钟直接测量纯 TLS 握手耗时（RTT），避免因服务端 Keep-Alive 机制引入虚假延迟。
- **极速并发**：多线程异步测速，数秒内完成全量测试并按延迟由低到高自动排序输出。
- **跨平台支持**：兼容 Ubuntu（含 20.04/22.04/24.04/26.04）、Debian、CentOS、AlmaLinux、Alpine 及 macOS。
- **单域名诊断**：提供独立检测参数，支持对指定自定义域名进行深度握手与证书体检。

---

## 快速开始

在 **VPS 终端** 执行以下命令即可运行：

### GitHub 原生源

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Docker7530/netbox/main/reality/sni.sh)
```

### 镜像加速源

```bash
bash <(curl -fsSL https://gh-proxy.com/https://raw.githubusercontent.com/Docker7530/netbox/main/reality/sni.sh)
```

---

## 命令行参数

下载脚本后可使用自定义参数运行：

```bash
# 查看最快的前 15 个域名（默认 10 个）
bash sni.sh -n 15

# 指定并发测试线程数（默认 20 线程）
bash sni.sh -c 30

# 设置单次握手超时时间（默认 2 秒）
bash sni.sh -t 3

# 深度体检单个自定义域名
bash sni.sh --check www.apple.com

# 查看帮助信息
bash sni.sh -h
```

---

## 面板配置参考

测速完成后，选择榜单中延迟最低的域名填入管理面板（以 `s-ui` / `Xray` 为例）：

| 配置项 | 推荐填写内容 | 格式说明 |
| :--- | :--- | :--- |
| **目标网站 / 目标地址 (Dest / Target)** | `最快域名:443`（例如 `www.apple.com:443`） | 需包含 443 端口 |
| **服务器名称 (serverNames / SNI)** | `最快域名`（例如 `www.apple.com`） | 纯域名，不包含端口 |

> **选型建议**：优先选择物理延迟最低（通常为 5ms ~ 40ms）且标有 `h2` 的域名。目标服务器离 VPS 物理距离越近，反向代理特征时延越小，伪装效果越稳定。
