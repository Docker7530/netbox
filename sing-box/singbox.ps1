<#
.SYNOPSIS
  sing-box Windows 服务管理脚本（基于 WinSW/同类 wrapper）

.DESCRIPTION
  约定：把本脚本放在 sing-box 服务目录下（同目录应包含 wrapper.exe 与 *.xml）。
  默认使用脚本所在目录作为服务目录。

.USAGE
  .\singbox.ps1                - 查看服务状态（默认）
  .\singbox.ps1 stop           - 停止服务
  .\singbox.ps1 restart        - 重启服务
  .\singbox.ps1 log            - 实时监控错误日志
  .\singbox.ps1 log <关键字>    - 实时监控并过滤包含关键字的日志（按字面匹配）
  .\singbox.ps1 config <URL>   - 从 URL 拉取配置并覆盖 config.json，完成后自动重启
  .\singbox.ps1 update         - 停止服务，从 GitHub 下载最新稳定版 sing-box.exe 并替换，然后重启
  .\singbox.ps1 update <版本>  - 更新或回退到指定版本（如 1.13.8 或 v1.13.8）

.NOTES
  - 日志默认从 logs\*.err.log 里找；没有就退化为 logs\*.log。
  - 如需管理其他目录的服务：-ServiceDir "D:\\MyService\\sing-box"
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('stop', 'restart', 'log', 'config', 'update')]
    [string]$Action,

    [Parameter(Position = 1)]
    [string]$Argument,

    [Parameter()]
    [string]$ServiceDir = $PSScriptRoot
)

function Resolve-ServiceDir {
    param([string]$Dir)
    if ([string]::IsNullOrWhiteSpace($Dir)) { return $null }
    try { return (Resolve-Path -LiteralPath $Dir -ErrorAction Stop).Path }
    catch { return $null }
}

function Resolve-WrapperPath {
    param([string]$Dir)
    foreach ($name in 'sing-box-service.exe', 'WinSW-x64.exe', 'WinSW.exe', 'winsw.exe') {
        $path = Join-Path -Path $Dir -ChildPath $name
        if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
    }
    return $null
}

function Get-SingBoxVersion {
    param([string]$ExePath)

    if (-not (Test-Path -LiteralPath $ExePath -PathType Leaf)) {
        return $null
    }

    try {
        $versionOutput = & $ExePath version 2>$null
        if (-not $versionOutput) {
            return $null
        }

        $versionLine = $versionOutput | Select-Object -First 1
        if ($versionLine -match 'sing-box version\s+([^\s]+)') {
            return $matches[1]
        }
    }
    catch {
        return $null
    }

    return $null
}

function Resolve-SingBoxReleaseTarget {
    param([string]$VersionArgument)

    if ([string]::IsNullOrWhiteSpace($VersionArgument)) {
        return [pscustomobject]@{
            ApiUrl = 'https://api.github.com/repos/SagerNet/sing-box/releases/latest'
            DisplayName = '最新稳定版本'
            RequestedTag = $null
        }
    }

    $trimmed = $VersionArgument.Trim()
    $tag = if ($trimmed.StartsWith('v')) { $trimmed } else { "v$trimmed" }

    return [pscustomobject]@{
        ApiUrl = "https://api.github.com/repos/SagerNet/sing-box/releases/tags/$tag"
        DisplayName = "指定版本 $tag"
        RequestedTag = $tag
    }
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
        Write-Warning "未找到任何日志文件: $logsDir\*.err.log 或 $logsDir\*.log"
        return
    }

    $paths = $logFiles | Sort-Object LastWriteTime -Descending | Select-Object -ExpandProperty FullName
    Write-Host "实时监控日志: $($paths -join ', ')" -ForegroundColor Green

    $pattern = if ($Argument) { [regex]::Escape($Argument) } else { $null }
    $filter = if ($pattern) { { $_ -match $pattern }.GetNewClosure() } else { { $true } }
    Get-Content -LiteralPath $paths -Tail 20 -Wait | Where-Object $filter
    return
}

if ($Action -eq 'config') {
    if ([string]::IsNullOrEmpty($Argument)) {
        Write-Error "错误: config 必须提供 URL，例如: .\singbox.ps1 config https://example.com/config.json"
        return
    }

    $configPath = Join-Path -Path $resolvedServiceDir -ChildPath 'config.json'

    try {
        $invokeParams = @{ Uri = $Argument; ErrorAction = 'Stop' }
        if ($PSVersionTable.PSVersion.Major -le 5) { $invokeParams.UseBasicParsing = $true }

        Write-Host "正在从 URL 拉取配置..." -ForegroundColor Cyan
        $content = [string](Invoke-WebRequest @invokeParams).Content

        $trimmed = $content.TrimStart()
        if (-not ($trimmed.StartsWith('{') -or $trimmed.StartsWith('['))) {
            Write-Warning "警告: 下载内容看起来不像 JSON（不是以 '{' 或 '[' 开头），仍然会写入 config.json"
        }

        [System.IO.File]::WriteAllText($configPath, $content, [System.Text.UTF8Encoding]::new($false))
        Write-Host "配置已成功写入: $configPath" -ForegroundColor Green

        Write-Host "正在重启服务以应用新配置..." -ForegroundColor Cyan
        & $wrapperPath restart
    }
    catch {
        Write-Error "配置更新失败: $($_.Exception.Message)"
    }
    return
}

if ($Action -eq 'update') {
    try {
        $singboxExe = Join-Path -Path $resolvedServiceDir -ChildPath 'sing-box.exe'
        $localVersion = Get-SingBoxVersion -ExePath $singboxExe
        $releaseTarget = Resolve-SingBoxReleaseTarget -VersionArgument $Argument

        Write-Host "正在查询 GitHub $($releaseTarget.DisplayName)..." -ForegroundColor Cyan
        $apiParams = @{ Uri = $releaseTarget.ApiUrl; ErrorAction = 'Stop'; Headers = @{ 'User-Agent' = 'singbox-updater' } }
        if ($PSVersionTable.PSVersion.Major -le 5) { $apiParams.UseBasicParsing = $true }
        $release = Invoke-WebRequest @apiParams | ConvertFrom-Json

        $tag = $release.tag_name          # e.g. "v1.13.8"
        $version = $tag.TrimStart('v')    # e.g. "1.13.8"
        Write-Host "目标版本: $tag" -ForegroundColor Green

        if ($releaseTarget.RequestedTag -and $tag -ne $releaseTarget.RequestedTag) {
            Write-Error "错误: 请求的版本为 $($releaseTarget.RequestedTag)，但 GitHub 返回的是 $tag"
            return
        }

        if ($localVersion) {
            Write-Host "本地当前版本: v$localVersion" -ForegroundColor Green
            if ($localVersion -eq $version) {
                Write-Host "当前已是目标版本，无需更新" -ForegroundColor Yellow
                return
            }
        }
        else {
            Write-Warning "警告: 无法识别本地 sing-box 版本，将继续执行更新"
        }

        $assetName = "sing-box-$version-windows-amd64.zip"
        $asset = $release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
        if (-not $asset) {
            Write-Error "错误: 在发行版 $tag 中未找到资产 '$assetName'"
            return
        }

        $zipPath = Join-Path -Path $env:TEMP -ChildPath $assetName
        Write-Host "正在下载: $($asset.browser_download_url)" -ForegroundColor Cyan
        $dlParams = @{ Uri = $asset.browser_download_url; OutFile = $zipPath; ErrorAction = 'Stop' }
        if ($PSVersionTable.PSVersion.Major -le 5) { $dlParams.UseBasicParsing = $true }
        Invoke-WebRequest @dlParams
        Write-Host "下载完成: $zipPath" -ForegroundColor Green

        Write-Host "正在停止服务..." -ForegroundColor Cyan
        & $wrapperPath stop

        $extractDir = Join-Path -Path $env:TEMP -ChildPath "sing-box-update-$version"
        if (Test-Path -LiteralPath $extractDir) { Remove-Item -LiteralPath $extractDir -Recurse -Force }
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force

        $newExe = Join-Path -Path $extractDir -ChildPath "sing-box-$version-windows-amd64\sing-box.exe"
        if (-not (Test-Path -LiteralPath $newExe -PathType Leaf)) {
            Write-Error "错误: 解压后未找到 sing-box.exe（期望路径: $newExe）"
            & $wrapperPath start
            return
        }

        Copy-Item -LiteralPath $newExe -Destination $singboxExe -Force -ErrorAction SilentlyContinue
        if (-not $?) {
            # 服务进程可能还未完全释放文件句柄，等待重试
            $maxRetry = 10
            $copied = $false
            for ($i = 1; $i -le $maxRetry; $i++) {
                Start-Sleep -Milliseconds 500
                try {
                    Copy-Item -LiteralPath $newExe -Destination $singboxExe -Force -ErrorAction Stop
                    $copied = $true
                    break
                }
                catch {
                    Write-Host "文件仍被占用，等待重试 ($i/$maxRetry)..." -ForegroundColor Yellow
                }
            }
            if (-not $copied) {
                Write-Error "错误: 无法替换 sing-box.exe，文件持续被占用"
                & $wrapperPath start
                return
            }
        }
        Write-Host "已替换: $singboxExe" -ForegroundColor Green

        Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue

        Write-Host "正在重启服务..." -ForegroundColor Cyan
        & $wrapperPath start
        Write-Host "更新完成，当前版本: $tag" -ForegroundColor Green
    }
    catch {
        Write-Error "更新失败: $($_.Exception.Message)"
    }
    return
}

Write-Host "正在对 sing-box 服务执行 '$Action' 操作..." -ForegroundColor Cyan
& $wrapperPath $Action
