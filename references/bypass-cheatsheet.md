# 常见绕过场景速查

> 按检测类型分类，直接复制使用。

## Root 检测绕过

### Level 1: File.exists() 拦截

```javascript
Java.perform(function() {
    var File = Java.use("java.io.File");
    var sensitive = ["su", "magisk", "busybox", "xposed", "root",
        "/system/xbin/su", "/system/bin/su", "/sbin/su",
        "/data/local/xbin/su", "/data/local/bin/su",
        "magisk", "topjohnwu", "supersu"];
    File.exists.implementation = function() {
        var p = this.getAbsolutePath().toLowerCase();
        for (var i = 0; i < sensitive.length; i++) {
            if (p.indexOf(sensitive[i]) !== -1) return false;
        }
        return this.exists();
    };
});
```

### Level 2: Runtime.exec() 拦截

```javascript
Java.perform(function() {
    var Runtime = Java.use("java.lang.Runtime");
    var origExec = Runtime.exec.overload('java.lang.String').implementation;
    Runtime.exec.overload('java.lang.String').implementation = function(cmd) {
        if (cmd.toLowerCase().indexOf("su") !== -1) {
            throw Java.use("java.io.IOException").$new("Permission denied");
        }
        return origExec.call(this, cmd);
    };
});
```

### Level 3: PackageManager 隐藏包

```javascript
Java.perform(function() {
    var PM = Java.use("android.content.pm.PackageManager");
    var blocked = ["de.robv.android.xposed.installer", "com.topjohnwu.magisk",
                   "com.nothome.delta", "org.frida.server", "com.koushikdutta.superuser"];
    var origGet = PM.getPackageInfo.overload('java.lang.String', 'int');
    PM.getPackageInfo.overload('java.lang.String', 'int').implementation = function(pkg, flags) {
        for (var i = 0; i < blocked.length; i++) {
            if (pkg.indexOf(blocked[i]) !== -1)
                throw PM$NameNotFoundException.$new();
        }
        return origGet.call(this, pkg, flags);
    };
});
```

### Level 4: Build.TAGS / 系统属性

```javascript
Java.perform(function() {
    var Build = Java.use("android.os.Build");
    Build.TAGS.value = "release-keys";
    // 其他属性
    Build.FINGERPRINT.value = "google/shamu/shamu:6.0/MRA58E/user/2526030:user/release-keys";
});
```

### Level 5: Native 检测绕过（syscall）

```javascript
// ptrace TracerPid 检测
var ptrace = Module.findExportByName(null, "ptrace");
if (ptrace) {
    Interceptor.attach(ptrace, {
        onEnter: function(args) {
            if (args[0].toInt32() === 10) { // PTRACE_GETSYSINFO
                this.hide = true;
            }
        },
        onLeave: function(retval) {
            if (this.hide) retval.replace(0);
        }
    });
}

// /proc/self/status 检测 TracerPid
var statusPath = "/proc/self/status";
var origRead = Module.findExportByName("libc.so", "read");
// 更简单: Hook fopen/fread
var fopen = Module.findExportByName(null, "fopen");
if (fopen) {
    Interceptor.attach(fopen, {
        onEnter: function(args) {
            this.path = args[0].readUtf8String();
        },
        onLeave: function(retval) {
            if (this.path === statusPath && retval.toInt32() !== 0) {
                // 后续 fread 时修改 TracerPid: 0
            }
        }
    });
}
```

## SSL Pinning 绕过

### OkHttp3

```javascript
Java.perform(function() {
    try {
        var CP = Java.use("okhttp3.CertificatePinner");
        CP.check.overload('java.lang.String', 'java.util.List').implementation = function() {};
    } catch(e) {}
    try {
        var TPM = Java.use("com.android.org.conscrypt.TrustManagerImpl");
        TPM.verifyChain.implementation = function(chain) { return chain; };
    } catch(e) {}
    try {
        var X509 = Java.use("javax.net.ssl.X509TrustManager");
        var TM = Java.registerClass({
            name: "com.bypass.TM",
            implements: [X509],
            methods: {
                checkClientTrusted: function() {},
                checkServerTrusted: function() {},
                getAcceptedIssuers: function() { return []; }
            }
        });
    } catch(e) {}
});
```

### JavaSSLSocket sslCheck

```javascript
Java.perform(function() {
    try {
        var Socket = Java.use("javax.net.ssl.SSLSession");
        // Android 7+ NetworkSecurityConfig
        var NSC = Java.use("android.security.net.config.NetworkSecurityConfig");
        NSC.isCleartextTrafficPermitted.implementation = function() { return true; };
    } catch(e) {}
});
```

### Native SSL (OpenSSL/BoringSSL)

```javascript
// SSL_CTX_set_ssl_cipher 等 native hook
var ssl = Process.findModuleByName("libssl.so") || Process.findModuleByName("libboringssl.so");
if (ssl) {
    var sslVerify = ssl.findExportByName("SSL_get_verify_result");
    if (sslVerify) {
        Interceptor.attach(sslVerify, {
            onLeave: function(retval) { retval.replace(0); }
        });
    }
}
```

## 反调试绕过

### Java 层

```javascript
Java.perform(function() {
    // Debug.isDebuggerConnected
    try {
        var D = Java.use("android.os.Debug");
        D.isDebuggerConnected.implementation = function() { return false; };
    } catch(e) {}
    // System.checkJni
    try {
        var S = Java.use("java.lang.System");
        S.checkJni = function() {};
    } catch(e) {}
});
```

### Native 层

```javascript
// isDebuggerConnected native
var isDbg = Module.findExportByName(null, "isDebuggerConnected");
if (isDbg) {
    Interceptor.attach(isDbg, { onLeave: function(r) { r.replace(0); } });
}

// sysctl (iOS)
var sysctl = Module.findExportByName(null, "sysctl");
if (sysctl) {
    Interceptor.attach(sysctl, {
        onEnter: function(args) {
            this.mib = args[0];
        },
        onLeave: function(retval) {
            // CTL_KERN / KERN_PROC / KERN_PROC_PID = 1/14/12
            if (this.mib) {
                // 检测 PT_DENY_ATTACH 绕过
            }
        }
    });
}
```

## 模拟器检测绕过

```javascript
Java.perform(function() {
    // Build 属性伪造
    var Build = Java.use("android.os.Build");
    Build.MODEL.value = "Pixel 6";
    Build.MANUFACTURER.value = "Google";
    Build.BRAND.value = "Google";
    Build.DEVICE.value = "shusky";
    Build.PRODUCT.value = "shusky";
    Build.HARDWARE.value = "shusky";

    // TelephonyManager 伪造
    try {
        var TM = Java.use("android.telephony.TelephonyManager");
        TM.getDeviceId.implementation = function() { return "35BBBBBB0123456"; };
        TM.getSubscriberId.implementation = function() { return "310004123456789"; };
        TM.getNetworkOperatorName.implementation = function() { return "T-Mobile"; };
    } catch(e) {}
});
```

## 常用检测库 Hook 列表

| 库类名 | Hook 目标 |
|--------|----------|
| `com.scottyab.rootbeer.RootBeer` | `isRooted()`, `isRootedWithBusyBox()`, `checkSuExists()` |
| `com.noshifuou.ba` | `checkRoot()` |
| `com.genonmale.trebuchet` | `checkRoot()` |
| `eu.chainfire.supersu` | `isActiveRoot()` |
| `com.devadvance.rootcover` | `isRootAvailable()` |
| `com.yellowes.suki` | `checkRoot()` |
| `com.koushikdutta.superuser` | `checkRoot()` |
| `com.noshuyuou.ba` | `isRootAvailable()` |
