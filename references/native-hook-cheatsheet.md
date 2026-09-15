# Native Hook 模板

> Frida Native 层 Hook 速查，针对 .so 导出函数和内部函数。

## 基础模板

```javascript
Interceptors.attach(Module.findExportByName("libc.so", "open"), {
    onEnter: function(args) {
        this.path = args[0].readUtf8String();
        console.log("[open] " + this.path);
    },
    onLeave: function(retval) {
        console.log("[open] ret=" + retval);
    }
});
```

## 模块查找

```javascript
// 按名称找模块
var lib = Process.findModuleByName("libtarget.so");
if (!lib) {
    console.log("[!] Module not found");
    Process.enumerateModules().forEach(function(m) {
        console.log("  " + m.name + " @ " + m.base.toString());
    });
}

// 按路径找
var base = Module.findBaseAddress("libtarget.so");
```

## Hook 导出函数

```javascript
// 方法1: findExportByName
var func = Module.findExportByName("libtarget.so", "Java_com_target_Game_nativMethod");
if (func) {
    Interceptor.attach(func, {
        onEnter: function(args) {
            console.log("args[0]=context, args[1]=jclass, args[2]=" + args[2]);
        },
        onLeave: function(ret) {
            console.log("ret=" + ret);
        }
    });
}

// 方法2: enumerateExports
var mod = Module.findModuleByName("libtarget.so");
mod.enumerateExports().forEach(function(exp) {
    if (exp.name.indexOf("encrypt") !== -1 || exp.name.indexOf("sign") !== -1) {
        Interceptor.attach(exp.address, {
            onEnter: function(args) {
                console.log("[*] Hooked: " + exp.name);
            }
        });
    }
});
```

## Hook 内部函数（无导出名）

```javascript
// 通过 pattern 扫描找函数地址
var mod = Module.findModuleByName("libtarget.so");
var pattern = "48 89 5C 24 ? 48 89 74 24 ? 57 48 83 EC ? 48 8B DA";
var results = mod.scanSync(pattern);
results.forEach(function(addr) {
    console.log("Found at: " + addr.address.toString());
    Interceptor.attach(addr.address, {
        onEnter: function(args) { console.log("Called!"); },
        onLeave: function(ret) { console.log("Returns: " + ret); }
    });
});
```

## 参数读取

```javascript
// 读取字符串
var str = args[0].readUtf8String();

// 读取字节数组
var len = parseInt(args[1]);
var bytes = args[0].readByteArray(len);

// 读取整数
var num = args[0].toInt32();
var longNum = args[0].toInt64();

// 打印 hexdump
console.log(hexdump(args[0], { offset: 0, length: 64 }));
```

## 返回值改写

```javascript
Interceptor.attach(func, {
    onLeave: function(ret) {
        // 改返回值
        ret.replace(0x1337);
        // 或返回特定值
        if (this.wantFake) ret.replace(fakeValue);
    }
});
```

## 跨模块调用

```javascript
// 调用原始函数（保留实现）
var origFunc = new NativeFunction(
    Module.findExportByName("libtarget.so", "encrypt"),
    "uint64", ["pointer", "uint", "pointer"]
);
var result = origFunc(ptr(input), inputLen, output);
```

## common 游戏 Hook 目标

```javascript
// Unity IL2CPP — 找 Player Health
Interceptor.attach(
    Module.findExportByName("libil2cpp.so", "Player_set_health"),
    { onLeave: function(r) { console.log("health=" + r); } }
);

// Unreal Engine — W2S
var w2s = Module.findExportByName("libUE4.so", "?WorldToScreen...");
if (w2s) {
    Interceptor.attach(w2s, {
        onEnter: function(args) {
            // args: This, Camera, ActorLocation, OutScreenPos, bCameraToWorld
        },
        onLeave: function(ret) {
            console.log("W2S result: " + ret);
        }
    });
}
```
