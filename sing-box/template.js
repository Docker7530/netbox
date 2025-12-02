const CONFIG = {
  subName: "Amy-clash",
  includeUnsupportedProxy: false,
  groups: [
    { outbound: "🇭🇰 香港", tags: "港|hk|hongkong|kong kong|🇭🇰" },
    { outbound: "🇹🇼 台湾", tags: "台|tw|taiwan|🇹🇼" },
    { outbound: "🇯🇵 日本", tags: "日本|jp|japan|🇯🇵" },
    { outbound: "🇸🇬 新加坡", tags: "^(?!.*(?:us)).*(新|sg|singapore|🇸🇬)" },
    { outbound: "🇺🇸 美国", tags: "美|us|unitedstates|united states|🇺🇸" },
  ],
};

const COMPATIBLE_OUTBOUND = {
  tag: "COMPATIBLE",
  type: "direct",
};

const rawConfig = $content ?? $files?.[0];
const parser = ProxyUtils.JSON5 || JSON;
const config = parser.parse(rawConfig);

if (!Array.isArray(config.outbounds)) {
  throw new Error("配置文件格式错误：未找到 outbounds 字段");
}

const proxies = await produceArtifact({
  name: CONFIG.subName,
  type: "subscription",
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
      } else {
        // 无匹配节点，注入兜底
        if (!outbound.outbounds.includes(COMPATIBLE_OUTBOUND.tag)) {
          outbound.outbounds.push(COMPATIBLE_OUTBOUND.tag);
          fallbackUsed = true;
        }
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
