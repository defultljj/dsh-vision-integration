<#
.SYNOPSIS
  dsh-vision-integration — 一键部署 dsh-vision-router 到 DSH web profile。

.DESCRIPTION
  完整部署流程,与项目 README 的部署步骤一一对应:
    1. 备份现有 package.json → package.json.bak
    2. 用官方 CLI 执行安装(dsh plugin add,自动完成依赖+bundles+lockfile)
    3. 调用 scripts/verify.ps1 自动预检
  安装前会提示确认;用 -Force 跳过提示。

.EXAMPLE
  .\scripts\install.ps1
  .\scripts\install.ps1 -Force
#>
[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$profileDir = "$env:USERPROFILE\.dsh\profiles\web"
$pkgPath = Join-Path $profileDir 'package.json'

Write-Host "=== dsh-vision-router 一键部署 ===" -ForegroundColor Cyan
Write-Host "Profile: $profileDir`n"

if (-not (Test-Path $pkgPath)) {
    Write-Host "[FAIL] 未找到 $pkgPath,请确认 profile 名称" -ForegroundColor Red
    exit 1
}

if (-not $Force) {
    $ans = Read-Host "将安装 dsh-vision-router 到该 profile,继续? [y/N]"
    if ($ans -notmatch '^[yY]') { Write-Host "已取消" -ForegroundColor Yellow; exit 0 }
}

# 1. 备份
Copy-Item $pkgPath "$pkgPath.bak" -Force
Write-Host "[OK] 已备份 → package.json.bak" -ForegroundColor Green

# 2. 官方安装(自动处理依赖 + bundles 注册 + lockfile)
Write-Host "`n[STEP] 执行官方安装命令 ..." -ForegroundColor Cyan
Push-Location $profileDir
try {
    npx --yes @deepseek-ai/dsh plugin --profile web add dsh-vision-router 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] 安装命令退出码 $LASTEXITCODE" -ForegroundColor Red
        Pop-Location; exit 1
    }
}
finally {
    Pop-Location
}

# 3. 自动预检
Write-Host "`n[STEP] 自动预检 ..." -ForegroundColor Cyan
$verify = Join-Path $PSScriptRoot 'verify.ps1'
& $verify -ProfileDir $profileDir
exit $LASTEXITCODE
