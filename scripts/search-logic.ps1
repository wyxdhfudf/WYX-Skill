# APK逻辑搜索脚本
param(
    [string]$SourceDir,
    [string[]]$Keywords = @("license", "auth", "key", "verify", "sign", "encrypt", "decrypt", "check", "valid", "login", "password", "token")
)

Write-Host "[*] WYX Logic Search v2.0" -ForegroundColor Cyan
Write-Host "[*] Source: $SourceDir" -ForegroundColor Yellow
Write-Host "[*] Keywords: $($Keywords -join ', ')" -ForegroundColor Yellow

if (-not (Test-Path $SourceDir)) {
    Write-Host "[!] Source directory not found: $SourceDir" -ForegroundColor Red
    exit 1
}

$results = @()
$totalFiles = 0

foreach ($keyword in $Keywords) {
    Write-Host "`n[*] Searching: $keyword" -ForegroundColor Cyan

    # 搜索Java/Kotlin文件
    $javaFiles = Get-ChildItem $SourceDir -Recurse -Include "*.java","*.kt" -ErrorAction SilentlyContinue
    $totalFiles += $javaFiles.Count

    foreach ($file in $javaFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if ($content -match "(?i)$keyword") {
            $lines = $content -split "`n"
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match "(?i)$keyword") {
                    $results += [PSCustomObject]@{
                        File = $file.FullName.Replace($SourceDir, "")
                        Line = $i + 1
                        Content = $lines[$i].Trim().Substring(0, [Math]::Min(100, $lines[$i].Trim().Length))
                        Keyword = $keyword
                    }
                }
            }
        }
    }

    # 搜索smali文件
    $smaliFiles = Get-ChildItem $SourceDir -Recurse -Include "*.smali" -ErrorAction SilentlyContinue
    $totalFiles += $smaliFiles.Count

    foreach ($file in $smaliFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if ($content -match "(?i)$keyword") {
            $results += [PSCustomObject]@{
                File = $file.FullName.Replace($SourceDir, "")
                Line = "N/A"
                Content = "Contains keyword: $keyword"
                Keyword = $keyword
            }
        }
    }
}

# 输出结果
Write-Host "`n[*] Scanned $totalFiles files" -ForegroundColor Cyan
Write-Host "[*] Found $($results.Count) matches" -ForegroundColor Yellow

if ($results.Count -gt 0) {
    Write-Host "`n[+] Results (first 50):" -ForegroundColor Green
    $results | Select-Object -First 50 | Format-Table -AutoSize

    if ($results.Count -gt 50) {
        Write-Host "... and $($results.Count - 50) more results" -ForegroundColor Yellow
    }
} else {
    Write-Host "[!] No matches found" -ForegroundColor Red
}

# 保存详细报告
$reportPath = Join-Path $SourceDir "..\search_report.md"
$report = @"
# WYX Search Report

**Source**: $SourceDir
**Keywords**: $($Keywords -join ', ')
**Total Files**: $totalFiles
**Matches**: $($results.Count)

## Results

"@

foreach ($r in $results) {
    $report += "`n### $($r.Keyword)`n"
    $report += "- **File**: $($r.File)`n"
    $report += "- **Line**: $($r.Line)`n"
    $report += "- **Content**: `$($r.Content)`n"
}

$report | Out-File $reportPath -Encoding utf8
Write-Host "`n[+] Report saved: $reportPath" -ForegroundColor Green
