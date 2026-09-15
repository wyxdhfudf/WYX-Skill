# 标准工作流

## 工作流1: APK静态分析（签名/卡密验证）

### 适用场景
- 破解APK软件授权验证
- 移除卡密检测
- 分析加密通信

### 执行步骤

```powershell
# 1. 解包APK
pwsh -File "<SKILL_ROOT>\scripts\decode.ps1" -ApkPath "C:\target\app.apk"

# 2. 分析Manifest
pwsh -File "<SKILL_ROOT>\scripts\manifest-summary.ps1" -ManifestPath "C:\target\app_apk\AndroidManifest.xml"

# 3. 搜索关键逻辑
jadx -d "C:\target\jadx_out" "C:\target\app.apk" --search "license|auth|key|verify|sign"
```

### 输出目录结构
```
work/<target>/
├── original.apk          # 原始样本（哈希备份）
├── apktool_out/          # smali+资源
├── jadx_out/             # Java反编译
├── analysis.md           # 分析报告
└── patches/              # 修改后的文件
```

## 工作流2: 游戏内存分析（自瞄/透视/无后座）

### 适用场景
- Unity/UE4游戏内存读取
- Entity list定位
- Bone matrix计算
- 屏幕坐标转换

### 执行步骤

```powershell
# 1. 找基址和偏移
# 使用Cheat Engine扫描游戏内存值

# 2. Dump游戏SDK
# Unity: Il2CppDumper
# UE4: UE4SS

# 3. 编写内存读取代码
# 参考 D:\shua-ke\ow_rust\src\lib.rs
```

### 关键地址定位技巧
- Entity list: 搜索"entity"相关字符串或类
- Bone matrix: 搜索"bone"或渲染相关函数
- Camera position: 搜索"camera"或视图矩阵
- Screen size: 搜索分辨率相关常量

## 工作流3: Frida动态Hook

### 适用场景
- 运行时篡改返回值
- 绕过root检测
- 绕过SSL Pinning
- Hook关键函数

### 模板脚本

```javascript
// hook_example.js
Java.perform(function() {
    // Hook登录验证
    var LoginActivity = Java.use("com.example.LoginActivity");
    LoginActivity.verifyLogin.implementation = function() {
        console.log("[+] Hooked verifyLogin");
        return true; // 直接返回true绕过验证
    };
    
    // Hook网络请求
    var OkHttp = Java.use("okhttp3.OkHttpClient");
    OkHttp.newCall.implementation = function(request) {
        console.log("[+] Request: " + request.url());
        return this.newCall(request);
    };
});
```

### 执行命令
```powershell
frida -U -f com.example.app -l hook.js --no-pause
```

## 工作流4: DLL注入（Windows游戏）

### 适用场景
- PC游戏内存修改
- ESP叠加层
- 功能注入

### 编译命令
```powershell
$env:RUSTUP_HOME = "D:\rust\.rustup"
$env:CARGO_HOME = "D:\rust\.cargo"
$env:PATH = "D:\rust\.cargo\bin;D:\mingw64\mingw64\bin;$env:PATH"
cargo build --release --target x86_64-pc-windows-gnu
```

### 注入方法
1. Process Hacker: 右键进程 → Plugins → Inject DLL
2. Cheat Engine: 工具 → DLL注入器
3. 手动: CreateRemoteThread + LoadLibrary

## 工作流5: 加密算法分析

### 适用场景
- 破解卡密生成算法
- 逆向加密通信
- 恢复签名验证

### 分析步骤
1. 字符串搜索: `grep -r "AES\|RSA\|MD5\|SHA\|encrypt\|decrypt"`
2. 混淆识别: OLLVM控制流平坦化、MBA混淆
3. 符号执行: angr路径探索
4. 运行时捕获: Frida hook加密函数记录输入输出
