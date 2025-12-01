const SCRIPT_ARGUMENTS = {
  // collection | subscription
  type: "subscription",
  name: "Amy-clash",
  includeUnsupportedProxy: false,
  groups: [
    {
      outboundPattern: "🇭🇰 香港",
      tagPattern: "港|hk|hongkong|kong kong|🇭🇰",
      outboundIgnoreCase: true,
      tagIgnoreCase: true,
    },
    {
      outboundPattern: "🇹🇼 台湾",
      tagPattern: "台|tw|taiwan|🇹🇼",
      outboundIgnoreCase: true,
      tagIgnoreCase: true,
    },
    {
      outboundPattern: "🇯🇵 日本",
      tagPattern: "日本|jp|japan|🇯🇵",
      outboundIgnoreCase: true,
      tagIgnoreCase: true,
    },
    {
      outboundPattern: "🇸🇬 新加坡",
      tagPattern: "^(?!.*(?:us)).*(新|sg|singapore|🇸🇬)",
      outboundIgnoreCase: true,
      tagIgnoreCase: true,
    },
    {
      outboundPattern: "🇺🇸 美国",
      tagPattern: "美|us|unitedstates|united states|🇺🇸",
      outboundIgnoreCase: true,
      tagIgnoreCase: true,
    },
  ],
};

let { type, name, includeUnsupportedProxy, groups = [] } = SCRIPT_ARGUMENTS;

const parser = ProxyUtils.JSON5 || JSON;
let config;
try {
  config = parser.parse($content ?? $files[0]);
} catch (e) {
  throw new Error(
    `配置文件不是合法的 ${ProxyUtils.JSON5 ? "JSON5" : "JSON"} 格式`
  );
}
const proxies = await produceArtifact({
  name,
  type,
  platform: "sing-box",
  produceType: "internal",
  produceOpts: {
    "include-unsupported-proxy": includeUnsupportedProxy,
  },
});

const groupRules = (groups || []).map((group) => {
  const {
    outboundPattern,
    outboundIgnoreCase = true,
    tagPattern = ".*",
    tagIgnoreCase = true,
  } = group;
  const tagRegex = createTagRegExp(tagPattern, tagIgnoreCase);
  const outboundRegex = createOutboundRegExp(
    outboundPattern,
    outboundIgnoreCase
  );
  return { outboundRegex, tagRegex };
});

config.outbounds.map((outbound) => {
  groupRules.map(({ outboundRegex, tagRegex }) => {
    if (outboundRegex.test(outbound.tag)) {
      if (!Array.isArray(outbound.outbounds)) {
        outbound.outbounds = [];
      }
      const tags = getTags(proxies, tagRegex);
      outbound.outbounds.push(...tags);
    }
  });
});

const compatible_outbound = {
  tag: "COMPATIBLE",
  type: "direct",
};

let compatible;
config.outbounds.map((outbound) => {
  groupRules.map(({ outboundRegex }) => {
    if (outboundRegex.test(outbound.tag)) {
      if (!Array.isArray(outbound.outbounds)) {
        outbound.outbounds = [];
      }
      if (outbound.outbounds.length === 0) {
        if (!compatible) {
          config.outbounds.push(compatible_outbound);
          compatible = true;
        }
        outbound.outbounds.push(compatible_outbound.tag);
      }
    }
  });
});

config.outbounds.push(...proxies);

$content = JSON.stringify(config, null, 2);

function getTags(proxies, regex) {
  return (regex ? proxies.filter((p) => regex.test(p.tag)) : proxies).map(
    (p) => p.tag
  );
}
function createTagRegExp(tagPattern, ignoreCase) {
  return createRegExp(tagPattern, ignoreCase);
}
function createOutboundRegExp(outboundPattern, ignoreCase) {
  return createRegExp(outboundPattern, ignoreCase);
}
function createRegExp(pattern, ignoreCase) {
  return new RegExp(pattern, ignoreCase ? "i" : undefined);
}
