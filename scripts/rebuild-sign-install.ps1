# Rebuild + Sign + Install APK
param(
    [Parameter(Mandatory=$true)][string]$ProjectDir,
    [switch]$Install,
    [switch]$Reinstall,
    [string]$DeviceSerial,
    [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

Write-Host "[*] WYX APK Rebuilder v2.0" -ForegroundColor Cyan
Write-Host "[*] Project: $ProjectDir" -ForegroundColor Yellow

# 检查工具
$apktool = Get-Command apktool -EA SilentlyContinue
$adb = Get-Command adb -EA SilentlyContinue

if (-not $apktool) { throw "[!] apktool not found" }
if (-not $adb) { throw "[!] adb not found" }

# 验证目录
if (-not (Test-Path $ProjectDir)) {
    throw "[!] Project directory not found: $ProjectDir"
}

# 生成签名密钥（如果不存在）
$keystore = Join-Path $env:USERPROFILE '.android\debug.keystore'
if (-not (Test-Path $keystore)) {
    Write-Host "`n[*] Generating debug keystore..." -ForegroundColor Cyan
    $keytool = Get-Command keytool -EA SilentlyContinue
    if (-not $keytool) {
        throw "[!] keytool not found. Install Android SDK Build-Tools."
    }
    New-Item -ItemType Directory -Path (Split-Path $keystore) -Force | Out-Null
    & $keytool -genkeypair -v -keystore $keystore -storepass android -keypass android `
        -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 `
        -dname 'CN=Debug,O=WYX,CN=Reverse' 2>$null
    Write-Host "[+] Keystore created: $keystore" -ForegroundColor Green
}

# 构建APK
$name = Split-Path $ProjectDir -Leaf
$outDir = Split-Path $ProjectDir
$signed = Join-Path $outDir "$name-signed.apk"

Write-Host "`n[*] Building APK..." -ForegroundColor Cyan
& apktool b $ProjectDir -o $signed 2>$null
if ($LASTEXITCODE -ne 0) { throw "[!] apktool build failed" }
Write-Host "[+] Build success: $signed" -ForegroundColor Green

# 签名APK
Write-Host "`n[*] Signing APK..." -ForegroundColor Cyan
$apksigner = Get-Command apksigner -EA SilentlyContinue
if ($apksigner) {
    & $apksigner sign --ks $keystore --ks-key-alias androiddebugkey `
        --ks-pass pass:android --key-pass pass:android --out $signed $signed 2>$null
    if ($LASTEXITCODE -ne 0) { throw "[!] apksigner failed" }
} else {
    $jarsigner = Get-Command jarsigner -EA SilentlyContinue
    if ($jarsigner) {
        & $jarsigner -keystore $keystore -storepass android -keypass android `
            $signed androiddebugkey 2>$null
        if ($LASTEXITCODE -ne 0) { throw "[!] jarsigner failed" }
    } else {
        throw "[!] Neither apksigner nor jarsigner found"
    }
}
Write-Host "[+] Sign success: $signed" -ForegroundColor Green

# 安装APK
if ($Install) {
    Write-Host "`n[*] Installing APK..." -ForegroundColor Cyan
    $args = @('install')
    if ($Reinstall) { $args += '-r' }
    if ($DeviceSerial) { $args += '-s'; $args += $DeviceSerial }
    $args += $signed
    & $adb @args
    if ($LASTEXITCODE -ne 0) { throw "[!] adb install failed" }
    Write-Host "[+] Install success!" -ForegroundColor Green
}

Write-Host "`n[+] Complete!" -ForegroundColor Green
Write-Host "    Signed APK: $signed" -ForegroundColor White
if ($Install) { Write-Host "    Installed to device" -ForegroundColor White }
