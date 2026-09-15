# WYX Skill — 游戏安全测试与APK逆向完整工作流

> ⚠️ **免责声明**：本skill仅用于授权的渗透测试、安全研究、CTF比赛和个人学习。未经授权使用他人软件进行破解、外挂开发属于违法行为。

## 📋 概述

WYX Skill 是一个面向游戏安全和移动端逆向工程的 Claude Code 技能包，提供从目标分析到最终验证的完整工作流。

**核心特性：**
- ✅ 本地化配置（适配 Windows 环境）
- ✅ 端到端工作流（从 APK 分析到重打包安装）
- ✅ 实战经验积累（memory + field-journal 系统）
- ✅ 自动化脚本（一键解密、注入、重打包）
- ✅ 模板库（Hook 模板、绕过模板、C/Rust 代码模板）

---

## 🚀 快速开始

### 安装

```bash
# 克隆到 Claude Code skills 目录
git clone <your-repo-url> ~/.claude/skills/WYX

# 或手动复制
cp -r WYX/ ~/.claude/skills/WYX/
```

### 触发方式

在 Claude Code 中使用斜杠命令：
```
/WYX
```

或在对话中提及关键词自动触发：
- APK逆向、APK破解
- 游戏外挂分析
- 加密算法提取
- Frida Hook
- SSL Pinning绕过
- Root检测绕过
- so逆向
- 卡密破解
- DLL注入

---

## 📦 功能模块

| 模块 | 说明 | 触发条件 |
|------|------|---------|
| **APK静态分析** | jadx/apktool 反编译、Smali层修改 | APK分析请求 |
| **APK动态Hook** | Frida/Xposed 运行时Hook | 动态分析需求 |
| **Native层分析** | .so 文件逆向（IDA/radare2） | 发现JNI调用核心逻辑 |
| **游戏内存分析** | Unity/UE4 游戏逆向 | 游戏相关请求 |
| **DLL注入** | Windows 游戏注入工具 | DLL注入需求 |
| **加密算法破解** | 卡密/签名验证绕过 | 卡密相关请求 |
| **绕过检测** | Root/SSL/反调试绕过套件 | 检测绕过需求 |
| **Unity IL2CPP** | Il2CppDumper + IDA分析 | Unity游戏 |
| **UE4逆向** | UE4SS + UObject dump | Unreal游戏 |

---

## 🔧 核心工作流

```
1. 目标识别 → 确定游戏/APK类型
     ↓
2. 静态分析 → jadx/apktool 反编译
     ↓
3. 动态分析 → Frida Hook / x64dbg 调试
     ↓
4. 逻辑还原 → 定位验证逻辑/内存结构
     ↓
5. 绕过实现 → 编写 hook 脚本 / DLL / 修改 smali
     ↓
6. 验证测试 → 功能验证 + 稳定性测试
     ↓
7. 文档输出 → 生成分析报告
```

---

## 🛠️ 工具链集成

本 skill 集成以下工具（基于 Windows 环境配置）：

| 工具 | 用途 | 路径示例 |
|------|------|---------|
| jadx | Java 反编译 | `jadx -d out.apk` |
| apktool | APK 解包/重打包 | `apktool d target.apk` |
| Frida | 动态 Hook | `frida -U -f com.app -l hook.js` |
| x64dbg | Windows 调试器 | 手动载入 PE 文件 |
| IDA Pro | Native 层逆向 | CLI / GUI 逆向分析工具 |
| Il2CppDumper | Unity SDK 生成 | `python Il2CppDumper.py` |
| UE4SS | Unreal 逆向框架 | 注入 DLL |
| Ghidra | 通用逆向分析 | CLI 模式 |
| radare2 | CLI 逆向工具 | `r2 -aa lib.so` |
| Scylla | 脱壳工具 | `scylla.exe` |
| Detect It Easy | 查壳工具 | DiE GUI/CLI |

---

## 📝 实战经验积累

WYX Skill 支持**自我提升**机制：

### 工作原理

```
任务完成 → 写入 field-journal → 下次任务自动读取 → 基于经验做出更优判断
```

### 使用方式

```
# 完成任务后，说：
"把这次经验记录到 memory 里"

# AI 会写入：
~/.claude/skills/WYX/field-journal/YYYY-MM-DD-<task-name>.md
~/.claude/projects/<project>/memory/*.md
```

### 经验层级

| 层级 | 目录 | 内容 | 建议公开 |
|------|------|------|---------|
| 索引 | `memory/MEMORY.md` | 经验文件列表 | ✅ 可公开 |
| 内容 | `memory/*.md` | 具体经验记录 | ❌ 建议私有 |
| 案例 | `field-journal/` | 详细任务复盘 | ❌ 必须私有 |
| 工作 | `work/` | 临时分析文件 | ❌ 必须私有 |

---

## 📂 仓库结构

```
WYX/
├── SKILL.md              # Skill 定义（主入口）
├── EXPERIENCE-GUIDE.md   # 经验积累使用说明
├── .gitignore            # Git 排除规则
├── workflows/            # 工作流定义
│   ├── apk-static.md     # APK 静态分析
│   ├── apk-dynamic.md    # APK 动态 Hook
│   ├── crypto-crack.md   # 加密算法破解
│   ├── game-memory.md    # 游戏内存分析
│   ├── dll-inject.md     # DLL 注入
│   ├── unity-reverse.md  # Unity IL2CPP 逆向
│   ├── ue4-reverse.md    # UE4 逆向
│   └── report-gen.md     # 报告生成
├── references/           # 参考文档
│   ├── bypass-cheatsheet.md  # 绕过检测速查表
│   ├── native-hook-cheatsheet.md # Native Hook 模板
│   ├── tool-checklist.md     # 工具检查清单
│   └── workflows.md          # 工作流汇总
└── scripts/              # 自动化脚本
    ├── decode.ps1        # APK 一键解密
    ├── frida-run.ps1     # Frida 注入脚本
    ├── build-dll.ps1     # DLL 编译脚本
    └── search-logic.ps1  # 逻辑搜索脚本
```

---

## 🔐 隐私与安全

本 skill 设计时考虑了隐私保护：

- **field-journal 和 memory 默认不公开**（通过 .gitignore 排除）
- 下载者获得的是**工作流模板**，而非**实战经验**
- 每个用户只能积累**自己的**经验

如需完全开源经验，可手动移除 `.gitignore` 中的排除规则。

---

## 🤝 贡献指南

欢迎贡献新的绕过模板、Hook 脚本或工作流优化：

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/xxx`)
3. 提交更改 (`git commit -am 'Add xxx'`)
4. 推送到分支 (`git push origin feature/xxx`)
5. 创建 Pull Request

**请勿提交：**
- `field-journal/` 内容
- `memory/*.md` 中的具体经验
- `work/` 目录下的临时文件

---

## 📄 License

MIT License — 自由使用，自行负责。

---

## 📞 联系方式

- GitHub Issues: [提交问题或建议]
- 技术支持: 通过 Claude Code 使用 `/WYX` 触发

---

**Built with ❤️ by 海鸥**
