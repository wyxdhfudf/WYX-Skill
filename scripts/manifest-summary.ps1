# Manifest摘要脚本
param(
    [string]$ManifestPath
)

Write-Host "[*] WYX Manifest Analyzer v2.0" -ForegroundColor Cyan
Write-Host "[*] Manifest: $ManifestPath" -ForegroundColor Yellow

if (-not (Test-Path $ManifestPath)) {
    Write-Host "[!] Manifest not found: $ManifestPath" -ForegroundColor Red
    exit 1
}

$manifest = Get-Content $ManifestPath -Raw
$xml = [xml]$manifest

Write-Host "`n[*] Basic Info:" -ForegroundColor Cyan
Write-Host "  Package: $($xml.manifest.package)" -ForegroundColor White
Write-Host "  Version: $($xml.manifest.versionName) ($($xml.manifest.versionCode))" -ForegroundColor White

Write-Host "`n[*] Permissions:" -ForegroundColor Cyan
$permissions = $xml.manifest.children | Where-Object { $_ -match "uses-permission" }
if ($permissions) {
    $permissions | ForEach-Object {
        if ($_ -match 'name="([^"]+)"') {
            Write-Host "  - $($Matches[1])" -ForegroundColor White
        }
    }
} else {
    Write-Host "  (none)" -ForegroundColor Gray
}

Write-Host "`n[*] Components:" -ForegroundColor Cyan
$activities = Select-String $manifest "activity" -AllMatches | Select-Object -First 10
$services = Select-String $manifest "service" -AllMatches | Select-Object -First 5
$receivers = Select-String $manifest "receiver" -AllMatches | Select-Object -First 5

Write-Host "  Activities: $($activities.Count)" -ForegroundColor White
Write-Host "  Services: $($services.Count)" -ForegroundColor White
Write-Host "  Receivers: $($receivers.Count)" -ForegroundColor White

Write-Host "`n[*] Exported Components:" -ForegroundColor Cyan
$exported = Select-String $manifest "android:exported=""true""" -AllMatches
if ($exported) {
    $exported | ForEach-Object {
        Write-Host "  - $($_.Line.Trim())" -ForegroundColor Yellow
    }
} else {
    Write-Host "  (none exported)" -ForegroundColor Gray
}

Write-Host "`n[*] Application Label:" -ForegroundColor Cyan
if ($manifest -match 'android:label="([^"]+)"') {
    Write-Host "  $($Matches[1])" -ForegroundColor White
}

Write-Host "`n[+] Analysis complete" -ForegroundColor Green
