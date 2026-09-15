# WYX Skill - 自我提升使用说明

## 如何让skill拥有个人经验

WYX skill的"自我提升"能力依赖于 **field-journal** 和 **memory** 两个目录。

### 下载者如何获得提升能力：

```bash
# 1. 克隆skill仓库
git clone https://github.com/yourname/WYX-skill.git ~/.claude/skills/WYX

# 2. 运行任务，让AI自动积累（或手动写入）
# 每次完成任务后，说："把这次经验记录到memory里"

# 3. 下次任务时，AI会自动读取memory
# 基于之前的经验做出更准确的判断
```

### 经验积累机制：

| 层级 | 目录 | 作用 | 公开建议 |
|------|------|------|---------|
| 索引 | `memory/MEMORY.md` | 列出所有经验文件 | ✅ 可以公开 |
| 内容 | `memory/*.md` | 具体经验记录 | ❌ 建议私有 |
| 案例 | `field-journal/` | 详细任务复盘 | ❌ 必须私有 |
| 工作 | `work/` | 临时分析文件 | ❌ 必须私有 |

### 快速开始：

```bash
# 初始化本地记忆目录（如果不存在）
mkdir -p ~/.claude/skills/WYX/memory
mkdir -p ~/.claude/skills/WYX/field-journal
mkdir -p ~/.claude/skills/WYX/work

# 创建初始MEMORY.md
echo "- [开始积累经验](#) — 记录你的第一个任务" > ~/.claude/skills/WYX/memory/MEMORY.md
```

---

## 给贡献者的说明

如果你想贡献新的绕过模板或Hook脚本：
1. 修改 `workflows/` 或 `references/` 下的文件
2. 提交PR时**不要包含** `field-journal/` 和 `memory/*.md`
3. 经验文件是个人私有财产，请尊重作者的field-journal
