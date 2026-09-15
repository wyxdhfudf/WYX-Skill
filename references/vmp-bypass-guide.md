# 虚拟机保护绕过指南

> 针对 VMProtect、Themida 等虚拟机保护的动态分析策略

---

## 一、识别虚拟机保护

### 1.1 静态特征

```powershell
# 查看PE section 名称
# VMP常用: .vmp0, .vmp1
# Themida常用: .themida, .data2

# 用 dumpbin
dumpbin /headers target.dll | Select-String "sections"

# 用 PowerShell 解析
$pesee = dumpbin /headers target.dll
$pesee -match "\.vmp\d"  # VMP检测
$pesee -match "themida"   # Themida检测
```

### 1.2 熵值分析

```powershell
# VMP保护的代码段熵值极高（接近1.0）
# 正常代码约0.6-0.8

# 使用 PETools 或手动计算
# entropy > 0.95 → 高度可能受VM保护
```

### 1.3 特征字符串

```powershell
strings target.dll | Select-String "VMProtect|themida|vmp|virtual"
```

---

## 二、绕过策略

### 策略1: Java层Hook（最简单）

**适用场景**: VMP只保护Native层，Java层未保护

```javascript
Java.perform(function() {
    // 直接Hook Java方法，不碰Native层
    var TargetClass = Java.use("com.example.TargetClass");
    
    TargetClass.verifyKey.implementation = function(key) {
        console.log("[*] verifyKey called with: " + key);
        return true; // 直接返回true
    };
    
    console.log("[*] Java layer bypass loaded");
});
```

### 策略2: Native导出函数Hook

**适用场景**: 需要Hook特定的Native函数

```javascript
Java.perform(function() {
    var lib = Process.findModuleByName("libtarget.so");
    if (!lib) return;
    
    // 找导出函数
    var func = lib.findExportByName("Java_com_example_Target_verify");
    if (!func) {
        console.log("[!] Export not found");
        return;
    }
    
    Interceptor.attach(func, {
        onEnter: function(args) {
            console.log("[*] Native verify called");
            this.key = args[1].readUtf8String();
        },
        onLeave: function(retval) {
            console.log("[*] Result: " + retval.toInt32());
            retval.replace(1); // 强制返回true
        }
    });
});
```

### 策略3: Trace分析

**适用场景**: 不关心内部实现，只需要输入输出对应关系

```javascript
// trace_all.js
var tracedExports = [
    "Java_com_example_Target_verify",
    "Java_com_example_Target_encrypt",
    "encrypt_data",
    "decrypt_data"
];

Java.perform(function() {
    var lib = Process.findModuleByName("libtarget.so");
    if (!lib) return;
    
    tracedExports.forEach(function(name) {
        var func = lib.findExportByName(name);
        if (func) {
            Interceptor.attach(func, {
                onEnter: function(args) {
                    console.log("\n[+] " + name);
                    for (var i = 0; i < Math.min(args.length, 4); i++) {
                        try {
                            console.log("    arg[" + i + "]: " + args[i].readUtf8String());
                        } catch(e) {
                            console.log("    arg[" + i + "]: 0x" + args[i].toString(16));
                        }
                    }
                },
                onLeave: function(retval) {
                    console.log("    return: " + retval);
                }
            });
        }
    });
    
    console.log("[*] Trace started");
});
```

### 策略4: 调试器附加

**适用场景**: 需要单步跟踪特定函数

```powershell
# 使用 x64dbg 或 Cheat Engine
# 1. 附加到进程
# 2. 设置断点到目标函数
# 3. 运行到断点
# 4. 分析寄存器状态
# 5. 单步执行观察VMP解密过程
```

**注意**: VMP专业版有反调试检测，需要使用 ScyllaHide 等插件隐藏调试器。

---

## 三、完整工作流

```powershell
# 1. 识别保护类型
r2 -aa libtarget.so
isz  # 查看section名称

# 2. 判断攻击面
# - 有Java层代码 → 策略1（最简单）
# - 只有Native层 → 策略2或3
# - 有anti-debug → 策略4 + ScyllaHide

# 3. 编写绕过脚本
# 根据Trace结果确定关键函数
# Hook返回值为true

# 4. 注入验证
frida -U -f com.example.app -l bypass.js --no-pause
```

---

## 四、常见问题

### Q1: VMP检测Frida怎么办？

```javascript
// 方法1: 隐藏Frida进程名
// 在bypass.js开头添加
var handle = Module.findExportByName(null, "dlopen");
if (handle) {
    Interceptor.attach(handle, {
        onEnter: function(args) {
            var path = args[0].readUtf8String();
            if (path.includes("frida")) {
                console.log("[!] Frida detected: " + path);
            }
        }
    });
}

// 方法2: 使用frida-server的隐藏模式
// ./frida-server --hide frida
```

### Q2: VMP + Themida 双重保护？

```
双重保护 = VMP + 代码混淆 + 反调试
策略：
1. 优先找Java层漏洞（通常只保护Native）
2. 如果必须分析Native，用Trace分析
3. 记录所有输入输出对
4. 手动推断加密逻辑
```

### Q3: 如何快速定位验证函数？

```powershell
# 搜索关键词
jadx -d jadx_out target.apk
Get-ChildItem jadx_out -Recurse | Select-String "verify|check|valid|auth" -List

# 查看调用链
# 找到上层调用后，在IDA中查看交叉引用
```

---

## 五、总结

### 优先级

```
1. Java层Hook（最快）
2. Native导出函数Hook（次快）
3. Trace分析（通用）
4. 手动调试（最后手段）
```

### 核心原则

```
- 不要尝试静态脱VMProtect（几乎不可能）
- 动态分析是唯一出路
- Hook返回值为真是最简单的绕过
- Trace分析可以绕过大部分保护
```

---

**版本**: 1.0
**最后更新**: 2026-09-15
**作者**: 海鸥
