# WYX Skill 使用指南

## 快速开始

### 1. APK逆向分析

```powershell
# 一键解密
pwsh -File "scripts/decode.ps1" -ApkPath "D:\target.apk"

# 查看Manifest
pwsh -File "scripts/manifest-summary.ps1" -ManifestPath "target_out/AndroidManifest.xml"

# 搜索关键逻辑
pwsh -File "scripts/search-logic.ps1" -SourceDir "target_out/jadx"

# Frida注入
pwsh -File "scripts/frida-run.ps1" -Usb -Spawn -Package com.game.target -ScriptPath "D:\hook.js"

# 重打包安装
pwsh -File "scripts/rebuild-sign-install.ps1" -ProjectDir "target_out/apktool" -Install
```

### 2. 游戏外挂开发

```powershell
# 编译DLL
pwsh -File "scripts/build-dll.ps1" -ProjectDir "<your-rust-project>" -Release

# 注入方法
# - Process Hacker: 右键进程 → Plugins → Inject DLL
# - Cheat Engine: 工具 → DLL注入器
# - 手动: CreateRemoteThread + LoadLibrary
```

### 3. EDR绕过

详见 `SKILL.md` 中的edr-syscall-bypass模块

## 常见问题

### Q1: jadx/apktool找不到？
A: 运行 `scripts/decode.ps1` 会自动检查并提示安装方式

### Q2: Rust编译报错dlltool missing？
A: 创建symlink:
```powershell
New-Item -Path "D:\mingw64\mingw64\bin\x86_64-w64-mingw32-dlltool.exe" `
         -ItemType SymbolicLink -Target "dlltool.exe" -Force
```

### Q3: Frida连接失败？
A: 检查frida-server版本是否匹配，或尝试USB调试模式

### Q4: 游戏检测Frida？
A: 使用 `references/bypass-cheatsheet.md` 中的Root/调试检测绕过模板

## 子模块说明

| 模块 | 用途 | 状态 |
|------|------|------|
| apk-static | APK静态分析 | ✅ 完整 |
| apk-dynamic | Frida动态Hook | ✅ 完整 |
| game-memory | 游戏内存分析 | ⚠️ 框架层 |
| dll-inject | DLL注入 | ⚠️ 框架层 |
| crypto-crack | 加密算法破解 | ⚠️ 框架层 |
| unity-reverse | Unity IL2CPP逆向 | ⚠️ 框架层 |

## 与GitHub项目联动

WYX可以调用以下GitHub项目作为子模块：

- **MobSF** → APK初步扫描
- **Il2CppDumper** → Unity SDK生成
- **UE4SS** → Unreal引擎逆向
- **Ghidra** → 深度二进制分析
- **SysWhispers3** → syscall stub生成
- **HyperHide** → Hypervisor反反调试

## 经验回写

每次完成任务后，WYX会自动：
1. 记录操作命令和输出
2. 更新field-journal
3. 索引经验条目
4. 下次任务前自动检索相关先例
