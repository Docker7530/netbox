<#
.SYNOPSIS
  sing-box Windows 服务管理脚本（基于 WinSW/同类 wrapper）

.DESCRIPTION
  约定：把本脚本放在 sing-box 服务目录下（同目录应包含 wrapper.exe 与 *.xml）。
  默认使用脚本所在目录作为服务目录。

.USAGE
  .\singbox.ps1                - 查看服务状态（默认）
  .\singbox.ps1 start          - 启动服务
  .\singbox.ps1 stop           - 停止服务
  .\singbox.ps1 restart        - 重启服务
  .\singbox.ps1 log            - 实时监控错误日志
  .\singbox.ps1 log <关键字>   - 实时监控并过滤包含关键字的日志（按字面匹配）
  .\singbox.ps1 config <URL>   - 从 URL 拉取配置并覆盖 config.json

.NOTES
  - 日志默认从 logs\*.err.log 里找；没有就退化为 logs\*.log。
  - 如需管理其他目录的服务：-ServiceDir "D:\\MyService\\sing-box"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateSet('start', 'stop', 'restart', 'log', 'config')]
    [string]$Action,

    [Parameter(Mandatory = $false, Position = 1)]
    [string]$Argument,

    [Parameter(Mandatory = $false)]
    [string]$ServiceDir = $PSScriptRoot
)
function Resolve-ServiceDir {
    param([string]$Dir)

    if ([string]::IsNullOrWhiteSpace($Dir)) {
        return $null
    }

    try {
        return (Resolve-Path -LiteralPath $Dir -ErrorAction Stop).Path
    }
    catch {
        return $null
    }
}

function Resolve-WrapperPath {
    param([string]$Dir)

    $candidates = @(
        'sing-box-service.exe',
        'WinSW-x64.exe',
        'WinSW.exe',
        'winsw.exe'
    )

    foreach ($name in $candidates) {
        $path = Join-Path -Path $Dir -ChildPath $name
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            return $path
        }
    }

    return $null
}

$resolvedServiceDir = Resolve-ServiceDir -Dir $ServiceDir
if (-not $resolvedServiceDir) {
    Write-Error "错误: 无法解析服务目录: $ServiceDir"
    return
}

$wrapperPath = Resolve-WrapperPath -Dir $resolvedServiceDir
if (-not $wrapperPath) {
    Write-Error "错误: 在 '$resolvedServiceDir' 找不到服务 wrapper exe（例如 sing-box-service.exe / WinSW-x64.exe）。请确认脚本位置，或使用 -ServiceDir 指定目录。"
    return
}

if (-not $PSBoundParameters.ContainsKey('Action')) {
    Write-Host "未指定操作，默认查看服务状态..." -ForegroundColor Cyan
    & $wrapperPath status
    return
}
if ($Action -eq 'log') {
    $logsDir = Join-Path -Path $resolvedServiceDir -ChildPath 'logs'
    if (-not (Test-Path -LiteralPath $logsDir -PathType Container)) {
        Write-Warning "未找到日志目录: $logsDir"
        return
    }

    $logFiles = Get-ChildItem -LiteralPath $logsDir -File -Filter '*.err.log' -ErrorAction SilentlyContinue
    if (-not $logFiles) {
        $logFiles = Get-ChildItem -LiteralPath $logsDir -File -Filter '*.log' -ErrorAction SilentlyContinue
    }

    if (-not $logFiles) {
        Write-Warning "未找到任何日志文件: $logsDir\\*.err.log 或 $logsDir\\*.log"
        return
    }

    $paths = $logFiles | Sort-Object LastWriteTime -Descending | Select-Object -ExpandProperty FullName
    Write-Host "实时监控日志: $($paths -join ', ')" -ForegroundColor Green

    if (-not [string]::IsNullOrEmpty($Argument)) {
        $pattern = [regex]::Escape($Argument)
        Get-Content -LiteralPath $paths -Tail 20 -Wait | Where-Object { $_ -match $pattern }
    }
    else {
        Get-Content -LiteralPath $paths -Tail 20 -Wait
    }

    return
}
if ($Action -eq 'config') {
    if ([string]::IsNullOrEmpty($Argument)) {
        Write-Error "错误: config 必须提供 URL，例如: .\\singbox.ps1 config https://example.com/config.json"
        return
    }

    $configUrl = $Argument
    $configPath = Join-Path -Path $resolvedServiceDir -ChildPath 'config.json'

    try {
        $invokeParams = @{ Uri = $configUrl; ErrorAction = 'Stop' }
        if ($PSVersionTable.PSVersion.Major -le 5) {
            $invokeParams.UseBasicParsing = $true
        }

        Write-Host "正在从 URL 拉取配置..." -ForegroundColor Cyan
        $response = Invoke-WebRequest @invokeParams
        $content = [string]$response.Content

        $trimmed = $content.TrimStart()
        if (-not ($trimmed.StartsWith('{') -or $trimmed.StartsWith('['))) {
            Write-Warning "警告: 下载内容看起来不像 JSON（不是以 '{' 或 '[' 开头），仍然会写入 config.json"
        }

        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($configPath, $content, $utf8NoBom)

        Write-Host "配置已成功写入: $configPath" -ForegroundColor Green
        Write-Host "提示: 如服务正在运行，请执行 '.\\singbox.ps1 restart' 应用新配置" -ForegroundColor Yellow
    }
    catch {
        Write-Error "配置更新失败: $($_.Exception.Message)"
    }

    return
}

Write-Host "正在对 sing-box 服务执行 '$Action' 操作..." -ForegroundColor Cyan
& $wrapperPath $Action
