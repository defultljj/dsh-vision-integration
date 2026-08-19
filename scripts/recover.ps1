<#
.SYNOPSIS
  dsh-vision-integration — 插件崩溃恢复脚本:按 docs/处理手册.md 的三级流程执行。

.DESCRIPTION
  当 dsh-vision-router 导致 DSH 崩溃或无法启动时,按顺序执行:
    1. 杀掉全部 DeepSeek 残留进程(-Kill 开启)
    2. 运行插件自带 doctor 诊断
    3. 运行插件自带 repair 自动修复(仅修复 UTF-8 BOM)
    4. 调用 verify.ps1 验证配置与加载
  全程只读诊断默认开启;repair 与杀进程需要显式参数。

.PARAMETER Kill
  杀干净所有 DeepSeek.exe / node.exe 进程(谨慎:会终止所有相关进程)。
.PARAMETER Repair
  运行 npx dsh-vision-router repair(删除 package.json 开头的 UTF-8 BOM 字节)。
.PARAMETER DoctorOnly
  只运行 doctor 诊断,不做任何修改。

.EXAMPLE
  .\scripts\recover.ps1 -DoctorOnly
  .\scripts\recover.ps1 -Kill -Repair
#>
[CmdletBinding()]
param(
    [switch]$Kill,
    [switch]$Repair,
    [switch]$DoctorOnly
)

$ErrorActionPreference = 'Continue'
$profileDir = "$env:USERPROFILE\.dsh\profiles\web"

Write-Host "=== 崩溃恢复流程 ===" -ForegroundColor Cyan
Write-Host "Profile: $profileDir`n"

# 1. 杀进程(可选,默认不杀——需要显式 -Kill)
if ($Kill) {
    Write-Host "[STEP] 终止残留进程 ..." -ForegroundColor Cyan
    $procs = @(Get-Process -Name 'DeepSeek','node' -ErrorAction SilentlyContinue)
    if ($procs.Count -eq 0) {
        Write-Host "[OK] 未发现 DeepSeek/node 进程,无需清理" -ForegroundColor Green
    }
    else {
        Write-Host "[WARN] 将终止以下 $($procs.Count) 个进程:" -ForegroundColor Yellow
        $procs | ForEach-Object { Write-Host "  - $($_.ProcessName) (PID $($_.Id))" }
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Write-Host "[OK] 进程已清理" -ForegroundColor Green
    }
}
elseif (-not $DoctorOnly) {
    Write-Host "[INFO] 未加 -Kill,跳过杀进程(建议在重启前手动关闭 DSH)" -ForegroundColor Yellow
}

# 2. doctor 诊断(只读)
Write-Host "`n[STEP] 运行 doctor 诊断 ..." -ForegroundColor Cyan
npx --yes dsh-vision-router doctor --profile web 2>&1 | ForEach-Object { Write-Host $_ }

# 3. repair 修复(可选)
if ($Repair) {
    Write-Host "`n[STEP] 运行 repair 自动修复 ..." -ForegroundColor Cyan
    npx --yes dsh-vision-router repair --profile web 2>&1 | ForEach-Object { Write-Host $_ }
}
elseif (-not $DoctorOnly) {
    Write-Host "`n[INFO] 未加 -Repair,跳过自动修复(如有 BOM 报错可加 -Repair)" -ForegroundColor Yellow
}

# 4. 验证配置(子进程运行,避免 verify.ps1 的 exit 终止本脚本,保证结尾提示可见)
Write-Host "`n[STEP] 验证 profile 配置 ..." -ForegroundColor Cyan
$verify = Join-Path $PSScriptRoot 'verify.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $verify -ProfileDir $profileDir
$verifyExit = $LASTEXITCODE

Write-Host "`n=== 恢复流程结束 ===" -ForegroundColor Cyan
if ($verifyExit -ne 0) {
    Write-Host "验证未通过(退出码 $verifyExit),请参考 docs/处理手册.md 手动兜底方案(删除依赖+bundles 两处条目)。" -ForegroundColor Yellow
}
else {
    Write-Host "验证通过,可以重启 DSH 验证。" -ForegroundColor Green
}
exit $verifyExit
