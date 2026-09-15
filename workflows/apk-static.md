# APK静态分析工作流

> 完整的APK静态分析流程，从解密到逻辑定位

---

## Phase 0: 快速侦察（5分钟）

### 0.1 一键解密

```powershell
# 使用WYX一键脚本
pwsh -File "../scripts/decode.ps1" -ApkPath "D:\target.apk"
```

**输出解读**:
```
[*] WYX Decode Script v2.0
[*] Target: D:\target.apk
[*] Running jadx...
[+] JADX success: target\jadx
[*] Running apktool...
[+] APKTool success: target\apktool
  Package: com.example.app
  SO files: 2
  [!] Native library detected - consider ida-reverse skill
```

**决策信号**:
- `SO files: 0` → 纯Java分析，继续Phase 1
- `SO files > 0` → 核心逻辑在Native层，计划调用ida-reverse
- `Package: com.example.il2cpp` → Unity游戏，计划使用Il2CppDumper

### 0.2 Manifest分析

```powershell
pwsh -File "../scripts/manifest-summary.ps1" -ManifestPath "target\apktool\AndroidManifest.xml"
```

**关键信息提取**:
- 包名 → 确定App身份
- 权限列表 → 评估风险等级
- 导出组件 → 寻找攻击面
- Application子类 → 查找初始化逻辑

### 0.3 关键逻辑搜索

```powershell
# 搜索验证相关逻辑
pwsh -File "../scripts/search-logic.ps1" -SourceDir "target\jadx" -Keywords @("license","auth","key","verify","sign","check")

# 搜索加密相关逻辑
pwsh -File "../scripts/search-logic.ps1" -SourceDir "target\jadx" -Keywords @("encrypt","decrypt","cipher","hash","md5","sha","aes")
```

---

## Phase 1: 深度静态分析

### 1.1 Java层分析

#### 1.1.1 入口点分析

```powershell
# 查看Application类
jadx --single-class com.example.MyApp -d jadx_out target.apk

# 重点看onCreate()方法
# 查找：SDK初始化、加密初始化、检查逻辑
```

**分析要点**:
- [ ] 是否有第三方SDK初始化
- [ ] 是否有加密库初始化（OkHttp、SSL）
- [ ] 是否有安全检测初始化（Root、模拟器）
- [ ] 是否有网络请求初始化

#### 1.1.2 登录/验证流程

```powershell
# 搜索登录相关类
Get-ChildItem target\jadx -Recurse -Include "*.java" | Select-String -Pattern "Login|Auth|SignIn" -List

# 查看关键Activity
jadx --single-class com.example.LoginActivity -d jadx_out target.apk
```

**分析要点**:
- [ ] 登录请求URL
- [ ] 请求参数（用户名、密码、设备ID）
- [ ] 响应处理逻辑
- [ ] 本地验证逻辑（卡密、许可证）

#### 1.1.3 加密逻辑定位

```powershell
# 搜索加密类
Get-ChildItem target\jadx -Recurse -Include "*.java" | Select-String -Pattern "Cipher|MessageDigest|Hmac" -List

# 查看加密工具类
jadx --single-class com.example.EncryptUtils -d jadx_out target.apk
```

**分析要点**:
- [ ] 加密算法（AES/RSA/自定义）
- [ ] 密钥来源（硬编码/服务器下发/设备绑定）
- [ ] 加密模式（ECB/CBC/GCM）
- [ ] 使用场景（网络请求/本地存储/文件加密）

### 1.2 Smali层分析

当Java层反编译不完整或需要修改时：

```powershell
# 查看Smali代码
notepad target\apktool\smali\com\example\LoginActivity.smali

# 搜索关键方法
Select-String -Path "target\apktool\smali\**\*.smali" -Pattern "checkLicense|verifySignature"
```

**常用Patch场景**:

| 场景 | Smali改法 | 示例 |
|------|-----------|------|
| 绕过登录验证 | 找`if-eqz`改成`if-nez` | `if-eqz v0, :cond_100` → `if-nez v0, :cond_100` |
| 禁用Root检测 | 修改检测类返回值 | `return v0` → `const/4 v0, 0x0` |
| 绕过签名校验 | Hook PackageManager | 见bypass-cheatsheet.md |
| 解锁付费功能 | 修改布尔值 | `const/4 v0, 0x0` → `const/4 v0, 0x1` |

### 1.3 网络请求分析

```powershell
# 搜索网络请求代码
Get-ChildItem target\jadx -Recurse -Include "*.java" | Select-String -Pattern "OkHttp|Retrofit|HttpClient|POST|GET" -List

# 查看网络配置
jadx --single-class com.example.NetworkConfig -d jadx_out target.apk
```

**分析要点**:
- [ ] API基础URL
- [ ] 请求头（User-Agent、Authorization）
- [ ] 加密的请求参数
- [ ] 响应格式（JSON/Protobuf）

---

## Phase 2: 分析结论

### 2.1 输出报告模板

```markdown
# APK静态分析报告

## 基本信息
- **包名**: com.example.app
- **版本**: 1.0.0 (100)
- **入口Activity**: com.example.MainActivity
- **Native库**: 2个（libgame.so, libutils.so）

## 关键发现
1. **登录验证**: 本地卡密验证 + 服务器二次验证
2. **加密算法**: AES-CBC，密钥硬编码在libgame.so
3. **安全检查**: Root检测（File.exists）、SSL Pinning（OkHttp3）
4. **付费功能**: 订阅制，本地记录过期时间

## 绕过策略
- [ ] 方案A: Frida Hook验证函数（推荐）
- [ ] 方案B: Smali Patch签名校验（需重打包）
- [ ] 方案C: Native层Hook加密函数（复杂）

## 下一步建议
1. 使用Frida进行动态Hook验证
2. 参考bypass-cheatsheet.md编写绕过脚本
3. 如需Native分析，调用ida-reverse skill
```

### 2.2 决策菜单

```
## 建议下一步（选一个编号）

1. 使用Frida进行动态Hook验证
2. 修改Smali代码并重打包
3. 分析Native .so文件（调用ida-reverse）
4. 生成当前阶段的分析报告
5. 暂停，我需要更多信息
```

---

## 常见问题

### Q1: jadx反编译失败怎么办？
```powershell
# 尝试混淆模式
jadx --deobf -d jadx_out_deobf target.apk

# 或只导出单个类
jadx --single-class com.example.KeyClass -d jadx_out target.apk
```

### Q2: 找不到关键类怎么办？
```powershell
# 全量搜索
Get-ChildItem target\jadx -Recurse -Include "*.java" | Select-String -Pattern "关键关键词" -List

# 搜索字符串资源
Select-String -Path "target\apktool\res\values\strings.xml" -Pattern "license|auth|key"
```

### Q3: 如何判断核心逻辑在哪个层？
```
判断流程：
1. 查看Manifest中的application标签
2. 查看lib/目录下的.so文件数量
3. 搜索System.loadLibrary()调用
4. 如果.so数量>0且Java层只有JNI包装 → 核心在Native层
```

---

## 相关资源

- [bypass-cheatsheet.md](../references/bypass-cheatsheet.md) - 绕过检测模板
- [native-hook-cheatsheet.md](../references/native-hook-cheatsheet.md) - Native Hook模板
- [experience-database.md](../references/experience-database.md) - 实战经验库
- [scripts/decode.ps1](../scripts/decode.ps1) - 一键解密脚本
- [scripts/search-logic.ps1](../scripts/search-logic.ps1) - 逻辑搜索脚本

---

**版本**: 1.0
**最后更新**: 2026-09-13
