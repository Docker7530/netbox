# Reality SNI 目标域名一键批量测速工具

专门为搭建 **VLESS-Reality / sing-box / s-ui / Xray** 量身打造的目标域名筛选工具。

## ✨ 特性亮点

1. **一次性全量并发测速**：内置 107 个全球知名跨国大厂域名（苹果、微软、亚马逊、特斯拉、英特尔、索尼等），16 线程并发测试，全流程约 2~4 秒完成。
2. **强制校验 TLS 1.3**：严格过滤不支持 TLS 1.3 的域名，避免 Reality 节点搭建后握手失败。
3. **彻底修复时间计算 Bug**：
   - 传统脚本使用 `date +%s%3N`，在 **Ubuntu 24.04 / 26.04**、Debian、Alpine 以及 macOS/BSD 系统上会因不支持 `%3N` 格式化符号输出字面字符串 `3N`，导致 Bash 算术报错或时间计算为负数。
   - 本脚本内置多层高精度毫秒计时器（优先利用 Bash 5+ 原生 `$EPOCHREALTIME`，次选 Python3/标准 epoch 毫秒），100% 消除跨系统时间 Bug。
4. **自动排序输出 Top 10**：自动按真实物理握手延迟（RTT）从低到高排序，输出最快的前 10 个域名，并附带面板一键填入格式。

---

## 🚀 一键运行命令

登录到你的 **VPS 终端**，直接复制并运行以下任意一条命令即可：

### 方案 A：GitHub 原生源（境外 VPS 推荐）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Docker7530/netbox/main/reality/sni.sh)
```

### 方案 B：国内镜像加速源（国内服务器 / 加速拉取推荐）

```bash
bash <(curl -fsSL https://gh-proxy.com/https://raw.githubusercontent.com/Docker7530/netbox/main/reality/sni.sh)
```

---

## 📋 在 s-ui / sing-box / Xray 面板中填写

脚本运行完毕后，会推荐延迟最低的域名（如 `se-edge.itunes.apple.com`）：

| 面板字段名称 | 推荐填写内容 |
| :--- | :--- |
| **目标网站 / 目标地址 (Dest / Target)** | `最快域名:443`（例如 `se-edge.itunes.apple.com:443`） |
| **服务器名称 (serverNames / SNI)** | `最快域名`（例如 `se-edge.itunes.apple.com`） |

> **提示**：建议在 VPS 所在地运行测速，因为离你 VPS 物理延迟最近的域名，Reality 伪装效果最逼真、最抗封锁。
