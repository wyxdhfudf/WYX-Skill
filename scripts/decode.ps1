# Decode — 全盘解包
param(
    [Parameter(Mandatory=$true)][string]$ApkPath,
    [string]$OutRoot,
    [switch]$SkipJadx,
    [switch]$SkipApktool,
    [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

Write-Host "[*] WYX Decode Script v2.0" -ForegroundColor Cyan
Write-Host "[*] Target: $ApkPath" -ForegroundColor Yellow

# 检查工具
$jadx = Get-Command jadx -EA SilentlyContinue
$apktool = Get-Command apktool -EA SilentlyContinue

if (-not $jadx) { Write-Host "[!] jadx not found, skipping Java decompilation" -ForegroundColor Red; $SkipJadx=$true }
if (-not $apktool) { Write-Host "[!] apktool not found, skipping APK unpacking" -ForegroundColor Red; $SkipApktool=$true }

if ($SkipJadx -and $SkipApktool) {
    Write-Host "[!] No tools available, aborting" -ForegroundColor Red
    exit 1
}

# 准备输出目录
$name = [System.IO.Path]::GetFileNameWithoutExtension($ApkPath)
$root = if ($OutRoot) { $OutRoot } else { Split-Path $ApkPath }
$out = Join-Path $root $name

if ($Clean -and (Test-Path $out)) {
    Write-Host "[*] Cleaning previous output: $out" -ForegroundColor Yellow
    Remove-Item $out -Recurse -Force
}

New-Item -ItemType Directory -Path $out -Force | Out-Null

# JADX反编译
if (-not $SkipJadx) {
    Write-Host "`n[*] Running jadx..." -ForegroundColor Cyan
    $jadxOut = Join-Path $out "jadx"
    try {
        & jadx -d $jadxOut $ApkPath 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[+] JADX success: $jadxOut" -ForegroundColor Green
        } else {
            Write-Host "[!] JADX partial failure (may still have useful output)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[!] JADX error: $_" -ForegroundColor Red
    }
}

# APKTool解包
if (-not $SkipApktool) {
    Write-Host "`n[*] Running apktool..." -ForegroundColor Cyan
    $apkOut = Join-Path $out "apktool"
    try {
        & apktool d $ApkPath -o $apkOut -f 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[+] APKTool success: $apkOut" -ForegroundColor Green

            # 提取关键信息
            $manifestPath = Join-Path $apkOut "AndroidManifest.xml"
            if (Test-Path $manifestPath) {
                Write-Host "`n[*] Manifest Analysis:" -ForegroundColor Cyan
                $pkg = [xml](Get-Content $manifestPath -Raw -EA SilentlyContinue)
                if ($pkg.manifest.package) {
                    Write-Host "  Package: $($pkg.manifest.package)" -ForegroundColor White
                }

                # 统计so文件
                $soCount = (Get-ChildItem $apkOut -Recurse -Filter "*.so" -EA SilentlyContinue).Count
                Write-Host "  SO files: $soCount" -ForegroundColor White

                if ($soCount -gt 0) {
                    Write-Host "  [!] Native library detected - consider Ghidra for deep analysis" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "[!] APKTool failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "[!] APKTool error: $_" -ForegroundColor Red
    }
}

# 输出摘要
Write-Host "`n[+] Decode complete!" -ForegroundColor Green
Write-Host "    Output: $out" -ForegroundColor White
if (-not $SkipJadx) { Write-Host "    JADX:   $out\jadx" -ForegroundColor White }
if (-not $SkipApktool) { Write-Host "    APKTool: $out\apktool" -ForegroundColor White }
