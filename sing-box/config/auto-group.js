// 排除高倍率节点正则（匹配 2.0x、3.0x、5.0x、2x、3X、1.5x、2倍 等，安全保留 1.0x、1x、0.5x）
const HIGH_RATE = String.raw`(?<![\d\.])(?:([2-9]|\d{2,}|1\.[1-9])\d*(\.\d+)?\s*[xX倍]|[xX]\s*([2-9]|\d{2,}|1\.[1-9])\d*(\.\d+)?)(?!\d)`;

const CONFIG = {
  name: "all",
  type: "collection",
  includeUnsupportedProxy: false,
  groups: [
    {
      outbound: "🇺🇸 美国自动",
      tags: String.raw`^(?!.*(备胎|${HIGH_RATE})).*(美|us|unitedstates|united states|🇺🇸)`,
    },
    {
      outbound: "^🇺🇸 美国$",
      tags: String.raw`(美|us|unitedstates|united states|🇺🇸)`,
    },
    {
      outbound: "🇭🇰 香港自动",
      tags: String.raw`^(?!.*(备胎|${HIGH_RATE})).*(港|hk|hongkong|hong kong|🇭🇰)`,
    },
    {
      outbound: "^🇭🇰 香港$",
      tags: String.raw`(港|hk|hongkong|hong kong|🇭🇰)`,
    },
    {
      outbound: "🇹🇼 台湾",
      tags: String.raw`(台|tw|taiwan|🇹🇼)`,
    },
    {
      outbound: "🇯🇵 日本",
      tags: String.raw`(日本|jp|japan|🇯🇵)`,
    },
    {
      outbound: "🇸🇬 新加坡",
      tags: String.raw`(新|sg|singapore|🇸🇬)`,
    },
  ],
};

const args = (typeof $arguments === "object" && $arguments) || {};

const subscriptionName = (typeof args.name === "string" && args.name.trim()) || CONFIG.name;

const t = args.type?.trim?.().toLowerCase?.();
const subscriptionType = t === "s" || t === "subscription" ? "subscription" : CONFIG.type;

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
  const targetRules = rules.filter(({ outboundReg }) => outboundReg.test(outbound.tag));
  for (const { tagReg } of targetRules) {
    const matchedTags = proxies.filter(({ tag }) => tagReg.test(tag)).map(({ tag }) => tag);
    if (matchedTags.length > 0) {
      outbound.outbounds.push(...matchedTags);
    } else if (!outbound.outbounds.includes("直连")) {
      outbound.outbounds.push("直连");
    }
  }
}

config.outbounds.push(...proxies);

$content = JSON.stringify(config, null, 2);
