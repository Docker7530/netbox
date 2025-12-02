const COMPATIBLE_OUTBOUND = {
  tag: "COMPATIBLE",
  type: "direct",
};

const SCRIPT_ARGUMENTS = {
  type: "subscription",
  name: "Amy-clash",
  includeUnsupportedProxy: false,
  groups: [
    { outboundPattern: "🇭🇰 香港", tagPattern: "港|hk|hongkong|kong kong|🇭🇰" },
    { outboundPattern: "🇹🇼 台湾", tagPattern: "台|tw|taiwan|🇹🇼" },
    { outboundPattern: "🇯🇵 日本", tagPattern: "日本|jp|japan|🇯🇵" },
    {
      outboundPattern: "🇸🇬 新加坡",
      tagPattern: "^(?!.*(?:us)).*(新|sg|singapore|🇸🇬)",
    },
    {
      outboundPattern: "🇺🇸 美国",
      tagPattern: "美|us|unitedstates|united states|🇺🇸",
    },
  ],
};

await buildSingBoxConfig(SCRIPT_ARGUMENTS);

async function buildSingBoxConfig(options) {
  const {
    type = "subscription",
    name,
    includeUnsupportedProxy = false,
    groups = [],
  } = options;
  const parser = ProxyUtils.JSON5 || JSON;
  const rawConfig = $content ?? $files[0];
  const config = parser.parse(rawConfig);
  const proxies = await fetchProxies({
    name,
    type,
    includeUnsupportedProxy,
  });
  const rules = buildGroupRules(groups);
  injectGroupOutbounds(config.outbounds, proxies, rules);
  ensureCompatibleFallback(config.outbounds, rules);
  config.outbounds.push(...proxies);
  $content = JSON.stringify(config, null, 2);
}

async function fetchProxies({ name, type, includeUnsupportedProxy }) {
  return produceArtifact({
    name,
    type,
    platform: "sing-box",
    produceType: "internal",
    produceOpts: {
      "include-unsupported-proxy": includeUnsupportedProxy,
    },
  });
}

function buildGroupRules(groups) {
  if (!Array.isArray(groups) || groups.length === 0) {
    return [];
  }
  return groups.map(({ outboundPattern, tagPattern = ".*" }) => ({
    outboundRegex: createRegExp(outboundPattern),
    tagRegex: createRegExp(tagPattern),
  }));
}

function ensureOutboundList(outbound) {
  if (!Array.isArray(outbound.outbounds)) {
    outbound.outbounds = [];
  }
  return outbound.outbounds;
}

function injectGroupOutbounds(outbounds = [], proxies = [], rules = []) {
  for (const outbound of outbounds) {
    for (const { outboundRegex, tagRegex } of rules) {
      if (!outboundRegex.test(outbound.tag)) {
        continue;
      }
      const tags = getTags(proxies, tagRegex);
      if (tags.length === 0) {
        continue;
      }
      ensureOutboundList(outbound).push(...tags);
    }
  }
}

function ensureCompatibleFallback(outbounds = [], rules = []) {
  if (rules.length === 0) {
    return;
  }
  let compatibleInjected = outbounds.some(
    (item) => item.tag === COMPATIBLE_OUTBOUND.tag
  );
  for (const outbound of outbounds) {
    if (outbound.tag === COMPATIBLE_OUTBOUND.tag) {
      continue;
    }
    for (const { outboundRegex } of rules) {
      if (!outboundRegex.test(outbound.tag)) {
        continue;
      }
      const entries = ensureOutboundList(outbound);
      if (entries.length > 0) {
        break;
      }
      if (!compatibleInjected) {
        outbounds.push({ ...COMPATIBLE_OUTBOUND });
        compatibleInjected = true;
      }
      entries.push(COMPATIBLE_OUTBOUND.tag);
      break;
    }
  }
}

function getTags(proxies, regex) {
  return (regex ? proxies.filter((p) => regex.test(p.tag)) : proxies).map(
    (p) => p.tag
  );
}

function createRegExp(pattern = ".*") {
  if (pattern instanceof RegExp) {
    const flags = pattern.flags.includes("i")
      ? pattern.flags
      : `${pattern.flags}i`;
    return new RegExp(pattern.source, flags);
  }
  return new RegExp(pattern, "i");
}
