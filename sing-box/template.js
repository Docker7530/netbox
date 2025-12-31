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
    { outbound: "公益", tags: String.raw`公益` },
  ],
};

const COMPATIBLE_OUTBOUND = {
  tag: "COMPATIBLE",
  type: "direct",
};

const args = (typeof $arguments === "object" && $arguments) || {};

const subscriptionName =
  (typeof args.name === "string" && args.name.trim()) || CONFIG.name;

const subscriptionType = normalizeSubscriptionType(args.type) || CONFIG.type;

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
  outboundReg: new RegExp(rule.outbound, "i"),
  tagReg: new RegExp(rule.tags, "i"),
}));

for (const outbound of config.outbounds) {
  if (!Array.isArray(outbound.outbounds)) continue;
  for (const { outboundReg, tagReg } of rules) {
    if (outboundReg.test(outbound.tag)) {
      const matchedTags = proxies
        .filter((p) => tagReg.test(p.tag))
        .map((p) => p.tag);
      if (matchedTags.length > 0) {
        outbound.outbounds.push(...matchedTags);
      } else if (!outbound.outbounds.includes("直连")) {
        outbound.outbounds.push("直连");
      }
    }
  }
}

config.outbounds.push(...proxies);

$content = JSON.stringify(config, null, 2);

function normalizeSubscriptionType(input) {
  if (typeof input !== "string") return "";
  const value = input.trim().toLowerCase();
  if (!value) return "";
  if (value === "c") return "collection";
  if (value === "s") return "subscription";
  return value;
}
