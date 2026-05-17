<#
.SYNOPSIS
  sing-box Windows 服务管理脚本（基于 WinSW/同类 wrapper）

.DESCRIPTION
  约定：把本脚本放在 sing-box 服务目录下（同目录应包含 sing-box-service.exe 与 *.xml）。
  脚本始终以自身所在目录作为服务目录。

.USAGE
  .\Manage-SingBox.ps1                - 查看服务状态（默认）
  .\Manage-SingBox.ps1 install        - 安装服务
  .\Manage-SingBox.ps1 uninstall      - 卸载服务
  .\Manage-SingBox.ps1 stop           - 停止服务
  .\Manage-SingBox.ps1 restart        - 重启服务
  .\Manage-SingBox.ps1 log            - 实时监控错误日志
  .\Manage-SingBox.ps1 log <关键字>    - 实时监控并过滤包含关键字的日志（按字面匹配）
  .\Manage-SingBox.ps1 config <URL>   - 从 substore URL 拉取原始节点，与 config_sub.json 合并后写入 config.json 并重启
  .\Manage-SingBox.ps1 update         - 停止服务，从 GitHub 下载最新稳定版 sing-box.exe 并替换，然后重启
  .\Manage-SingBox.ps1 update <版本>  - 更新或回退到指定版本（如 1.13.8 或 v1.13.8）

.NOTES
  - 日志默认从 logs\*.err.log 里找；没有就退化为 logs\*.log。
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('stop', 'restart', 'log', 'config', 'update', 'install', 'uninstall')]
    [string]$Action,

    [Parameter(Position = 1)]
    [string]$Argument
)

# 执行 `sing-box version` 并从首行提取版本号，用于更新前与目标版本的比对
function Get-SingBoxVersion {
    param([string]$ExePath)
    if (-not (Test-Path -LiteralPath $ExePath -PathType Leaf)) { return $null }
    try {
        $line = & $ExePath version 2>$null | Select-Object -First 1
        if ($line -match 'sing-box version\s+(\S+)') { return $matches[1] }
    }
    catch {}
    return $null
}

# 跟随 /releases/latest 重定向，从最终 URL 解析 tag（不走 API，无速率限制）
function Resolve-LatestSingBoxTag {
    $response = Invoke-WebRequest -Uri 'https://github.com/SagerNet/sing-box/releases/latest' `
        -UseBasicParsing -MaximumRedirection 10 -ErrorAction Stop
    $finalUrl = if ($PSVersionTable.PSVersion.Major -le 5) {
        $response.BaseResponse.ResponseUri.ToString()
    }
    else {
        $response.BaseResponse.RequestMessage.RequestUri.ToString()
    }
    return ($finalUrl.TrimEnd('/') -split '/')[-1]
}

$wrapperPath = Join-Path -Path $PSScriptRoot -ChildPath 'sing-box-service.exe'
if (-not (Test-Path -LiteralPath $wrapperPath -PathType Leaf)) {
    Write-Error "错误: 在 '$PSScriptRoot' 找不到 sing-box-service.exe，请确认脚本位置。"
    return
}

if (-not $PSBoundParameters.ContainsKey('Action')) {
    Write-Host "未指定操作，默认查看服务状态..." -ForegroundColor Cyan
    & $wrapperPath status
    return
}

if ($Action -eq 'log') {
    $logsDir = Join-Path -Path $PSScriptRoot -ChildPath 'logs'
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

    if ($Argument) {
        $escaped = [regex]::Escape($Argument)
        Get-Content -LiteralPath $paths -Tail 20 -Wait | Where-Object { $_ -match $escaped }
    }
    else {
        Get-Content -LiteralPath $paths -Tail 20 -Wait
    }
    return
}

if ($Action -eq 'config') {
    if ([string]::IsNullOrEmpty($Argument)) {
        Write-Error "错误: config 必须提供节点订阅 URL，例如: .\Manage-SingBox.ps1 config https://example.com/nodes"
        return
    }

    # 按需加载合并工具脚本（dot-source），每次执行 config 动作时重新载入确保最新
    . "$PSScriptRoot\config\Merge-SingboxConfig.ps1"

    $baseConfigPath = Join-Path -Path $PSScriptRoot -ChildPath 'config\config_sub.json'
    $outputPath = Join-Path -Path $PSScriptRoot -ChildPath 'config.json'

    try {
        Merge-SingboxConfig -SubstoreUrl $Argument -BaseConfigPath $baseConfigPath -OutputPath $outputPath

        Write-Host "正在重启服务以应用新配置..." -ForegroundColor Cyan
        & $wrapperPath restart
    }
    catch {
        Write-Error "配置更新失败: $($_.Exception.Message)"
    }
    return
}

if ($Action -eq 'update') {
    $stopped = $false
    try {
        $singboxExe = Join-Path -Path $PSScriptRoot -ChildPath 'sing-box.exe'
        $localVersion = Get-SingBoxVersion -ExePath $singboxExe

        if ([string]::IsNullOrWhiteSpace($Argument)) {
            Write-Host "正在查询最新稳定版本..." -ForegroundColor Cyan
            $tag = Resolve-LatestSingBoxTag
        }
        else {
            $tag = 'v' + $Argument.Trim().TrimStart('v')
        }

        $version = $tag.TrimStart('v')
        Write-Host "目标版本: $tag" -ForegroundColor Green

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
        $downloadUrl = "https://github.com/SagerNet/sing-box/releases/download/$tag/$assetName"
        $zipPath = Join-Path -Path $env:TEMP -ChildPath $assetName
        Write-Host "正在下载: $downloadUrl" -ForegroundColor Cyan
        $dlParams = @{ Uri = $downloadUrl; OutFile = $zipPath; ErrorAction = 'Stop' }
        if ($PSVersionTable.PSVersion.Major -le 5) { $dlParams.UseBasicParsing = $true }
        Invoke-WebRequest @dlParams
        Write-Host "下载完成: $zipPath" -ForegroundColor Green

        Write-Host "正在停止服务..." -ForegroundColor Cyan
        & $wrapperPath stop
        $stopped = $true

        $extractDir = Join-Path -Path $env:TEMP -ChildPath "sing-box-update-$version"
        if (Test-Path -LiteralPath $extractDir) { Remove-Item -LiteralPath $extractDir -Recurse -Force }
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force

        $newExe = Join-Path -Path $extractDir -ChildPath "sing-box-$version-windows-amd64\sing-box.exe"
        if (-not (Test-Path -LiteralPath $newExe -PathType Leaf)) {
            Write-Error "错误: 解压后未找到 sing-box.exe（期望路径: $newExe）"
            if ($stopped) { & $wrapperPath start }
            return
        }

        # 服务进程可能还未完全释放文件句柄，首次失败后等待重试
        $maxRetry = 10
        $copied = $false
        for ($i = 0; $i -le $maxRetry; $i++) {
            if ($i -gt 0) { Start-Sleep -Milliseconds 500 }
            try {
                Copy-Item -LiteralPath $newExe -Destination $singboxExe -Force -ErrorAction Stop
                $copied = $true
                break
            }
            catch {
                if ($i -gt 0) { Write-Host "文件仍被占用，等待重试 ($i/$maxRetry)..." -ForegroundColor Yellow }
            }
        }
        if (-not $copied) {
            Write-Error "错误: 无法替换 sing-box.exe，文件持续被占用"
            if ($stopped) { & $wrapperPath start }
            return
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
        if ($stopped) { & $wrapperPath start }
    }
    return
}

Write-Host "正在对 sing-box 服务执行 '$Action' 操作..." -ForegroundColor Cyan
& $wrapperPath $Action
