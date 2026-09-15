---
name: WYX
description: |
  游戏外挂开发与APK破解的完整技能包。合并了游戏内存分析、DLL注入、反调试绕过、APK逆向、加密算法破解等同类功能，提供统一的工具链和工作流。
  触发关键词：APK逆向、APK破解、游戏外挂分析、加密算法提取、签名绕过、Frida Hook、SSL Pinning绕过、
  Root检测绕过、反调试绕过、so逆向、smali修改、重打包APK、IL2CPP、Unity逆向、Unreal移动版逆向、
  JNI分析、native hook、Xposed模块、Objection、JADX、apktool、smali patch、证书校验、风控绕过、
  游戏内存分析、自瞄、透视、无后座、ESP、DLL注入、进程操作、卡密破解、授权绕过。
  当用户想分析任何移动端目标（游戏或App）或开发游戏外挂时使用此skill，无需用户明确提及"逆向"二字。
---

# WYX — 游戏安全测试与APK破解技能包

> **WARNING**: 本skill仅用于授权的渗透测试、安全研究、CTF比赛和个人学习。未经授权使用他人软件进行破解、外挂开发属于违法行为。

## 快速路由

| 任务类型 | 路由到子模块 |
|---------|-------------|
| APK静态分析（Java/Smali层） | `workflows/apk-static.md` |
| APK动态Hook（Frida/Xposed） | `workflows/apk-dynamic.md` |
| Native .so分析 | Ghidra / radare2 逆向分析 |
| 游戏内存分析（自瞄/透视/无后座） | `workflows/game-memory.md` |
| DLL注入（Windows游戏） | `workflows/dll-inject.md` |
| 加密算法破解/卡密验证 | `workflows/crypto-crack.md` |
| 绕过检测（Root/SSL/反调试） | `references/bypass-cheatsheet.md` |
| Unity IL2CPP逆向 | `workflows/unity-reverse.md` |
| UE4逆向 | `workflows/ue4-reverse.md` |
| 生成分析报告 | `workflows/report-gen.md` |

## 核心优势（比网上那些垃圾强在哪）

1. **本地化配置** - 基于你的真实环境（D盘工具链、MinGW、Rust），不是瞎编的路径
2. **实战经验** - 融合了OW2外挂开发的真实踩坑记录（dpi问题、v8崩溃、字面量溢出）
3. **端到端流程** - 从目标分析到最终payload/注入器，一条流程走完
4. **自动化工具** - 自带脚本一键完成解密、注入、重打包等操作
5. **持续进化** - 每次任务完成后自动回写经验到field-journal
6. **模板库** - 内置绕过模板、Hook模板、C代码模板，开箱即用

## 前置检查清单

在开始任何操作前，MUST确认：

- [ ] 已读取 `references/tool-checklist.md` 确认本地工具可用性
- [ ] 已确认目标为授权测试对象（自己开发/CTF/授权渗透测试）
- [ ] 已创建case工作目录 `work/<target-name>/`
- [ ] 已备份原始样本（哈希校验）

## 工作流程总览

```
1. 目标识别 → 确定游戏/APK类型
2. 静态分析 → jadx/apktool反编译 or strings/scan分析
3. 动态分析 → Frida Hook or 调试器断点
4. 逻辑还原 → 定位验证逻辑/内存结构
5. 绕过实现 → 编写hook脚本/DLL/修改smali
6. 验证测试 → 功能验证+稳定性测试
7. 文档输出 → 生成分析报告
```

## 决策信号速查

| 信号 | 判断 | 下一步 |
|------|------|--------|
| APK含`.so`文件 | 核心逻辑在Native层 | 切 Ghidra / radare2 逆向分析 |
| Java层全是JNI wrapper | 同上 | 切Native分析 |
| 包名含`il2cpp`或资源有`Managed` | Unity游戏 | 用 `Il2CppDumper` |
| Java层可读且逻辑清晰 | 纯Java分析够用 | 直接Frida Hook |
| 发现签名验证逻辑 | 需要绕过签名 | 用 `bypass-cheatsheet.md` |
| 发现加密算法 | 需要破解 | 用 `crypto-crack.md` |

---

# 模块1: APK静态分析工作流

## Phase 0: 快速侦察（5分钟出结论）

```powershell
# 一键解密APK
pwsh -File "scripts/decode.ps1" -ApkPath "D:\target.apk"

# 查看Manifest关键信息
pwsh -File "scripts/manifest-summary.ps1" -ManifestPath "target_out/AndroidManifest.xml"

# 搜索关键逻辑
jadx -d "jadx_out" "target.apk" --search "license|auth|key|verify|sign|encrypt|decrypt"
```

## Phase 1: 深度静态分析

### 1a. Java层分析

```powershell
# 完整导出
jadx -d jadx_out target.apk

# 只看关键类
jadx --single-class com.target.LoginActivity -d jadx_out target.apk

# 混淆代码也试试
jadx --deobf -d jadx_out_deobf target.apk
```

重点分析：
- `Application` 子类的 `onCreate()`
- 登录/注册相关 Activity
- 网络请求（OkHttp/Retrofit/WebView）
- 加密类（Cipher/MessageDigest/Hmac）
- 安全检测类（含 `root`、`debug`、`emulator`、`frida` 关键字）

### 1b. Smali层分析

当jadx反编译不完整或需要改代码时：

```powershell
apktool d target.apk -o apktool_out
# 修改 smali 文件
# 示例：绕过 root 检测，找对应的 smali 改成 return true/false
```

### 1c. Manifest关键信息

```powershell
# 快速看包名、权限、导出组件
$manifest = Get-Content "apktool_out/AndroidManifest.xml" -Raw
# 权限
Select-String $manifest "uses-permission" | ForEach-Object { $_.Line }
# 导出组件
Select-String $manifest "android:exported" | ForEach-Object { $_.Line }
```

---

# 模块2: APK动态Hook工作流

## Phase 2: Frida动态Hook

### 2a. 设备连接

```powershell
# 列表设备
frida-ps -U

# 或者 USB
adb devices
```

### 2b. 通用Hook模板

```javascript
// hook.js — 通用模板，按需修改
Java.perform(function() {
    console.log("[*] Frida script loaded");

    // === 加密 Hook ===
    var Cipher = Java.use("javax.crypto.Cipher");
    Cipher.doFinal.overload('[B').implementation = function(input) {
        console.log("[Cipher] input=" + bytesToHex(input));
        var result = this.doFinal(input);
        console.log("[Cipher] output=" + bytesToHex(result));
        return result;
    };

    // === 网络 Hook (OkHttp) ===
    var RealCall = Java.use("okhttp3.RealCall");
    RealCall.execute.implementation = function() {
        var req = this.request();
        console.log("[OkHttp] " + req.method() + " " + req.url());
        return this.execute();
    };
});

function bytesToHex(bytes) {
    var hex = [];
    for (var i = 0; i < bytes.length; i++) {
        hex.push(('0' + (bytes[i] & 0xFF).toString(16)).slice(-2));
    }
    return hex.join('');
}
```

### 2c. 注入方式

```powershell
# 方式1: Spawn 启动（推荐，进程可控）
frida -U -f com.game.target -l hook.js --no-pause

# 方式2: Attach 到已运行进程
frida -U com.game.target -l hook.js

# 方式3: 使用一键脚本
pwsh -File "scripts/frida-run.ps1" -Usb -Spawn -Package com.game.target -ScriptPath "D:\hook.js"
```

---

# 模块3: 绕过检测工作流

## Phase 3: 一键绕过套件

详见 `references/bypass-cheatsheet.md`

核心模板已内置：

```javascript
// bypass.js — Root + SSL Pinning + 反调试 全套绕过
Java.perform(function() {
    console.log("[*] Bypass kit loaded");

    // === Root 检测绕过 ===
    // File.exists() 拦截
    // Runtime.exec() 拦截
    // PackageManager 隐藏敏感包
    // Build.TAGS 伪造

    // === SSL Pinning 绕过 ===
    // OkHttp3 CertificatePinner
    // TrustManagerImpl
    // X509TrustManager

    // === 反调试绕过 ===
    // Debug.isDebuggerConnected
    // System.checkJni
    // ptrace TracerPid
});
```

---

# 模块4: Native层分析工作流

## Phase 4: .so分析

当Java层发现 `System.loadLibrary()` 调用核心逻辑时：

### 4a. 快速侦察

```bash
# 列出所有 so
apktool d target.apk -o out
Get-ChildItem out -Recurse -Filter "*.so" | Select-Object FullName,Length

# radare2 快速分析
r2 -aa libtarget.so
iz ~ signature
iz ~ Java_
isz
```

### 4b. 深度分析 → Ghidra（免费）/ radare2（免费）

```powershell
# 方案1: Ghidra（推荐，免费开源）
# GUI模式：ghidraRun.bat libtarget.so
# CLI模式（无界面服务器）：
ghidraRun -process libtarget.so -scriptPath analyze.gs -postScript "PrintFunctions.java"

# 方案2: radare2（命令行，轻量）
r2 -aa libtarget.so      # 自动分析
iz                       # 查看所有字符串
isz                      # 查看导入/导出函数
aaa                      # 重新分析所有函数
pdf @ main             # 反汇编main函数
```

**选择建议**：
- 需要图形界面 → Ghidra
- 快速命令行分析 → radare2
- 生产环境自动化 → Ghidra CLI 模式

### 4c. Native Hook模板

详见 `references/native-hook-cheatsheet.md`

核心模板：

```javascript
// native_hook.js
// Hook导出函数
var func = Module.findExportByName("libtarget.so", "Java_com_target_Game_nativMethod");
if (func) {
    Interceptor.attach(func, {
        onEnter: function(args) {
            console.log("args[0]=" + args[0]);
        },
        onLeave: function(ret) {
            console.log("ret=" + ret);
        }
    });
}

// Hook内部函数（pattern扫描）
var mod = Module.findModuleByName("libtarget.so");
var pattern = "48 89 5C 24 ? 48 89 74 24 ? 57";
var results = mod.scanSync(pattern);
results.forEach(function(addr) {
    Interceptor.attach(addr.address, {
        onEnter: function(args) { console.log("Called at: " + addr.address); }
    });
});
```

---

# 模块5: 游戏内存分析工作流

## Phase 5: Unity/UE4游戏逆向

### 5a. Unity IL2CPP分析

```bash
# 1. dump 游戏内存找 Il2Cpp 基址
# 2. 运行 Il2CppDumper
python Il2CppDumper.py global-metadata.dat il2cpp_dll_output

# 3. 用 IDA 加载生成的 shim + metadata
# 4. 获得完整类/方法/字段偏移
```

### 5b. UE4分析

```bash
# 使用 UE4SS
# 1. 注入 UE4SS DLL
# 2. dump UObject
# 3. 生成SDK
```

### 5c. 内存读取模板（Rust）

参考示例项目（替换为你的实际路径）

关键经验：
```rust
// DPI问题
unsafe {
    SetThreadDpiAwarenessContext(-3); // PER_MONITOR_AWARE_V2
}

// 避免v8崩溃
// grab_screen_v2 中不要重复调用 GetDIBits

// 字面量溢出
let val = 0x8000u16 as i16;

// static mut替代
use std::cell::UnsafeCell;
```

---

# 模块6: DLL注入工作流

## Phase 6: Windows游戏注入

### 6a. 编译DLL

```powershell
# 一键编译
pwsh -File "scripts/build-dll.ps1" -ProjectDir "<your-rust-project>" -Release

# 或手动编译
$env:RUSTUP_HOME = "D:\rust\.rustup"
$env:CARGO_HOME = "D:\rust\.cargo"
$env:PATH = "D:\rust\.cargo\bin;D:\mingw64\mingw64\bin;$env:PATH"
cargo build --release --target x86_64-pc-windows-gnu
```

### 6b. 注入方法

1. **Process Hacker**: 右键进程 → Plugins → Inject DLL
2. **Cheat Engine**: 工具 → DLL注入器
3. **手动**: CreateRemoteThread + LoadLibrary

```cpp
// 手动注入模板
BOOL InjectDLL(DWORD pid, LPCWSTR dllPath) {
    HANDLE hProcess = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid);
    if (!hProcess) return FALSE;

    LPVOID pRemoteBuffer = VirtualAllocEx(hProcess, NULL, lstrlen(dllPath) + 1,
        MEM_COMMIT, PAGE_READWRITE);
    WriteProcessMemory(hProcess, pRemoteBuffer, dllPath, lstrlen(dllPath) + 1, NULL);

    HANDLE hThread = CreateRemoteThread(hProcess, NULL, 0,
        (LPTHREAD_START_ROUTINE)LoadLibraryW, pRemoteBuffer, 0, NULL);
    WaitForSingleObject(hThread, INFINITE);

    CloseHandle(hThread);
    CloseHandle(hProcess);
    return TRUE;
}
```

---

# 模块7: 加密算法破解工作流

## Phase 7: 卡密/签名验证破解

### 7a. 字符串搜索

```powershell
# 搜索加密相关字符串
jadx -d jadx_out target.apk
Get-ChildItem jadx_out -Recurse -Include "*.java" | Select-String -Pattern "AES|RSA|MD5|SHA|encrypt|decrypt|cipher|key|hash" -List
```

### 7b. Frida Hook加密函数

```javascript
// crypto_hook.js
Java.perform(function() {
    // Hook AES加密
    var Cipher = Java.use("javax.crypto.Cipher");
    Cipher.doFinal.overload('[B').implementation = function(input) {
        console.log("[AES] input=" + bytesToHex(input));
        var result = this.doFinal(input);
        console.log("[AES] output=" + bytesToHex(result));
        return result;
    };

    // Hook MD5
    var MessageDigest = Java.use("java.security.MessageDigest");
    MessageDigest.update.overload('[B').implementation = function(input) {
        console.log("[MD5] input=" + bytesToHex(input));
        this.update(input);
    };
});
```

### 7c. OLLVM混淆处理

```markdown
识别特征：
- 控制流平坦化：大量switch-case，单入口单出口
- 虚假控制流：添加了无意义的判断分支
- MBA混淆：混合布尔算术表达式

处理方法：
1. 使用 Ghidra 插件（免费开源）
2. 使用 ollvm-unflattener（Miasm）
3. 符号执行（angr）
```

---

# 模块8: 重打包安装工作流

## Phase 8: Smali修改与重打包

### 8a. 常用Patch场景

| 场景 | Smali 改法 |
|------|-----------|
| 绕过登录验证 | 找 `if-eqz v0, :cond_x` 改成 `if-nez v0, :cond_x` |
| 禁用Root检测 | Hook `File.exists()` 或修改检测类返回 false |
| 绕过签名校验 | Hook `PackageManager.verifySignatures()` |
| 解锁付费功能 | 找付费检查点，改成 `const/4 v0, 0x1` (true) |
| 修改游戏数值 | 找HP/攻击/金币变量地址，Frida hook改写 |

### 8b. 一键重打包

```powershell
# 重建+签名+安装
pwsh -File "scripts/rebuild-sign-install.ps1" -ProjectDir "apktool_out" -Install -Reinstall
```

---

# 脚本手册

## `scripts/decode.ps1`

```powershell
# 完整解包（jadx + apktool）
pwsh -File "scripts/decode.ps1" -ApkPath "D:\app.apk"

# 只跑apktool（跳过jadx）
pwsh -File "scripts/decode.ps1" -ApkPath "D:\app.apk" -SkipJadx

# 指定输出目录
pwsh -File "scripts/decode.ps1" -ApkPath "D:\app.apk" -OutRoot "D:\analysis"
```

## `scripts/frida-run.ps1`

```powershell
# 列出设备
pwsh -File "scripts/frida-run.ps1" -ListDevices

# 列出进程
pwsh -File "scripts/frida-run.ps1" -Usb -ListProcesses

# Spawn + 注入脚本
pwsh -File "scripts/frida-run.ps1" -Usb -Spawn -Package com.game.target -ScriptPath "D:\hook.js"

# Attach到运行中进程
pwsh -File "scripts/frida-run.ps1" -Usb -Process com.game.target -ScriptPath "D:\hook.js"
```

## `scripts/build-dll.ps1`

```powershell
# Debug编译
pwsh -File "scripts/build-dll.ps1" -ProjectDir "<your-rust-project>"

# Release编译
pwsh -File "scripts/build-dll.ps1" -ProjectDir "<your-rust-project>" -Release
```

## `scripts/search-logic.ps1`

```powershell
# 搜索关键逻辑
pwsh -File "scripts/search-logic.ps1" -SourceDir "jadx_out" -Keywords @("license","auth","key","verify","sign")

# 自定义关键词
pwsh -File "scripts/search-logic.ps1" -SourceDir "jadx_out" -Keywords @("encrypt","decrypt","crypto")
```

---

# 输出要求

最终至少说明：
- 入口组件与关键类
- 核心逻辑位置（Java / smali / .so / IL2CPP）
- 已定位的敏感点：登录、签名、加密、风控、检测
- 做了什么 Patch 或 Hook
- 如果重打包，输出路径和安装状态

---

## 路由上下文

**上游入口**: 本 skill 独立触发

**下游出口**:
- Native .so 深度分析 → Ghidra / radare2 逆向工具
- Unity IL2CPP 专项 → Il2CppDumper + Ghidra
- EDR绕过 → syscall unhook / hypervisor 隐藏

**同级关联**:
- 通用逆向方法论 → 参考 references/ 下的模板库

## 任务完成自检

声称完成前MUST通过：

- [ ] 是否执行了完整分析工作流（不只是看了Manifest）？
- [ ] 是否定位了核心逻辑所在的层（Java/Smali/Native）？
- [ ] 是否产出了可复现证据（命令/脚本/截图）？
- [ ] 如果做了Hook，是否记录了Hook的目标类和函数？
- [ ] 如果做了Patch，是否记录了修改内容和重打包结果？
- [ ] 是否融合了你的实战经验（DPI、v8崩溃等）？
- [ ] 是否使用了本地化路径（非假设路径）？
