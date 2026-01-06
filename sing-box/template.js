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

const args = (typeof $arguments === "object" && $arguments) || {};

const subscriptionName =
  (typeof args.name === "string" && args.name.trim()) || CONFIG.name;

const t = args.type?.trim?.().toLowerCase?.();
const subscriptionType =
  t === "s" || t === "subscription" ? "subscription" : CONFIG.type;

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
  const targetRules = rules.filter(({ outboundReg }) =>
    outboundReg.test(outbound.tag)
  );
  for (const { tagReg } of targetRules) {
    const matchedTags = proxies
      .filter(({ tag }) => tagReg.test(tag))
      .map(({ tag }) => tag);
    if (matchedTags.length > 0) {
      outbound.outbounds.push(...matchedTags);
    } else if (!outbound.outbounds.includes("直连")) {
      outbound.outbounds.push("直连");
    }
  }
}

config.outbounds.push(...proxies);

$content = JSON.stringify(config, null, 2);
