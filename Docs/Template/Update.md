
# 可反向纳入模板的新功能

以下功能在当前项目（MagicFlute）中已实现，但模板中尚未包含，具有通用性，建议纳入模板。

---

## 1. Spring 弹簧动画系统

**路径：** `Content/Script/Animation/SpringVariant/`

**文件：** `spring_float.gd`、`spring_vector2.gd`、`spring_vector3.gd`、`README.md`

**说明：** 基于阻尼弹簧振荡器的弹性运动系统，提供 `SpringFloat`、`SpringVector2`、`SpringVector3` 三个变体，适用于位置、缩放、旋转等任何需要"弹弹的"手感的场景。

**核心 API：**
- `bump(amount)` — 给弹簧一个瞬间冲量
- `move_to(target)` — 弹性过渡到新目标值
- `move_to_additive(delta)` — 在当前目标上叠加偏移
- `restore_initial()` — 弹性回归初始值
- `stop()` / `finish()` / `reset()` — 停止/跳到目标/完全重置

**适用场景：** 受击反馈、UI 按钮弹性、跳跃挤压拉伸、相机跟随等。

---

## 2. 后处理控制器重构（抽象基类 + 2D/3D 分离）

**路径：** `Content/Art/Shader/PostProcess/`

**文件：**
- `post_process_controller_base.gd` — 抽象基类
- `PostProcess2D/post_process_2d_controller.gd` — 2D 后处理控制器
- `PostProcess3D/post_process_3d_controller.gd` — 3D 后处理控制器

**说明：** 将原来的单一 `PostProcessController` 重构为抽象基类 `PostProcessControllerBase`，子类只需实现 4 个抽象方法即可适配不同节点类型（2D 用 ColorRect，3D 用 MeshInstance3D）。所有效果扫描、检查器面板生成、参数管理、开关控制等逻辑统一在基类中。

**模板影响：** 原有的 2D 后处理控制器需要改为继承此基类的版本。

---

## 3. 3D 后处理效果系统

**路径：** `Content/Art/Shader/PostProcess/PostProcess3D/`

**文件：**
- `post_process_3d_controller.gd` — 3D 后处理控制器
- `post_processing_3d.tscn` — 3D 后处理场景
- `Shaders/post_process_outline.gdshader` — 3D 描边 Shader

**说明：** 基于 `PostProcessControllerBase` 的 3D 后处理效果系统。作为 Camera3D 的子节点使用，扫描 MeshInstance3D 子节点上的 ShaderMaterial。自动忽略 `DEPTH_TEXTURE` 和 `NORMR_TEXTURE` 等内置纹理参数。

**内置效果：**
- **Outline** — 基于深度和法线的 3D 描边效果，支持距离自适应粗细、掠射角防护，兼容移动端（可选法线重建模式）

---

## 4. 精灵图 Shader — InnerOutline（内轮廓线）

**路径：** `Content/Art/Shader/Sprite/Outline/inner_outline.gdshader`

**说明：** 在精灵不透明区域的**内侧**边缘绘制描边效果（模板中已有的 Outline 是外轮廓线）。原理是采样周围像素的 alpha 值，如果当前像素不透明但周围存在透明像素，则判定为边缘内侧。

**参数：**
- `enabled` : bool — 是否启用
- `outline_color` : Color — 轮廓线颜色
- `outline_width` : float (0.0 ~ 10.0) — 轮廓线宽度
- `alpha_threshold` : float (0.0 ~ 1.0) — 边缘判定的 alpha 阈值

---

## 5. 2D 网格系统（GridSystem2D + GridEntity2D）

**路径：** `Content/Script/Gameplay/GridSystem/`

**文件：** `grid_system_2d.gd`、`grid_entity_2d.gd`

**说明：** 通用的无限 2D 网格管理系统。以 Node2D 的 position 为原点，提供坐标转换、格子占用追踪、实体移动/阻挡/重叠检测等功能。网格无固定边界，可向任意方向延伸。配合 TileMapLayer 子节点（ZoneLayer + EntityLayer）实现地形数据查询和场景瓦片自动注册。

**核心功能：**
- **坐标转换** — `grid_to_world()` / `world_to_grid()`，网格坐标与世界坐标互转
- **占用追踪** — `place_entity()` / `remove_entity()` / `move_entity()`，O(1) 反向索引查表
- **碰撞系统** — 基于位掩码的 `grid_layer` / `block_mask` / `overlap_mask`，支持阻挡检测和重叠回调
- **多格实体** — `GridEntity2D.cell_size` 支持任意尺寸的实体占用
- **地形查询** — `get_cell_data()` / `get_cell_custom_data()` / `get_filtered_cells()`，读取 TileSet 的 Custom Data
- **编辑器工具** — `@tool` 模式下修改格子尺寸自动同步所有 TileMapLayer 的 TileSize

**信号：**
- `entity_placed` / `entity_removed` / `entity_moved` / `entity_blocked` / `entity_overlapped`

**GridEntity2D 虚方法（子类覆写）：**
- `_on_placed()` / `_on_removed()` / `_on_blocked()` / `_on_overlap()`

---

## 6. 精灵图 Shader — Curtain 幕布系列

**路径：** `Content/Art/Shader/Sprite/Curtain/`

**文件：**
- `curtain.gdshader` — 幕布飘动效果

### 6.1 Curtain（幕布飘动）

模拟布料/幕布的飘动效果，包含多层波浪形变、褶皱阴影和边缘柔化。

**参数：**
- 波浪：`wave_amplitude`、`wave_frequency`、`wave_speed`、`vertical_amplitude`
- 褶皱：`fold_intensity`、`fold_frequency`、`fold_shadow_color`、`fold_highlight_color`
- 悬挂：`top_weight`、`pin_top`

---

## 7. NodeUtils 工具类

**路径：** `Content/Script/Utils/node_utils.gd`

**新增方法：**
- `recursive_get_children(root: Node, include_internal = false) -> Array` — 深度优先递归遍历所有子孙节点并返回

---

## 8. TweenUtils 工具类

**路径：** `Content/Script/Utils/tween_utils.gd`

**新增方法：**
- `curve_interpolator(curve: Curve) -> Callable` — 将 Curve 资源转换为 Tween 可用的自定义插值器（返回一个 `func(t: float) -> float` 的 Callable）

---

## 9. 音频系统增强（AudioEventPlayer + AudioManager）

### 9.1 AudioEventPlayer 新增方法

**路径：** `Content/Script/Audio/audio_stream_player_enhanced.gd`

- `is_paused() -> bool` — 返回当前是否处于暂停状态
- `continue_audio() -> void` — 恢复暂停的播放（会重新随机音量）

### 9.2 AudioManager 变更

**路径：** `Content/Script/Audio/audio_manager.gd`

**重命名：**
- `play_music()` → `start_music()` — 函数名更语义化，且新增支持传入 `null` event 来淡出停止指定轨道

**新增方法：**
- `pause_music(track_name: StringName, fade_time: float = 0.5)` — 暂停指定音乐轨道，支持淡出效果（`fade_time <= 0` 时立即暂停）
- `continue_music(track_name: StringName, fade_time: float = 0.5)` — 恢复指定音乐轨道的播放

**模板影响：** 原模板中 `AudioManager.play_music()` 需重命名为 `start_music()`，并同步新增 `pause_music()` / `continue_music()` 两个方法。

---

## 10. CommonTextureButton（通用纹理按钮）

**路径：** `Content/Scene/UI/Common/Button/common_texture_button.gd`

**说明：** 继承 `TextureButton` 的通用按钮组件，按下时播放音效并执行缩放动画（通过 Curve 自定义缓动曲线），动画结束后发出信号。适用于需要统一按钮手感的 UI 场景。

**导出参数：**
- `duration` : float — 按下动画时长
- `ease_curve` : Curve — 自定义缓动曲线
- `press_sound` : AudioEvent — 按下音效

**信号：**
- `button_anim_finish` — 按钮动画播放完毕时触发

**备注：** 当前类设计较简单（硬编码缩放到 `Vector2.ZERO`、不支持自定义目标值等），纳入模板后需要优化重构。

!!!!!!!!!!!!!!!!!!!!!可以为每个UI界面加上显示和隐藏的回调
