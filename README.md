# NetBox

个人网络代理配置、自动化分流体系与节点优选工具箱。

---

## 目录结构

```text
netbox/
├── reality/                       # Reality 协议工具集
│   ├── sni.sh                     # 目标域名 (SNI) 智能并发测速与合规筛选脚本
│   └── README.md                  # Reality 工具使用说明与一键命令
└── sing-box/                      # sing-box 核心配置与规则体系
    ├── config/
    │   ├── config_sub.json        # 生产级 sing-box 订阅配置模板 (现代化 DNS、三明治分流、自建节点支持)
    │   └── auto-group.js          # Sub-Store 节点自动归类、倍率过滤与自建装载脚本
    ├── qichiyuhub/                # 七尺雨多平台配置参考归档 (Windows / Linux / iOS 等)
    └── rule_set/                  # 本地规则集定义与备份
```

---

## 模块说明

### 1. Reality 工具 (`reality/`)
- **`sni.sh`**：内置 180 个高合规跨国大厂与权威机构域名，多线程并发测量 VPS 到目标域名的真实 TLS 握手延迟（RTT），严格校验 `TLS 1.3`、`ALPN: h2` 及权威证书链，输出最快的前 10 个优质伪装目标。
- **快速运行**：
  ```bash
  bash <(curl -fsSL https://raw.githubusercontent.com/Docker7530/netbox/main/reality/sni.sh)
  ```

### 2. sing-box 核心配置 (`sing-box/config/`)
- **`config_sub.json`**：
  - **DNS 体系**：国内真实 IP 直连（AliDNS）+ 境外防污染解析（Google DoH + Fake-IP），配合 `action: evaluate` 智能探测边缘 CDN，开启 0ms 乐观缓存与逆向映射。
  - **分流机制**：严格三明治分流结构，业务分组（AI、YouTube、Google、X、PayPal 等）精准分立，大厂国内特供服务优先截胡直连。
  - **环境兼容**：深度适配 macOS 本地防护（局域网与投屏广播硬隔离），兼顾 Windows 即插即用防环路。
  - **自愈底座**：全量规则集与 Web 仪表盘统一接入 `gh-proxy` 镜像直连下载，零代理冷启动。
- **`auto-group.js`**：Sub-Store 自动化脚本，支持节点国家自动归类、排除高倍率节点，并自动识别 `👑 自建` 节点智能装载，避免自建 VPS 流量被测速轮询浪费。
