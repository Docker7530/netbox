# AGENTS.md

本文件为自动化智能体（AI Agent / Coding Assistant）在当前代码仓库（netbox）工作时的规范与约束指引。

---

## 1. Python 环境规范 (Virtual Environment)

- 本仓库的 Python 工具与依赖均运行于仓库根目录下的专属虚拟环境 `.venv/`。
- **严禁直接使用宿主机全局 Python 环境**安装任何第三方依赖或执行脚本。
- 工具脚本（如 `./tools/format_config.py`）内置了解释器自动切换机制，但所有自动化操作必须尊重 `.venv/` 的隔离性。

---

## 2. 配置文件格式化约束 (Pre-commit Formatter)

- **强制规则**：
  在对 `sing-box/` 目录下的任何 JSON 配置文件（包括但不限于 `sing-box/config/config_sub.json` 等）进行修改、新增、调优或合并之后，**在执行 Git 提交（git commit）前，必须运行格式化工具**：

  ```bash
  ./tools/format_config.py [配置文件路径]
  ```

  若未指定路径，工具将默认处理 `sing-box/config/config_sub.json`。

- **格式化标准**：
  - 遵循本项目的通用紧凑规则（Compact JSON Serialization）。
  - `dns.servers`、`dns.rules`、`outbounds`、`route.rules`、`route.rule_set`、`http_clients` 的每个规则与策略对象必须保持整洁的单行紧凑展示。
  - 根结构与复杂块保持标准 2 空格缩进。
  - 必须保证 `json.loads()` 语义 100% 等价，严禁丢失字段、修改 IPv6 CIDR 格式或破坏节点 Emoji。
