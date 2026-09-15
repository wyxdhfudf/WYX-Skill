# Frida注入 — 统一入口
param(
    [string]$Package,
    [string]$Process,
    [string]$RemoteHost = '127.0.0.1:27042',
    [string]$ScriptPath,
    [switch]$Usb,
    [switch]$Spawn,
    [switch]$Attach,
    [switch]$ListDevices,
    [switch]$ListProcesses,
    [switch]$Trace
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

Write-Host "[*] WYX Frida Injector v2.0" -ForegroundColor Cyan

# 检查frida
$fridaPs = Get-Command frida-ps -EA SilentlyContinue
$frida = Get-Command frida -EA SilentlyContinue

if (-not $frida) {
    Write-Host "[!] Frida not found. Install: pip install frida frida-tools" -ForegroundColor Red
    exit 1
}

# 列出设备
if ($ListDevices) {
    Write-Host "`n[*] Available Devices:" -ForegroundColor Cyan
    frida-ls-devices
    exit 0
}

# 列出进程
if ($ListProcesses) {
    Write-Host "`n[*] Running Processes:" -ForegroundColor Cyan
    $flags = @("-U")
    if ($RemoteHost -ne '127.0.0.1:27042') { $flags = @("-H", $RemoteHost) }
    & frida-ps @flags
    exit 0
}

# 验证脚本路径
if (-not $ScriptPath) {
    Write-Host "[!] ScriptPath is required" -ForegroundColor Red
    Write-Host "    Usage: -ScriptPath ""D:\hooks\hook.js""" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $ScriptPath)) {
    Write-Host "[!] Script not found: $ScriptPath" -ForegroundColor Red
    exit 1
}

# 验证目标
if (-not $Package -and -not $Process) {
    Write-Host "[!] Provide -Package or -Process" -ForegroundColor Red
    Write-Host "    Example: -Package com.game.target" -ForegroundColor Yellow
    exit 1
}

# 构建参数
$target = $Package ?? $Process
$dev = if ($Usb) { '-U' } else { '-H', $RemoteHost }

Write-Host "`n[*] Target: $target" -ForegroundColor Yellow
Write-Host "[*] Script: $ScriptPath" -ForegroundColor Yellow
Write-Host "[*] Mode: $(if($Spawn){'Spawn'}else{'Attach'})" -ForegroundColor Yellow

# Spawn模式
if ($Spawn) {
    Write-Host "`n[*] Spawning process: $target" -ForegroundColor Cyan
    & $frida $dev @('-f', $target, '-l', $ScriptPath, '--no-pause')
}
# Attach模式
elseif ($Attach) {
    Write-Host "`n[*] Attaching to process: $target" -ForegroundColor Cyan
    & $frida $dev @('-n', $target, '-l', $ScriptPath)
}
# Trace模式
elseif ($Trace) {
    Write-Host "`n[*] Tracing: $target" -ForegroundColor Cyan
    & $frida $dev @('-f', $target, '-l', $ScriptPath, '-j', '*!*', '--no-pause')
}
# 默认Attach
else {
    Write-Host "`n[*] Attaching to process: $target" -ForegroundColor Cyan
    & $frida $dev @('-n', $target, '-l', $ScriptPath)
}

Write-Host "`n[+] Frida session ended" -ForegroundColor Green
