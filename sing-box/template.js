// https://raw.githubusercontent.com/xream/scripts/main/surge/modules/sub-store-scripts/sing-box/template.js#type=组合订阅&name=机场&outbound=🕳ℹ️all|all-auto🕳ℹ️hk|hk-auto🏷ℹ️港|hk|hongkong|kong kong|🇭🇰🕳ℹ️tw|tw-auto🏷ℹ️台|tw|taiwan|🇹🇼🕳ℹ️jp|jp-auto🏷ℹ️日本|jp|japan|🇯🇵🕳ℹ️sg|sg-auto🏷ℹ️^(?!.*(?:us)).*(新|sg|singapore|🇸🇬)🕳ℹ️us|us-auto🏷ℹ️美|us|unitedstates|united states|🇺🇸

// 示例说明
// 读取 名称为 "机场" 的 组合订阅 中的节点(单订阅不需要设置 type 参数)
// 把 所有节点插入匹配 /all|all-auto/i 的 outbound 中(跟在 🕳 后面, ℹ️ 表示忽略大小写, 不筛选节点不需要给 🏷 )
// 把匹配 /港|hk|hongkong|kong kong|🇭🇰/i  (跟在 🏷 后面, ℹ️ 表示忽略大小写) 的节点插入匹配 /hk|hk-auto/i 的 outbound 中
// ...
// 可选参数: includeUnsupportedProxy 包含官方/商店版不支持的协议 SSR. 用法: `&includeUnsupportedProxy=true`

// ⚠️ 如果 outbounds 为空, 自动创建 COMPATIBLE(direct) 并插入 防止报错

// 在脚本内声明参数, 免去 URL 传参
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
