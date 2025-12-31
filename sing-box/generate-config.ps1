#!/usr/bin/env pwsh
#requires -Version 7.0

[CmdletBinding()]
param(
  # 订阅来源：可传 sub-store 的 download URL（推荐），或本地 JSON 文件路径
  [Parameter(Mandatory = $false)]
  [string]$SubscriptionUrl,

  # 直接传入订阅 JSON 字符串（用于你自己拉取/缓存后再喂给脚本）
  [Parameter(Mandatory = $false)]
  [string]$SubscriptionJson,

  # 基础配置模板（默认同目录的 config_sub.json）
  [Parameter(Mandatory = $false)]
  [string]$ConfigPath = (Join-Path $PSScriptRoot 'config_sub.json'),

  # 输出文件路径
  [Parameter(Mandatory = $false)]
  [string]$OutputPath = (Join-Path $PSScriptRoot 'config.json')
)

function Read-Subscription {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionUrl,

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionJson
  )

  if ($SubscriptionJson) {
    $obj = ConvertFrom-Json -InputObject $SubscriptionJson -Depth 100
    Assert-SubscriptionShape -Subscription $obj
    return $obj
  }

  if (-not $SubscriptionUrl) {
    throw '必须提供 -SubscriptionUrl 或 -SubscriptionJson'
  }

  if (Test-Path -LiteralPath $SubscriptionUrl) {
    $raw = Get-Content -LiteralPath $SubscriptionUrl -Raw
    $obj = ConvertFrom-Json -InputObject $raw -Depth 100
    Assert-SubscriptionShape -Subscription $obj
    return $obj
  }

  if ($SubscriptionUrl -notmatch '^https?://') {
    throw "-SubscriptionUrl 既不是 http(s) URL 也不是本地文件路径：$SubscriptionUrl"
  }

  try {
    $raw = Invoke-RestMethod -Method Get -Uri $SubscriptionUrl -TimeoutSec 30 -ResponseHeadersVariable _headers
    # Invoke-RestMethod 可能直接给对象，也可能给字符串；统一到对象
    if ($raw -is [string]) {
      $obj = ConvertFrom-Json -InputObject $raw -Depth 100
    } else {
      $obj = $raw
    }
  } catch {
    throw "拉取订阅失败：$SubscriptionUrl\n$($_.Exception.Message)"
  }

  Assert-SubscriptionShape -Subscription $obj
  return $obj
}

function Merge-ProxiesIntoConfig {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object]$Config,

    [Parameter(Mandatory = $true)]
    [object[]]$Proxies,

    [Parameter(Mandatory = $true)]
    [hashtable[]]$Groups,

    [Parameter(Mandatory = $true)]
    [object]$CompatibleOutbound
  )

  $rules = foreach ($g in $Groups) {
    [pscustomobject]@{
      outboundReg = [string]$g.outbound
      tagReg      = [string]($g.tags ?? '.*')
    }
  }

  $fallbackUsed = $false

  foreach ($outbound in @($Config.outbounds)) {
    if (-not (Has-ArrayProperty -Object $outbound -Name 'outbounds')) { continue }

    $outboundTag = [string]($outbound.tag ?? '')
    if (-not $outboundTag) { continue }

    foreach ($rule in $rules) {
      if ($outboundTag -match $rule.outboundReg) {
        $matchedTags = @(
          foreach ($p in $Proxies) {
            $tag = [string]($p.tag ?? '')
            if (-not $tag) { continue }
            if ($tag -match $rule.tagReg) { $tag }
          }
        )

        if ($matchedTags.Count -gt 0) {
          $outbound.outbounds = @($outbound.outbounds) + $matchedTags
        } else {
          if (@($outbound.outbounds) -notcontains $CompatibleOutbound.tag) {
            $outbound.outbounds = @($outbound.outbounds) + @($CompatibleOutbound.tag)
            $fallbackUsed = $true
          }
        }
      }
    }
  }

  if ($fallbackUsed) {
    $hasFallback = $false
    foreach ($o in @($Config.outbounds)) {
      if ([string]($o.tag ?? '') -eq [string]$CompatibleOutbound.tag) { $hasFallback = $true; break }
    }

    if (-not $hasFallback) {
      $Config.outbounds = @($Config.outbounds) + @($CompatibleOutbound)
    }
  }

  $Config.outbounds = @($Config.outbounds) + $Proxies
}

function Assert-SubscriptionShape {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object]$Subscription
  )

  if (-not $Subscription) {
    throw '订阅内容为空或不是合法 JSON'
  }

  if (-not (Has-ArrayProperty -Object $Subscription -Name 'outbounds')) {
    throw '订阅内容格式错误：缺少 outbounds 数组'
  }
}

function Assert-ConfigShape {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object]$Config
  )

  if (-not $Config) {
    throw '配置文件为空或不是合法 JSON'
  }

  if (-not (Has-ArrayProperty -Object $Config -Name 'outbounds')) {
    throw '配置文件格式错误 outbounds 字段缺失或不是数组'
  }
}

function Has-ArrayProperty {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object]$Object,

    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  $p = $Object.PSObject.Properties[$Name]
  if (-not $p) { return $false }
  return $p.Value -is [System.Collections.IEnumerable] -and $p.Value -isnot [string]
}

function Read-JsonFile {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "找不到配置文件：$Path"
  }

  $raw = Get-Content -LiteralPath $Path -Raw
  try {
    return ConvertFrom-Json -InputObject $raw -Depth 100
  } catch {
    throw "解析 JSON 失败：$Path\n$($_.Exception.Message)"
  }
}

function Write-JsonFile {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [object]$Object
  )

  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }

  $json = $Object | ConvertTo-Json -Depth 100
  Set-Content -LiteralPath $Path -Value $json -Encoding utf8NoBOM
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Groups = @(
  @{ outbound = '白嫖'; tags = '公益' },
  @{ outbound = '🇭🇰 香港'; tags = '^(?!.*公益).*(港|hk|hongkong|kong kong|🇭🇰)' },
  @{ outbound = '🇹🇼 台湾'; tags = '^(?!.*公益).*(台|tw|taiwan|🇹🇼)' },
  @{ outbound = '🇯🇵 日本'; tags = '^(?!.*公益).*(日本|jp|japan|🇯🇵)' },
  @{ outbound = '🇸🇬 新加坡'; tags = '^(?!.*公益)(?!.*(?:us)).*(新|sg|singapore|🇸🇬)' },
  @{ outbound = '🇺🇸 美国'; tags = '^(?!.*公益).*(美|us|unitedstates|united states|🇺🇸)' }
)

$CompatibleOutbound = [pscustomobject]@{
  tag  = 'COMPATIBLE'
  type = 'direct'
}

$config = Read-JsonFile -Path $ConfigPath
Assert-ConfigShape -Config $config

$subscription = Read-Subscription -SubscriptionUrl $SubscriptionUrl -SubscriptionJson $SubscriptionJson
$proxies = @($subscription.outbounds)

if ($proxies.Count -eq 0) {
  throw "订阅内容里 outbounds 为空：$SubscriptionUrl"
}

Merge-ProxiesIntoConfig -Config $config -Proxies $proxies -Groups $Groups -CompatibleOutbound $CompatibleOutbound

Write-JsonFile -Path $OutputPath -Object $config
Write-Host "已生成：$OutputPath" -ForegroundColor Green
