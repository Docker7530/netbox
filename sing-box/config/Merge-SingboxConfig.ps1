# Outbound：匹配 config_sub.json 中出站组的 tag（用于定位要填充哪个组）
# Tags：匹配节点的 tag（用于筛选归属该组的节点），-imatch 大小写不敏感
$script:GROUPS = @(
    @{ Outbound = '🇭🇰 香港'; Tags = '^(?!.*公益).*(港|hk|hongkong|hong kong|🇭🇰)' }
    @{ Outbound = '🇹🇼 台湾'; Tags = '^(?!.*公益).*(台|tw|taiwan|🇹🇼)' }
    @{ Outbound = '🇯🇵 日本'; Tags = '^(?!.*公益).*(日本|jp|japan|🇯🇵)' }
    @{ Outbound = '🇸🇬 新加坡'; Tags = '^(?!.*公益).*(新|sg|singapore|🇸🇬)' }
    @{ Outbound = '🇺🇸 美国'; Tags = '^(?!.*公益).*(美|us|unitedstates|united states|🇺🇸)' }
    @{ Outbound = '公益'; Tags = '公益' }
)

function Merge-SingboxConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SubstoreUrl,
        [Parameter(Mandatory)][string]$BaseConfigPath,
        [Parameter(Mandatory)][string]$OutputPath
    )

    Write-Host "正在从 substore 拉取节点..." -ForegroundColor Cyan
    $fetchParams = @{ Uri = $SubstoreUrl; ErrorAction = 'Stop' }
    if ($PSVersionTable.PSVersion.Major -le 5) { $fetchParams.UseBasicParsing = $true }
    $rawNodes = Invoke-RestMethod @fetchParams
    $proxies = @($rawNodes.outbounds)
    if ($proxies.Count -eq 0) { throw "拉取的节点为空或格式错误" }
    Write-Host "获取到 $($proxies.Count) 个节点" -ForegroundColor Green

    # 基础配置包含入站、路由、DNS 等，outbounds 中各分组的节点列表为空，由本函数填充
    $baseContent = [System.IO.File]::ReadAllText($BaseConfigPath, [System.Text.Encoding]::UTF8)
    $config = $baseContent | ConvertFrom-Json

    foreach ($outbound in $config.outbounds) {
        # 通过 PSObject.Properties 检测属性是否存在，比直接访问更可靠（避免 PS5 严格模式问题）
        $prop = $outbound.PSObject.Properties['outbounds']
        if ($null -eq $prop) { continue }

        $list = [System.Collections.Generic.List[string]]::new()
        foreach ($item in @($prop.Value)) { if ($item) { $list.Add([string]$item) } }

        foreach ($group in $script:GROUPS) {
            if ($outbound.tag -imatch $group.Outbound) {
                $matched = @($proxies | Where-Object { $_.tag -and ($_.tag -imatch $group.Tags) } | ForEach-Object { $_.tag })
                if ($matched.Count -gt 0) {
                    foreach ($t in $matched) { $list.Add($t) }
                }
                elseif (-not $list.Contains('直连')) {
                    # 该地区无可用节点时回退直连，与 auto-group.js 行为一致
                    $list.Add('直连')
                }
            }
        }

        $outbound.outbounds = $list.ToArray()
    }

    # 将原始节点追加到 outbounds 末尾，供各分组引用
    $allOutbounds = [System.Collections.Generic.List[object]]::new()
    foreach ($ob in @($config.outbounds)) { $allOutbounds.Add($ob) }
    foreach ($p in $proxies) { $allOutbounds.Add($p) }
    $config.outbounds = $allOutbounds.ToArray()

    # Depth 20 防止深层嵌套（如 tls.reality）被截断；BOM-free UTF-8 避免 sing-box 解析异常
    $json = $config | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($OutputPath, $json, [System.Text.UTF8Encoding]::new($false))
    Write-Host "配置已写入: $OutputPath" -ForegroundColor Green
}
