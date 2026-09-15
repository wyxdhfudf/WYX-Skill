# Rust DLL编译脚本
param(
    [string]$ProjectDir = "D:\shua-ke\ow_rust",
    [switch]$Release,
    [switch]$Watch
)

Write-Host "[*] WYX DLL Builder v2.0" -ForegroundColor Cyan
Write-Host "[*] Project: $ProjectDir" -ForegroundColor Yellow

# 设置环境变量（基于你的真实环境）
$env:RUSTUP_HOME = "D:\rust\.rustup"
$env:CARGO_HOME = "D:\rust\.cargo"
$env:PATH = "D:\rust\.cargo\bin;D:\mingw64\mingw64\bin;$env:PATH"

# 验证工具
$cargo = Get-Command cargo -EA SilentlyContinue
$gcc = Get-Command x86_64-w64-mingw32-gcc -EA SilentlyContinue

if (-not $cargo) {
    Write-Host "[!] Cargo not found. Check RUSTUP_HOME and CARGO_HOME." -ForegroundColor Red
    exit 1
}
if (-not $gcc) {
    Write-Host "[!] MinGW gcc not found. Check PATH or dlltool symlink." -ForegroundColor Red
    Write-Host "    Solution: New-Item -Path 'D:\mingw64\mingw64\bin\x86_64-w64-mingw32-dlltool.exe' -ItemType SymbolicLink -Target 'dlltool.exe' -Force" -ForegroundColor Yellow
    exit 1
}

Push-Location $ProjectDir

$buildFlags = @("--target", "x86_64-pc-windows-gnu")
if ($Release) {
    $buildFlags += @("--release")
    Write-Host "[*] Release build" -ForegroundColor Yellow
} else {
    Write-Host "[*] Debug build" -ForegroundColor Yellow
}

Write-Host "`n[*] Compiling..." -ForegroundColor Cyan
Write-Host "    cargo build $($buildFlags -join ' ')" -ForegroundColor Gray

cargo build @buildFlags

if ($LASTEXITCODE -eq 0) {
    $outDir = if ($Release) { "target\x86_64-pc-windows-gnu\release" } else { "target\x86_64-pc-windows-gnu\debug" }
    $dllPath = Join-Path $outDir (Split-Path $ProjectDir -Leaf)

    Write-Host "`n[+] Build successful!" -ForegroundColor Green
    Write-Host "[+] DLL location: $dllPath.dll" -ForegroundColor White

    # 列出所有DLL
    $dlls = Get-ChildItem $outDir -Filter "*.dll" -ErrorAction SilentlyContinue
    foreach ($dll in $dlls) {
        Write-Host "  -> $($dll.FullName) ($($dll.Length) bytes)" -ForegroundColor Cyan
    }

    # 注入提示
    Write-Host "`n[*] Injection methods:" -ForegroundColor Cyan
    Write-Host "  1. Process Hacker: Right-click process -> Plugins -> Inject DLL" -ForegroundColor White
    Write-Host "  2. Cheat Engine: Tools -> DLL Injector" -ForegroundColor White
    Write-Host "  3. Manual: CreateRemoteThread + LoadLibrary" -ForegroundColor White
} else {
    Write-Host "`n[!] Build failed" -ForegroundColor Red
    Write-Host "    Common issues:" -ForegroundColor Yellow
    Write-Host "    - dlltool missing: Create symlink x86_64-w64-mingw32-dlltool.exe -> dlltool.exe" -ForegroundColor White
    Write-Host "    - 0x8000i16 overflow: Use 0x8000u16 as i16" -ForegroundColor White
    Write-Host "    - static mut: Use UnsafeCell instead" -ForegroundColor White
}

Pop-Location

if ($Watch) {
    Write-Host "`n[*] Watch mode enabled. Press Ctrl+C to stop." -ForegroundColor Yellow
    while ($true) {
        Start-Sleep -Seconds 2
        $modified = Get-ChildItem $ProjectDir -Recurse -Include "*.rs" | Where-Object { $_.LastWriteTime -gt $lastCheck }
        if ($modified) {
            Write-Host "`n[*] Changes detected, rebuilding..." -ForegroundColor Cyan
            & $PWD\scripts\build-dll.ps1 -ProjectDir $ProjectDir -Release:$Release
        }
        $lastCheck = Get-Date
    }
}
