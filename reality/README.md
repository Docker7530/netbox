# Reality SNI 目标域名智能批量测速与合规筛选工具

专门为搭建 **VLESS-Reality / sing-box / s-ui / Xray** 量身打造的目标域名筛选工具。

站在批判与审查的视角，吸收开源社区优秀实践（chnnic / harenaNow / 不良林），去粗取精，打造最适合 Reality 生产环境的精炼脚本。

---

## 🌟 核心特性与架构升级

1. **三维黄金合规准入（向 chnnic 学习，但摒弃其 95KB 臃肿代码）**：
   - 传统脚本只测能否连通，往往误选只有 `http/1.1` 的伪合规站点；
   - 本脚本在握手阶段深度校验 **`TLS 1.3` + `ALPN: h2 (HTTP/2)` + `证书受信任 (Cert OK)`**，确保候选站点拟真度 100% 贴合现代主流浏览器指纹。
2. **严苛审查的黄金域名库（扩充至 167 个）**：
   - **坚决剔除高危项**：彻底排除了 `www.cloudflare.com`（Reality 大忌，CF 节点易被主动探测重点风控）及国内 `.cn` 域名；
   - **剔除假合规项**：排除了如 `azure.microsoft.com`、`download.amd.com` 等实测仅支持 `http/1.1` 的站点；
   - **吸收优质资产**：补充了全球 Anycast 金融级大厂（Visa、MasterCard、PayPal、Stripe）、顶尖跨国企业（Apple、Amazon、Sony、Tesla、Intel、AMD、Nvidia）及亚太/欧洲本地自然锚点（全日空、日本雅虎、国泰航空、新航、宝马等）。
3. **彻底根治系统计时 Bug**：
   - 原脚本使用 `date +%s%3N`，在 **Ubuntu 24.04 / 26.04**、Debian、Alpine 和 macOS 上会因 `%3N` 非标准格式输出字面字符 `3N`，导致 Bash 算术报错崩溃；
   - 本脚本内置分层高精度毫秒计时器（优先利用 Bash 5+ 原生内置的 `$EPOCHREALTIME`，次选 Python3/标准 epoch 毫秒），100% 杜绝跨系统算术 Bug。
4. **极速高并发全量扫描**：
   - 20 线程并发异步测试，全量 167 个域名在 **3~5 秒内全部测完**并生成排名。
5. **支持单域名深度体检模式（向 harenaNow 学习）**：
   - 支持通过 `--check 域名` 参数，对单个指定网站进行全方位 TLS 握手、ALPN、证书颁发机构深度体检。

---

## 🚀 一键运行命令

在你的 **VPS 终端**，直接复制并运行以下命令即可：

### 方案 A：GitHub 原生源（境外 VPS 推荐）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Docker7530/netbox/main/reality/sni.sh)
```

### 方案 B：国内镜像加速源（国内服务器 / 加速拉取推荐）

```bash
bash <(curl -fsSL https://gh-proxy.com/https://raw.githubusercontent.com/Docker7530/netbox/main/reality/sni.sh)
```

---

## 🛠️ CLI 命令行高级参数

```bash
# 查看最快的前 15 个域名
bash sni.sh -n 15

# 指定 30 线程并发测速
bash sni.sh -c 30

# 设置单次握手超时为 3 秒
bash sni.sh -t 3

# 深度体检单个自定义域名的 Reality 合规性
bash sni.sh --check www.apple.com
```

---

## 📋 在 s-ui / sing-box / Xray 面板中填写

脚本运行完毕后，会输出最快的 Top 10 榜单（如 `www.apple.com`）：

| 面板字段名称 | 推荐填写内容 | 说明 |
| :--- | :--- | :--- |
| **目标网站 / 目标地址 (Dest / Target)** | `最快域名:443`（例如 `www.apple.com:443`） | 必须带上 443 端口 |
| **服务器名称 (serverNames / SNI)** | `最快域名`（例如 `www.apple.com`） | 纯域名，不可带端口 |

> **提示**：建议在 VPS 所在地运行测速，因为离你 VPS 物理延迟最近、且带有 `h2` 标识的域名，Reality 伪装效果最逼真、最抗封锁。
