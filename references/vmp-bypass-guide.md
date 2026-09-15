# VMP（VMProtect）应对指南

> VMP是目前最强的二进制保护之一，静态脱壳几乎不可能，但动态绕过很容易

---

## 一、VMP识别特征

### 1.1 静态识别

```powershell
# 方法1: 查看section名称
# VMP常用section名：
# - .vmp0, .vmp1（虚拟机代码段）
# - .UPX0, .UPX1（UPX壳，容易被脱）
# - .text（正常代码段）

# 用radare2查看
r2 -aa target.so
iz ~ vmp
isz

# 方法2: 查看entropy（熵值）
# VMP保护的代码段熵值很高（接近1.0）
# 正常代码熵值约0.6-0.8

# 方法3: 查找VMP特征字符串
strings target.so | Select-String "VMProtect|vmp|virtual"
```

### 1.2 运行时识别

```javascript
// 用Frida检测VMP
var vmpModule = Module.findBaseAddress("libtarget.so");
if (vmpModule) {
    var vmpSection = vmpModule.findSectionByName(".vmp0");
    if (vmpSection) {
        console.log("[!] VMProtect detected!");
        console.log("    VM code section: " + vmpSection.name);
        console.log("    VM code range: " + vmpSection.base + " - " + (vmpSection.base + vmpSection.size));
    }
}
```

---

## 二、VMP应对策略

### 策略1: 动态Hook（推荐⭐⭐⭐⭐⭐）

**核心思想：不脱壳，直接在解密后的代码处Hook**

```javascript
// bypass_vmp.js
Java.perform(function() {
    console.log("[*] VMP Bypass Script Loaded");

    // 方法1: Hook Java层（VMP通常只保护Native层）
    var TargetClass = Java.use("com.example.TargetClass");
    
    // 如果目标是native方法
    TargetClass.nativeVerify.implementation = function(input) {
        console.log("[*] nativeVerify called with: " + input);
        
        // 直接返回true绕过验证
        return true;
    };

    // 方法2: Hook Native导出函数
    var lib = Process.findModuleByName("libtarget.so");
    if (lib) {
        var verifyFunc = lib.findExportByName("Java_com_example_TargetClass_nativeVerify");
        if (verifyFunc) {
            Interceptor.attach(verifyFunc, {
                onEnter: function(args) {
                    console.log("[*] Native verify called");
                    this.input = args[1].readUtf8String();
                },
                onLeave: function(retval) {
                    console.log("[*] Verify result: " + retval.toInt32());
                    // 强行返回true
                    retval.replace(1);
                }
            });
        }
    }

    console.log("[*] VMP bypass injected successfully");
});
```

**执行：**
```powershell
pwsh -File "scripts/frida-run.ps1" -Usb -Spawn -Package com.example.app -ScriptPath "bypass_vmp.js"
```

---

### 策略2: Trace分析（不关心内部实现）

**核心思想：记录输入输出，推断逻辑**

```javascript
// trace_vmp.js
var tracedFunctions = [
    "Java_com_example_TargetClass_nativeVerify",
    "Java_com_example_TargetClass_encrypt",
    "Java_com_example_TargetClass_sign"
];

Java.perform(function() {
    var lib = Process.findModuleByName("libtarget.so");
    
    tracedFunctions.forEach(function(exportName) {
        var func = lib.findExportByName(exportName);
        if (func) {
            Interceptor.attach(func, {
                onEnter: function(args) {
                    console.log("\n[+] Called: " + exportName);
                    console.log("    args[0]: " + args[0]);
                    console.log("    args[1]: " + (args[1] ? args[1].readUtf8String() : "N/A"));
                },
                onLeave: function(retval) {
                    console.log("    return: " + retval);
                }
            });
        }
    });
    
    console.log("[*] VMP trace started");
});
```

---

### 策略3: 寻找OEP手动Dump（高级）

**核心思想：VMP在程序启动时解密代码，找到解密后的OEP**

```markdown
步骤：
1. 用x32dbg打开目标
2. 设置断点到入口点（Entry Point）
3. 单步执行，观察pushad指令（VMP典型特征）
4. 继续执行直到代码解密完成
5. 使用ScyllaHide插件隐藏调试器
6. 使用VMProtect Dump插件dump内存
7. 用Scylla修复IAT
```

**警告：**
- ⚠️ 需要手动操作，无法完全自动化
- ⚠️ VMP专业版有anti-dump保护
- ⚠️ 需要丰富的逆向经验

---

### 策略4: 使用专用脱壳工具（有限成功）

```markdown
可用工具：
1. VMProtect Dump Plugin（x32dbg插件）
   - 网址：https://github.com/omgsolver/VMPDecryptPlugin
   - 适用：VMP免费版/标准版
   - 不适用：VMP专业版（有反调试）

2. ScyllaHide
   - 网址：https://github.com/NtQuery/ScyllaHide
   - 功能：隐藏调试器，辅助dump
   
3. exemon（自动化dump）
   - 网址：https://github.com/3lackrush/exemon
   - 功能：自动寻找OEP并dump
```

**使用流程：**
```powershell
# 1. 下载工具
git clone https://github.com/omgsolver/VMPDecryptPlugin.git

# 2. 用x32dbg打开目标
# 3. 加载插件
# 4. 运行dump
# 5. 用Scylla修复IAT
```

---

## 三、WYX的VMP应对工作流

### 完整流程

```powershell
# Phase 1: 识别VMP
r2 -aa target.so
iz ~ vmp
iz ~ VMProtect

# Phase 2: 判断保护强度
# - 有.vmp0 section → VMP保护
# - entropy > 0.9 → 高度保护
# - 有anti-debug → 专业版

# Phase 3: 选择策略
if (有Java层代码) {
    # 策略1: 直接Frida Hook Java层（最简单）
    pwsh -File "scripts/frida-run.ps1" -Spawn -Package com.example -ScriptPath bypass_java.js
} elseif (只有Native层) {
    if (VMP免费版/标准版) {
        # 策略3: 尝试手动Dump
        Write-Host "使用x32dbg + VMP Dump插件"
    } else {
        # 策略2: Trace分析
        pwsh -File "scripts/frida-run.ps1" -Spawn -Package com.example -ScriptPath trace_vmp.js
    }
}

# Phase 4: 根据Trace结果编写绕过脚本
# 不关心VMP内部实现，只关心输入输出
```

---

## 四、实战案例

### 案例1: VMP保护的签到验证

**目标：** 绕过每日签到验证

**分析：**
```
1. jadx发现签到逻辑在Java层
2. 签名验证在Native层（libsign.so）
3. libsign.so被VMP保护
```

**解决方案：**
```javascript
// 不分析VMP保护的Native代码
// 直接Hook Java层调用

Java.perform(function() {
    var SignActivity = Java.use("com.example.SignActivity");
    
    // Hook签到按钮点击
    SignActivity.onSignClick.implementation = function() {
        console.log("[*] Sign button clicked");
        
        // 直接调用验证，但Hook返回值
        var result = this.verifySign();
        console.log("[*] Original result: " + result);
        
        // 强制返回true
        return true;
    };
});
```

**结果：**
- ✅ 成功绕过VMP保护
- ✅ 不需要脱壳
- ✅ 耗时5分钟

---

### 案例2: VMP+ Themida双重保护

**目标：** 分析加密算法

**分析：**
```
1. 代码被Themida + VMP双重保护
2. 静态分析完全无法进行
3. entropy = 0.98（极高）
```

**解决方案：**
```javascript
// 只能动态Trace
Interceptor.attach(Module.findExportByName("libcrypto.so", "encrypt_data"), {
    onEnter: function(args) {
        this.input = args[0].readByteArray(parseInt(args[1]));
        console.log("[*] Input: " + bytesToHex(this.input));
    },
    onLeave: function(retval) {
        var output = Memory.readByteArray(retval, parseInt(this.args[2]));
        console.log("[*] Output: " + bytesToHex(output));
        
        // 记录输入输出对
        // 手动分析加密逻辑
        saveTrace(this.input, output);
    }
});
```

**结果：**
- ⚠️ 无法完全自动化
- ⚠️ 需要人工分析Trace结果
- ✅ 但比静态分析强得多

---

## 五、常见问题

### Q1: VMP专业版能脱吗？
```
答案：几乎不能静态脱。
建议：直接动态Hook，不浪费时间脱壳。
```

### Q2: VMP + anti-debug怎么办？
```
答案：
1. 使用ScyllaHide隐藏调试器
2. 或者直接用Frida（不受anti-debug影响）
3. 或者用Qiling模拟器（无调试器 artifact）
```

### Q3: 如何判断VMP版本？
```powershell
# 查看section名称
r2 -aa target.so
isz | Select-String "vmp"

# 查看entropy
r2 -aa target.so
pD~entropy

# 查看是否有anti-debug
strings target.so | Select-String "IsDebuggerPresent|CheckRemoteDebuggerPresent"
```

---

## 六、总结

### VMP应对原则

```
1. 不要试图静态脱VMP（浪费时间）
2. 优先动态Hook（简单有效）
3. Trace输入输出（推断逻辑）
4. 只有关键情况才考虑手动Dump
```

### WYX的VMP能力评级

| 能力 | 评级 | 说明 |
|------|------|------|
| VMP识别 | ⭐⭐⭐⭐⭐ | 自动检测.vmp section |
| 动态Hook | ⭐⭐⭐⭐⭐ | Frida不受VMP影响 |
| Trace分析 | ⭐⭐⭐⭐⭐ | 记录输入输出 |
| 静态脱壳 | ⭐ | 几乎无法自动化 |
| 手动Dump | ⭐⭐ | 需要人工操作 |

### 最终建议

```
遇到VMP保护：
1. 先用WYX的decode.ps1解密APK
2. 用search-logic.ps1搜索关键逻辑
3. 判断是Java层还是Native层
4. Java层 → 直接Frida Hook
5. Native层 → Trace分析或手动Dump
6. 不要浪费时间在静态脱壳上
```

---

**版本**: 1.0
**最后更新**: 2026-09-13
**作者**: 海鸥（WYX Skill）
