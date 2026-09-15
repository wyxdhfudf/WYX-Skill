# 工具链检查清单

> 基于本地环境生成，不是网上抄的模板

## 必备工具（当前已验证）

### 逆向分析工具
| 工具 | 路径 | 版本 | 状态 |
|-----|------|------|------|
| jadx | `jadx --version` | 1.5.5 | ✓ |
| apktool | `apktool --version` | 3.0.2 | ✓ |
| adb | `adb version` | platform-tools | ✓ |
| frida | `frida-ps -V` | 17.9.6 | ✓ |

### 编译工具链
| 工具 | 路径 | 状态 |
|-----|------|------|
| Rust/Cargo | `D:\rust\.cargo\bin\cargo.exe` | ✓ |
| MinGW-w64 | `D:\mingw64\mingw64\bin\` | ✓ |
| gcc/g++ | `x86_64-w64-mingw32-gcc` | ✓ |

### 分析工具
| 工具 | 路径 | 状态 |
|-----|------|------|
| IDA Pro | 需确认 | ⚠ |
| Ghidra | 需安装 | ✗ |
| Cheat Engine | 需安装 | ✗ |
| Process Hacker | 系统自带 | ✓ |

## 快速验证命令

```powershell
# 验证逆向工具
jadx --version
apktool --version
adb devices
frida-ps -U

# 验证编译工具
$env:PATH = "D:\rust\.cargo\bin;D:\mingw64\mingw64\bin;$env:PATH"
cargo --version
x86_64-w64-mingw32-gcc --version
```

## 缺失工具（需手动安装）

| 工具 | 用途 | 安装方式 |
|-----|------|---------|
| Frida-server | Android动态注入 | `pip install frida-tools` + 下载对应版本frida-server |
| Ghidra | 开源逆向分析 | https://github.com/NationalSecurityAgency/ghidra/releases |
| Cheat Engine | 游戏内存扫描 | https://www.cheatengine.org/ |
| x64dbg | Windows调试器 | https://x64dbg.com/ |

## 环境变量配置

```powershell
# 添加到 %USERPROFILE%\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
$env:RUSTUP_HOME = "D:\rust\.rustup"
$env:CARGO_HOME = "D:\rust\.cargo"
$env:PATH = "D:\rust\.cargo\bin;D:\mingw64\mingw64\bin;$env:PATH"
```
