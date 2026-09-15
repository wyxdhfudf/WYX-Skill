# WYX Skill 介绍文案

## 简短版（适合论坛/社交媒体）

> **WYX Skill** — 一个会"自我学习"的游戏安全与 APK 逆向 Claude Code 技能包。
>
> 集成 jadx、Frida、IDA、Il2CppDumper 等主流逆向工具的工作流，支持从 APK 静态分析到动态 Hook、从 Native 层逆向到游戏内存修改的完整链路。
>
> 最独特的是它的**经验积累机制**：每次任务完成后自动记录实战经验，下次任务时基于历史经验做出更准确的判断。代码开源，经验私有。
>
> 🔗 GitHub: [链接]

---

## 详细版（适合技术博客/文档）

### 是什么？

WYX Skill 是面向游戏安全测试和移动端逆向工程的专业 Claude Code 技能包。它将 OW2 外挂开发、APK 逆向分析、加密算法破解等实战经验封装为标准化工作流，让每次任务都能基于历史经验进行优化。

### 核心功能

**1. 完整的逆向工作流**
- APK 静态分析（jadx/apktool 反编译）
- 动态 Hook（Frida/Xposed 运行时拦截）
- Native 层逆向（IDA/radare2 .so 分析）
- Unity/Unreal 游戏引擎逆向
- Windows DLL 注入

**2. 实战模板库**
- 绕过检测模板（Root/SSL Pinning/反调试）
- Hook 模板（Java层/Native层）
- 加密算法分析模板
- Smali 修改速查表

**3. 自我提升机制**
- field-journal：详细任务复盘记录
- memory：结构化经验积累
- 每次任务后自动学习踩坑经验

**4. 本地化适配**
- 针对 Windows 环境优化
- D 盘工具链配置
- MinGW/Rust 编译环境集成

### 为什么独特？

| 特性 | 普通 skill | WYX Skill |
|------|-----------|-----------|
| 工作流 | 静态模板 | 动态工作流 + 自动路由 |
| 经验积累 | 无 | field-journal + memory 双系统 |
| 隐私保护 | 全公开 | 代码开源，经验私有 |
| 环境适配 | 通用 Linux | Windows 本地化配置 |
| 脚本集成 | 无 | PowerShell 一键脚本 |

### 适用场景

- CTF 逆向挑战
- 授权渗透测试
- 个人应用安全研究
- 游戏外挂开发学习
- 恶意软件分析

### 技术栈

```
反向工程：jadx, apktool, IDA Pro, Ghidra, radare2
动态分析：Frida, x64dbg, Process Hacker
Unity/Unreal：Il2CppDumper, UE4SS
编译工具：Rust (windows crate), MinGW-w64
自动化：PowerShell 脚本集成
```

### 开源策略

本 skill 采用**代码开源 + 经验私有**的策略：

- ✅ **公开**：工作流模板、脚本、参考文档
- ❌ **私有**：field-journal、具体经验记录
- 📝 **索引**：MEMORY.md（经验文件列表，可公开）

下载者获得的是**工作流能力**，而非**实战经验**。每个用户只能积累自己的经验。

---

### 安装

```bash
git clone <repo-url> ~/.claude/skills/WYX
# 在 Claude Code 中使用 /WYX 触发
```

### 快速体验

```
1. 打开 Claude Code
2. 输入 /WYX
3. 描述你的目标（APK 文件路径或游戏名称）
4. AI 自动路由到对应工作流
```

---

**作者：海鸥**  
**GitHub**: [链接]  
**许可证**: MIT
