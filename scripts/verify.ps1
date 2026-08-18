<#
.SYNOPSIS
  dsh-vision-integration — 一键预检:验证 dsh-vision-router 在 DSH web profile 中是否正确安装、注册、可加载。

.DESCRIPTION
  执行与人工部署验证一致的完整检查链:
    1. profile 目录与 package.json 存在性
    2. JSON 语法合法性(可被 JSON.parse 解析)
    3. 无 UTF-8 BOM(首字节必须是 '{')
    4. dependencies 中已注册 dsh-vision-router
    5. dsh.profile.bundles 中已注册 dsh-vision-router
    6. node_modules 中插件实体存在
    7. 模块加载预检:动态 import 后 apply 导出为 function(杜绝 invalid plugin 崩溃)
  任何一项失败 → 打印 [FAIL] 并以退出码 1 结束。

.EXAMPLE
  .\scripts\verify.ps1
  .\scripts\verify.ps1 -ProfileDir C:\Users\<你的用户名>\.dsh\profiles\web
#>
[CmdletBinding()]
param(
    [string]$ProfileDir = "$env:USERPROFILE\.dsh\profiles\web"
)

$ErrorActionPreference = 'Stop'
$failCount = 0

function Check([string]$Name, [bool]$Ok, [string]$Detail = '') {
    if ($Ok) {
        Write-Host "[PASS] $Name" -ForegroundColor Green
    }
    else {
        Write-Host "[FAIL] $Name $Detail" -ForegroundColor Red
        $script:failCount++
    }
}

Write-Host "=== dsh-vision-router 预检 ===" -ForegroundColor Cyan
Write-Host "Profile: $ProfileDir`n"

# 1. 目录与 manifest 存在
Check "profile 目录存在" (Test-Path $ProfileDir)
$pkgPath = Join-Path $ProfileDir 'package.json'
Check "package.json 存在" (Test-Path $pkgPath)

if (-not (Test-Path $pkgPath)) { Write-Host "`n预检中止:缺少 package.json" -ForegroundColor Yellow; exit 1 }

# 2. 无 BOM(首字节必须为 ASCII '{' = 0x7B = 123)
$bytes = [System.IO.File]::ReadAllBytes($pkgPath)
Check "无 UTF-8 BOM(首字节=123)" ($bytes.Length -gt 0 -and $bytes[0] -eq 123) "(实际 $($bytes[0]))"

# 3. JSON 语法合法
$jsonOk = $true
$pkg = $null
try {
    $pkg = Get-Content $pkgPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
}
catch {
    $jsonOk = $false
    $jsonErr = $_.Exception.Message
}
Check "JSON 语法合法" $jsonOk ($jsonErr)

if (-not $jsonOk) { Write-Host "`n预检中止:package.json 无法解析" -ForegroundColor Yellow; exit 1 }

# 4. dependencies 注册
$depVer = $pkg.dependencies.'dsh-vision-router'
Check "dependencies 已注册" (-not [string]::IsNullOrEmpty($depVer)) "(版本: $depVer)"

# 5. bundles 注册
$inBundles = $pkg.dsh.profile.bundles -contains 'dsh-vision-router'
Check "dsh.profile.bundles 已注册" $inBundles

# 6. 插件实体存在
$entry = Join-Path $ProfileDir 'node_modules\dsh-vision-router\entry.js'
Check "node_modules 插件实体存在" (Test-Path $entry)

# 7. 模块加载预检(模拟 dsh loader 的加载路径)
if (Test-Path $entry) {
    $loadTest = & {
        Push-Location $ProfileDir
        try {
            $out = node -e "import('dsh-vision-router').then(m => { console.log(typeof m.apply) }).catch(e => { console.error(e.message); process.exit(1) })" 2>&1
            Pop-Location
            $out
        }
        catch {
            Pop-Location
            $_.Exception.Message
        }
    }
    $applyOk = ($loadTest -match '^function$')
    Check "模块加载预检(apply=function)" $applyOk "(输出: $loadTest)"
}
else {
    Check "模块加载预检(apply=function)" $false "(entry.js 缺失,跳过)"
}

# 汇总
Write-Host ""
if ($failCount -eq 0) {
    Write-Host "✅ 全部检查通过" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "❌ $failCount 项检查失败,请参考 docs/处理手册.md" -ForegroundColor Red
    exit 1
}
