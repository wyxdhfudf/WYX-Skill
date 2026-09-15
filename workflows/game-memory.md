# 游戏内存分析工作流

> Unity/UE4游戏内存分析、自瞄、透视、无后座开发指南

---

## Phase 0: 游戏识别

### 0.1 确定游戏引擎

```powershell
# 方法1: 查看包名
$manifest = Get-Content "apktool_out\AndroidManifest.xml" -Raw
if ($manifest -match 'il2cpp') { Write-Host "Unity IL2CPP游戏" }
if ($manifest -match 'unity3d') { Write-Host "Unity Mono游戏" }

# 方法2: 查看资源目录
if (Test-Path "apktool_out\assets\Managed") { Write-Host "Unity游戏（有Managed目录）" }

# 方法3: 查看.so文件
Get-ChildItem "apktool_out\lib" -Recurse -Filter "*.so" | ForEach-Object {
    Write-Host "$($_.Name)"
    if ($_.Name -match 'il2cpp') { Write-Host "  → Unity IL2CPP" }
    if ($_.Name -match 'UE4|Unreal') { Write-Host "  → Unreal Engine" }
}
```

### 0.2 确定游戏类型

| 游戏类型 | 典型特征 | 分析重点 |
|---------|---------|---------|
| FPS（和平精英/PUBG） | 射击、视野、地图 | 自瞄、透视、地图挂 |
| MOBA（王者荣耀） | 英雄、技能、小地图 | 自动技能、免冷却、全图视野 |
| RPG（原神） | 角色、副本、抽卡 | 自动战斗、抽卡分析、资源修改 |
| 吃鸡类 | 缩圈、搜刮、战斗 | 安全区提示、敌人高亮、自动压枪 |

---

## Phase 1: 内存结构定位

### 1.1 Entity List定位

#### Unity IL2CPP游戏

```javascript
// 搜索策略1: 字符串搜索
// 在IL2CPP dump的metadata中搜索：
// - "players"
// - "entities"
// - " heroes"
// - "units"

// 搜索策略2: 类名搜索
// 典型类名模式：
// - PlayerController
// - GameManager
// - EntityManager
// - BattleManager

// 搜索策略3: 静态字段搜索
// 在IDA中搜索：
// - "m_Instance"
// - "s_Instance"
// - "Instance"
```

**Unity Entity List典型结构**:
```cpp
class CEngineClient {
public:
    char pad_0x0000[0x4];           // 0x00
    CBaseEntity* m_pLocalPlayer;    // 0x04 本地玩家
    char pad_0x0008[0x1FC];         // 0x08
    CBaseEntity* m_pEntList[64];    // 0x204 实体列表
};
// 基址: 0x8F6994 (示例)
```

#### UE4游戏

```javascript
// 搜索策略: GWorld和OwningGameInstance
// UE4::UGameplayStatics::GetPlayerController()
// UE4::UWorld::PersistentLevel
// UE4::APlayerController::AcknowledgeDeath
```

**UE4 GameMode典型结构**:
```cpp
class AGameModeBase {
public:
    TArray<AActor*> AllActors;      // 所有演员
    APlayerController* PlayerList;  // 玩家列表
};
```

### 1.2 Bone Matrix定位

#### Unity游戏

```javascript
// 搜索策略: Transform和Bone相关
// - "GetBoneTransform"
// - "GetBonePosition"
// - "boneMatrix"
// - "BindPose"

// IL2CPP方法签名：
// UnityEngine.Transform::GetBoneTransform(int32_t)
// UnityEngine.AnimationUtility::CalculateBoneMatrix(...)
```

**Bone结构典型偏移**:
```cpp
class CBaseEntity {
public:
    Vector3 m_vecOrigin;            // 0x008C 原点和尺寸
    Matrix3x4 m_ModelToWorld;       // 0x0260 模型矩阵
    int m_iHealth;                  // 0x0288 生命值
    int m_iTeamNum;                 // 0x028C 队伍号
    CHandle m_hOwnerEntity;         // 0x0290 所有者
    bool m_bDrawModel;              // 0x0294 是否绘制
    bool m_bSimulatedEveryTick;     // 0x0295 每帧模拟
    bool m_bAnimatedEveryTick;      // 0x0296 每帧动画
    bool m_bStartupAnimation;       // 0x0297 启动动画
};
```

#### UE4游戏

```javascript
// 搜索策略: SkeletalMesh和Socket
// - "USkeletalMeshComponent"
// - "GetSocketLocation"
// - "GetSocketTransform"
// - "AnimScriptInstance"
```

### 1.3 Camera Position定位

```javascript
// Unity搜索策略
// - "Camera.main"
// - "mainCamera"
// - "GetMainCamera"
// - "m_RenderTexture"

// UE4搜索策略
// - "UGameplayStatics::GetPlayerCameraManager"
// - "FMinimalViewInfo"
// - "ProjectWorldToScreen"
```

**Camera结构典型偏移**:
```cpp
class VMatrix {
public:
    float m[4][4];
};

class C_CSPlayerResource {
public:
    Vector3 m_vecViewOffset;      // 0x0000 视角偏移
    QAngle m_angEyeAngles;        // 0x000C 眼睛角度
    float m_flFOV;                // 0x0018 FOV
    float m_flDefaultFOV;         // 0x001C 默认FOV
};
```

### 1.4 Screen Size定位

```powershell
# 在jadx中搜索分辨率相关代码
Get-ChildItem target\jadx -Recurse -Include "*.java" | Select-String -Pattern "getDisplayHeight|getDisplayWidth|screenHeight|screenWidth" -List
```

**典型值**:
- Android: `Resources.getSystem().getDisplayMetrics().heightPixels`
- Unity: `Screen.height` / `Screen.width`
- UE4: `UGameplayStatics::GetPlayerPawn` → `GetViewPortSize`

---

## Phase 2: 基础功能实现

### 2.1 ESP透视

#### Rust实现模板

```rust
use std::ptr;

#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct Vector {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct Matrix {
    pub m: [[f32; 4]; 4],
}

impl Matrix {
    pub fn transform(&self, v: &Vector) -> Vector {
        Vector {
            x: self.m[0][0] * v.x + self.m[0][1] * v.y + self.m[0][2] * v.z + self.m[0][3],
            y: self.m[1][0] * v.x + self.m[1][1] * v.y + self.m[1][2] * v.z + self.m[1][3],
            z: self.m[2][0] * v.x + self.m[2][1] * v.y + self.m[2][2] * v.z + self.m[2][3],
        }
    }

    pub fn w_component(&self, v: &Vector) -> f32 {
        self.m[3][0] * v.x + self.m[3][1] * v.y + self.m[3][2] * v.z + self.m[3][3]
    }
}

// W2S投影
pub fn world_to_screen(world: &Vector, matrix: &Matrix, screen_width: u32, screen_height: u32) -> Option<Vector> {
    let transposed = transpose(matrix);
    let v = transposed.transform(world);
    
    if v.w <= 0.0 {
        return None; // 在camera后面
    }
    
    let mut screen = Vector {
        x: (screen_width as f32 / 2.0) * (1.0 + v.x / v.w),
        y: (screen_height as f32 / 2.0) * (1.0 - v.y / v.w),
        z: v.z / v.w,
    };
    
    Some(screen)
}

fn transpose(m: &Matrix) -> Matrix {
    Matrix {
        m: [
            [m.m[0][0], m.m[1][0], m.m[2][0], m.m[3][0]],
            [m.m[0][1], m.m[1][1], m.m[2][1], m.m[3][1]],
            [m.m[0][2], m.m[1][2], m.m[2][2], m.m[3][2]],
            [m.m[0][3], m.m[1][3], m.m[2][3], m.m[3][3]],
        ],
    }
}
```

### 2.2 自瞄基础

```rust
// 自瞄核心逻辑
pub struct Aimbot {
    pub target_offset: i32,        // 目标偏移
    pub bone_id: i32,              // 骨骼ID（0=head, 1=neck, 2=chest）
    pub smooth: f32,               // 平滑度
    pub fov: f32,                  // 视野范围
}

impl Aimbot {
    pub fn find_best_target(&self, entities: &[Entity], camera: &Camera) -> Option<Entity> {
        let mut best_target = None;
        let mut best_score = f32::MAX;
        
        for entity in entities {
            if !entity.is_alive() || entity.is_teammate() {
                continue;
            }
            
            let screen_pos = world_to_screen(&entity.position, &camera.view_matrix, 1920, 1080)?;
            let center = Vector { x: 960.0, y: 540.0, z: 0.0 };
            let distance = distance_2d(&screen_pos, &center);
            
            if distance < self.fov && distance < best_score {
                best_score = distance;
                best_target = Some(entity.clone());
            }
        }
        
        best_target
    }
    
    pub fn smooth_aim(&self, current: &mut f32, target: f32, delta_time: f32) {
        let diff = target - current;
        let step = diff * self.smooth * delta_time;
        *current += step;
    }
}
```

### 2.3 无后座实现

```rust
// 无后座核心逻辑
pub struct NoRecoil {
    pub base_recoil: f32,          // 基础后坐力
    pub compensation: f32,         // 补偿量
}

impl NoRecoil {
    pub fn calculate_compensation(&self, fire_rate: f32, weapon_type: &str) -> f32 {
        // 根据武器类型和射速计算补偿
        match weapon_type {
            "ak47" => self.base_recoil * 0.85,
            "m4a1" => self.base_recoil * 0.75,
            "awm" => self.base_recoil * 0.95,
            _ => self.base_recoil * 0.80,
        }
    }
    
    pub fn apply_compensation(&self, current_pitch: &mut f32, delta_time: f32) {
        *current_pitch -= self.compensation * delta_time;
    }
}
```

---

## Phase 3: 高级功能

### 3.1 健康条绘制

```rust
pub struct HealthBar {
    pub entity: Entity,
    pub screen_pos: Vector,
    pub health: i32,
    pub max_health: i32,
}

impl HealthBar {
    pub fn draw(&self, canvas: &mut Canvas) {
        let bar_width = 2.0;
        let bar_height = 50.0;
        let x = self.screen_pos.x - bar_width / 2.0;
        let y = self.screen_pos.y;
        
        // 背景
        canvas.draw_rect(x, y, bar_width, bar_height, Color::BLACK);
        
        // 血量
        let health_height = (self.health as f32 / self.max_health as f32) * bar_height;
        let health_color = if self.health > 50 {
            Color::GREEN
        } else if self.health > 25 {
            Color::YELLOW
        } else {
            Color::RED
        };
        canvas.draw_rect(x, y + bar_height - health_height, bar_width, health_height, health_color);
        
        // 血量文字
        let text = format!("{} HP", self.health);
        canvas.draw_text(x + bar_width + 2.0, y, &text, Color::WHITE);
    }
}
```

### 3.2 姓名显示

```rust
pub struct PlayerName {
    pub entity: Entity,
    pub screen_pos: Vector,
    pub name: String,
    pub distance: f32,
}

impl PlayerName {
    pub fn draw(&self, canvas: &mut Canvas) {
        let text = format!("{} {:.1}m", self.name, self.distance);
        canvas.draw_text(self.screen_pos.x, self.screen_pos.y - 10.0, &text, Color::CYAN);
    }
}
```

### 3.3 线框透视

```rust
pub struct WireframeESP {
    pub entity: Entity,
    pub screen_positions: [Vector; 8],  // 8个顶点
}

impl WireframeESP {
    pub fn draw(&self, canvas: &mut Canvas) {
        let lines = [
            (0, 1), (1, 3), (3, 2), (2, 0),  // 底面
            (4, 5), (5, 7), (7, 6), (6, 4),  // 顶面
            (0, 4), (1, 5), (2, 6), (3, 7),  // 垂直线
        ];
        
        for (i, j) in lines {
            canvas.draw_line(
                self.screen_positions[i],
                self.screen_positions[j],
                Color::WHITE,
            );
        }
    }
}
```

---

## Phase 4: 性能优化

### 4.1 帧率优化

```rust
pub struct GameLoop {
    pub target_fps: u32,
    pub frame_time: f32,
    pub last_time: Instant,
}

impl GameLoop {
    pub fn tick(&mut self) {
        let now = Instant::now();
        let elapsed = now.duration_since(self.last_time).as_secs_f32();
        
        // 限制帧率
        if elapsed >= self.frame_time {
            self.update();
            self.render();
            self.last_time = now;
        }
    }
    
    pub fn update(&mut self) {
        // 更新游戏状态
    }
    
    pub fn render(&mut self) {
        // 渲染ESP
    }
}
```

### 4.2 内存优化

```rust
// 使用对象池避免频繁分配
pub struct EntityPool {
    pub pool: Vec<Entity>,
    pub used: Vec<Entity>,
}

impl EntityPool {
    pub fn get(&mut self) -> Option<Entity> {
        self.pool.pop()
    }
    
    pub fn release(&mut self, entity: Entity) {
        self.pool.push(entity);
    }
}
```

---

## Phase 5: 测试验证

### 5.1 功能测试清单

```markdown
- [ ] ESP绘制正常，不闪烁
- [ ] 自瞄平滑，不抖动
- [ ] 无后座有效，子弹轨迹稳定
- [ ] 帧率稳定在60fps以上
- [ ] 内存占用低于100MB
- [ ] 无崩溃、无卡顿
- [ ] 不被游戏检测（如有反作弊）
```

### 5.2 性能测试

```powershell
# 监控内存和CPU
tasklist /FI "IMAGENAME eq game.exe" /V
tasklist /FI "IMAGENAME eq cheat.dll" /V

# 帧率监控
# 使用MSI Afterburner或fraps
```

---

## 常见问题

### Q1: 找不到Entity List基址怎么办？
```
解决方案：
1. 使用Cheat Engine扫描已知值（如玩家数量）
2. 搜索包含"entity"的字符串
3. 搜索"GetPlayer"相关函数
4. 分析游戏主循环，找Update调用位置
```

### Q2: Bone Matrix偏移不对怎么办？
```
解决方案：
1. 使用IDA查看骨骼动画函数
2. 搜索"GetBoneMatrix"或"SetupBones"
3. 分析AnimState结构
4. 对比不同游戏的Bone结构差异
```

### Q3: W2S投影不准确怎么办？
```
解决方案：
1. 检查Camera矩阵是否正确
2. 确认屏幕分辨率是否正确获取
3. 验证投影公式（不同游戏可能有差异）
4. 添加边界检查（防止透视到屏幕外）
```

---

## 相关资源

- [experience-database.md](../references/experience-database.md) - DPI、v8崩溃等实战经验
- [build-dll.ps1](../scripts/build-dll.ps1) - DLL编译脚本
- [ Il2CppDumper](https://github.com/abdullahalriyaz/Il2CppDumper) - Unity SDK生成
- [UE4SS](https://github.com/UULib/UE4SS) - UE4逆向框架

---

**版本**: 1.0
**最后更新**: 2026-09-13
