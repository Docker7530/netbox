const CONFIG = {
  name: "all",
  type: "collection",
  includeUnsupportedProxy: false,
  groups: [
    {
      outbound: "🇭🇰 香港",
      tags: String.raw`^(?!.*公益).*(港|hk|hongkong|kong kong|🇭🇰)`,
    },
    {
      outbound: "🇹🇼 台湾",
      tags: String.raw`^(?!.*公益).*(台|tw|taiwan|🇹🇼)`,
    },
    {
      outbound: "🇯🇵 日本",
      tags: String.raw`^(?!.*公益).*(日本|jp|japan|🇯🇵)`,
    },
    {
      outbound: "🇸🇬 新加坡",
      tags: String.raw`^(?!.*公益).*(新|sg|singapore|🇸🇬)`,
    },
    {
      outbound: "🇺🇸 美国",
      tags: String.raw`^(?!.*公益).*(美|us|unitedstates|united states|🇺🇸)`,
    },
    { outbound: "白嫖", tags: String.raw`公益` },
  ],
};

const args = (typeof $arguments === "object" && $arguments) || {};
const subscriptionName =
  (typeof args.name === "string" && args.name.trim()) || CONFIG.name;
const subscriptionType = normalizeSubscriptionType(args.type) || CONFIG.type;

const COMPATIBLE_OUTBOUND = {
  tag: "COMPATIBLE",
  type: "direct",
};

const rawConfig = $content ?? $files?.[0];
const parser = ProxyUtils.JSON5 || JSON;
const config = parser.parse(rawConfig);

if (!Array.isArray(config.outbounds)) {
  throw new TypeError("配置文件格式错误: outbounds 字段缺失或不是数组");
}

const proxies = await produceArtifact({
  name: subscriptionName,
  type: subscriptionType,
  platform: "sing-box",
  produceType: "internal",
  produceOpts: {
    "include-unsupported-proxy": CONFIG.includeUnsupportedProxy,
  },
});

const rules = CONFIG.groups.map((rule) => ({
  outboundReg: createRegExp(rule.outbound),
  tagReg: createRegExp(rule.tags || ".*"),
}));

let fallbackUsed = false;

for (const outbound of config.outbounds) {
  // 跳过非策略组节点 (没有 outbounds 字段的通常是直接代理或 direct/block)
  if (!Array.isArray(outbound.outbounds)) continue;

  // 遍历规则寻找匹配
  for (const { outboundReg, tagReg } of rules) {
    if (outboundReg.test(outbound.tag)) {
      // 筛选符合条件的节点 tag
      const matchedTags = proxies
        .filter((p) => tagReg.test(p.tag))
        .map((p) => p.tag);

      if (matchedTags.length > 0) {
        // 注入节点
        outbound.outbounds.push(...matchedTags);
      } else if (!outbound.outbounds.includes(COMPATIBLE_OUTBOUND.tag)) {
        outbound.outbounds.push(COMPATIBLE_OUTBOUND.tag);
        fallbackUsed = true;
      }
    }
  }
}

if (fallbackUsed) {
  const hasFallback = config.outbounds.some(
    (o) => o.tag === COMPATIBLE_OUTBOUND.tag
  );
  if (!hasFallback) {
    config.outbounds.push(COMPATIBLE_OUTBOUND);
  }
}

config.outbounds.push(...proxies);

$content = JSON.stringify(config, null, 2);

function createRegExp(pattern) {
  if (pattern instanceof RegExp) {
    const flags = pattern.flags.includes("i")
      ? pattern.flags
      : pattern.flags + "i";
    return new RegExp(pattern.source, flags);
  }
  return new RegExp(pattern, "i");
}

function normalizeSubscriptionType(input) {
  if (typeof input !== "string") return "";
  const value = input.trim().toLowerCase();
  if (!value) return "";
  if (value === "c") return "collection";
  if (value === "s") return "subscription";
  return value;
}
