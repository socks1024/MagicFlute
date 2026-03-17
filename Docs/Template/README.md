# GODOT 简单项目模板

## 目录
- [x] 目录结构
- [x] 模板使用
- [x] 命名规范
- [x] 版本控制
- [x] 场景管理器
  - [x] 场景切换
  - [x] 带有加载界面的异步场景加载
- [ ] 存读档系统
  - [x] Config存档&读档
  - [ ] 序列化存档&读档
- [ ] Debug系统
  - [x] 增强Log（输出元数据）
  - [ ] CheatManager
- [x] 音频管理器
  - [x] Master Music SFX Voice等多音频总线设置
  - [x] 音频参数配置化
  - [x] 音效池（避免短时间播放多个音效导致前一个音效被切断）
  - [x] 带淡入淡出的背景音轨
- [x] 输入系统
  - [x] 输入配置
  - [x] 输入上下文（一组同时被激活的输入映射）
- [ ] UI组件库
  - [x] 基本界面
	- [x] 开始游戏界面
	- [x] 设置界面
	- [ ] 存档界面
	- [x] 制作者名单界面
  - [ ] 通用UI组件
	- [x] 按钮
	- [ ] 滑动条（Feel式）
  - [ ] 对话框
- [x] 相机功能（Phantom?）
- [ ] 视觉特效库
  - [x] shader（VisualShader or GDShader）
	- [x] 精灵图效果
	- [x] 后处理效果
  - [ ] 粒子
- [ ] 导表工具
- [ ] 编辑器工具（更多属性编辑器等）
- [x] 本地化配置框架
- [ ] 调研其他Godot插件
  - [ ] 已集成至模板的插件
  - [ ] 可用于特定游戏内容的推荐插件

总体完成度：27/43

---

## 模板使用

打开 Godot 项目列表页面，提供新名称并复制模板项目。

复制模板项目后，可以运行 res://Editor/Template/init_new_project.gd 来进行项目初始化。

目前的初始化流程：
- 移除.git文件夹。

---

## 目录结构

### addons

用于存放从网络下载的和自制的插件。

有关 Godot 中的插件，可以查看[官方文档中有关插件的页面](https://docs.godotengine.org/zh-cn/4.5/tutorials/plugins/index.html)。

因为一些插件可能会使用硬编码的路径，所以这个文件夹的名称目前是首字母小写的。

### Build

用于存放历史构建版本。

历史构建版本按照平台、版本号分类，并单独打包到一个文件夹中，文件夹命名格式为 MyProject-win-v0.1.0 。

有关语义化版本号，可以查看[这个网站](https://semver.org/lang/zh-CN/)（为什么会有一个专门的网站介绍语义化版本号）。

### Content

用于存放游戏内容。

这个文件夹中包含：
- Art 文件夹（用于存放美术资产）
- Data 文件夹（用于存放配置数据）
- Scene 文件夹（用于存放场景文件）
- Script 文件夹（用于存放代码脚本）

并非所有的代码都需要放在 Script 文件夹下。对代码的管理可以遵循以下的混合式原则：

与场景同目录或子scripts目录（紧耦合）：
1. 脚本名与场景名相同（除扩展名）
2. 脚本只被该场景使用
3. 脚本包含场景特定的节点硬引用

放在scripts文件夹（松耦合）：
1. 脚本被多个场景使用
2. 脚本是工具类/工具函数
3. 脚本定义基类或接口

### Docs

用于存放游戏的文档。

不一定需要把策划案放在这里，不过建议把程序文档放在这里，比较省事。

给 AI Agent 看的文档可以放在 Docs/Agent 下。

### Editor

用于存放那些不能算是一个插件，但是又需要用到的编辑器扩展脚本。

### Test

用于存放测试用的东西。

这里的东西应当可以随时被删除且不影响游戏运行。（如果删掉之后游戏跑不起来了，说明你该睡觉了。）

---

## 命名规范

Godot 的命名主要使用 PascalCase 和 snake_case 。
- 文件夹使用 PascalCase
- 资产、场景、GDS脚本等使用 snake_case
- 节点名、GDS类名使用 PascalCase
- GDS常量名使用 UPPER_SNAKE_CASE
- GDS变量、函数、信号使用 snake_case，私有成员需要在前面额外加下划线

不需要在资产名称前加类型标识符，文件夹结构会负责做这件事情的。

---

## 版本控制

版本控制使用 Git。云端仓库可以使用 Github，不过这个无所谓。

版本控制需要每个工程单独配置，无法在模板中配置。

工程内已经配置好了基本的 gitignore，可以直接使用。

需要注意的是，Git会自动忽略空文件夹，所以提交时需要放一些占位资产。

---

## 场景管理器

场景管理器由 `SceneUtils` 工具类和 `LoadControl` 加载界面基类组成，提供场景切换和带加载界面的异步加载功能。

### SceneUtils

`SceneUtils` 是处理场景相关逻辑的静态工具类。

**核心方法：**

- `quick_instantiate(parent: Node, p_scene: PackedScene, init_callable = null)` - 快速实例化场景，具有可选的初始化回调函数，接收一个 Node 作为参数

- `switch_scene_by_path(from_scene: Node, to_scene_path: String)` - 直接切换场景

- `switch_scene_by_load_control(from_scene: Node, to_scene_path: String, load_scene_path: String, min_load_time: float = -1, confirm_time: float = -1)` - 通过加载界面切换场景
  - `from_scene` - 当前场景节点，将被释放
  - `to_scene_path` - 目标场景的资源路径
  - `load_scene_path` - 加载界面场景的资源路径（需要继承 `LoadControl`）
  - `min_load_time` - 最小加载时间（秒），用于确保加载界面至少显示一定时间
  - `confirm_time` - 加载完成后的确认等待时间（秒）

### LoadControl

`LoadControl` 是加载界面的抽象基类，使用 Godot 的多线程资源加载功能实现异步加载。

**核心信号：**

- `load_finish(res)` - 加载完成时发出，携带加载好的 PackedScene 资源

**抽象方法：**

- `_init_progress_control()` - 初始化进度显示控件（如进度条）
- `_update_progress_control(value: float)` - 更新进度显示（value 范围 0.0 ~ 1.0）
- `_free_progress_control()` - 释放进度控件/加载界面

---

## 存读档系统

### Config 存档 & 读档

配置存档系统由 `ConfigUtils` 工具类和 `SettingsManager` 管理器组成，用于持久化存储游戏设置。

#### ConfigUtils

`ConfigUtils` 是一个静态工具类，封装了 Godot 的 `ConfigFile` API。
该工具类默认将config文件存储在 user://config.cfg 位置。

**核心方法：**

- `save_setting(section: String, key: String, default = null)` - 将设置保存到配置文件

- `load_setting(section: String, key: String, default = null) -> Variant` - 从配置文件加载设置

- `has_section(section: String) -> bool` - 检查是否存在某个配置分类

- `has_section_key(section: String, key: String) -> bool` - 检查是否存在某个配置项

- `erase_config()` - 删除整个配置文件

- `erase_section(section: String)` - 删除某个配置分类

- `erase_section_key(section: String, key: String)` - 删除某个配置项

- `get_keys_by_section(section: String) -> PackedStringArray` - 获取某个分类下的所有配置项名称

#### ConfigControl

`ConfigControl` 是配置控件的抽象基类。
加入场景树时，控件会加载默认值并显示。
用户修改控件时，新的值会被自动保存到配置，并发出 `config_changed` 信号。可以通过该类的派生类来创建具体的配置控件，如绑定音量的滑动条。。

**核心属性：**

- `config_section: String` - 配置分类
- `config_key: String` - 配置项名称

**核心信号：**

- `config_changed(value)` - 配置更改时发出

**抽象方法：**

- `get_default_value() -> Variant` - 获取默认值
- `set_control_value(value: Variant)` - 更新控件显示的值
- `set_control_editable(editable: bool)` - 设置控件是否可编辑
- `connect_control_input()` - 连接控件的输入信号

#### SettingsManager

`SettingsManager` 是一个 AutoLoad 单例，负责管理所有游戏设置的加载、保存和重置。

**支持的配置分类：**

1. **Audio：** - 音频设置
   - 管理所有音频总线的音量
   - `get_bus_volume_db(bus_name: String) -> float` - 获取总线音量
   - `set_bus_volume_db(bus_name: String, volume_db: float)` - 设置总线音量
   - `mute_bus(bus_name: String, mute: bool)` - 静音/取消静音

2. **Input：** - 输入设置
   - 保存和加载自定义按键映射
   - `get_action_names() -> Array` - 获取所有非内置的 InputAction 名称
   - `get_event_dic(action_name: String) -> Dictionary` - 获取某个动作的输入事件字典
   - `set_input_events(action_name: String, events: Array)` - 设置某个动作的输入事件

3. **Video：** - 视频设置
   - `toggle_full_screen(value: bool)` - 切换全屏模式

4. **Game：** - 游戏设置
   - `set_locale_by_lang(lang: LocalizationUtils.Lang)` - 设置游戏语言

**其他核心方法**

- `reset_all_settings()` - 删除配置文件并重置所有设置为默认值

## Debug系统

### Log

使用了插件 CLog by Anchork。

可以在 Addons/clog 下查看插件的代码和文档。

**改进记录：**
- 修复了 `SOURCE_LINK_COLOR` HDR颜色值被截断的问题
  - 问题：当编辑器主题设置中的 `safe_line_number_color` 包含HDR颜色值（超过1.0）时，生成的 `SOURCE_LINK_COLOR` 也会包含HDR值，导致被 `to_html()` 方法截断为纯白色
  - 解决方案：在 `clog_editor_plugin.gd` 的 `_generate_colors_class_file()` 方法中添加HDR颜色检查机制，确保自动生成的 `SOURCE_LINK_COLOR` 值始终在合理范围内（0.0-1.0）
  - 修复版本：2026-03-06

### CheatManager

还在施工中。

---

## 音频系统

音频系统由三个核心类组成：`AudioEvent`（音频事件资源）、`AudioEventPlayer`（音频播放器）和 `AudioManager`（音频管理器）。
音频系统不与程序的其他部分（如音量设置）耦合，如果需要换用其他音频系统（如 FMOD for Godot），仅需禁用 AutoLoad 中的 AudioManager。

### AudioEvent

`AudioEvent` 是一个资源类，用于定义音频事件的各种属性。

**核心属性：**

- `name` - 音频事件的唯一名称，用于标识和查询播放器
- `audio_stream` - 基础的 AudioStream 资源
- `is_loop` - 是否循环播放
- `priority` - 优先级（0-100，数值越小优先级越高）
- `bus` - 音频总线名称，用于音量控制和效果链
- `volume` - 音量（相对于总线的偏移，单位 dB）
- `random_volume_range` - 音量随机范围，产生变化效果
- `pitch` - 音调缩放（0.01-4）
- `random_pitch_range` - 音调随机范围
- `variants` - 变体列表，用于播放不同的音频资源

**核心方法：**

- `get_random_audio_stream()` - 返回一个随机的 AudioStream 资源（从变体列表或基础资源中随机选择）
- `get_random_volume_db()` - 返回应用随机范围后的最终音量
- `get_random_pitch_scale()` - 返回应用随机范围后的最终音调

### AudioEventPlayer

`AudioEventPlayer` 是 `AudioStreamPlayer` 的增强版本，专门用于播放 `AudioEvent` 资源。它不保存音频数据，而是通过 AudioEvent 资源来配置播放参数。

**核心方法：**

- `play_audio(event: AudioEvent = null)` - 播放音频事件，自动应用 AudioEvent 中配置的所有参数
- `pause_audio()` - 暂停播放，保持当前位置
- `stop_audio(clear_event: bool = false)` - 停止播放，可选清除配置的事件
- `fade_in(fade_time: float, callback = null)` - 淡入播放，可指定淡入时间和完成回调
- `fade_out(fade_time: float, callback = null)` - 淡出停止，可指定淡出时间和完成回调

### AudioManager

`AudioManager` 是一个全局管理器，负责协调所有音频的播放。它维护两个播放器池：

1. **音效池（Sound Pool）** - 用于播放音效，有容量限制（默认16个），超出时会移除优先级最低的
2. **音乐轨道（Music Tracks）** - 用于管理多个音乐轨道，支持交叉淡入淡出

**核心方法：**

- `play_sound(event: AudioEvent)` - 播放音效
  
- `play_music(event: AudioEvent, track_name: StringName, fade_time: float = 1.0, cross_fade: bool = false)` - 播放音乐
  - `track_name` - 音乐轨道名称（用于区分不同的音乐层或背景音）
  - `fade_time` - 淡入/淡出时间
  - `cross_fade` - 是否使用交叉淡入淡出效果
  
- `get_player_by_event_name(event_name: StringName) -> AudioEventPlayer` - 根据事件名称查找正在播放的播放器

---

## 输入系统

本项目的输入系统采用 Godot 内置输入映射和 `InputContext` 的双层架构：

在项目设置中配置输入映射作为默认输入，通过输入设置来变更每个 `InputActionEvent` 对应的激活方式；在 `InputManager` 中动态启用和禁用 `InputContext`，来控制哪些 `InputActionEvent` 可以传递到游戏逻辑中。

### InputUtils

`InputUtils` 是一个静态工具类，提供输入事件处理的辅助功能。

**设备检测：**

- `has_joypad() -> bool` - 检查是否连接了手柄
- `is_joypad_event(event: InputEvent) -> bool` - 检查是否为手柄事件
- `is_mouse_event(event: InputEvent) -> bool` - 检查是否为鼠标事件
- `get_device_name(event: InputEvent) -> String` - 获取设备名称

**输入显示：**

- `get_text(event: InputEvent) -> String` - 将 InputEvent 转换为用户友好的字符串
- `get_device_specific_text(event: InputEvent, device_name: String = "") -> String` - 获取设备特定的按键文本

**内置常量：**

- `DEVICE_KEYBOARD`、`DEVICE_MOUSE`、`DEVICE_XBOX_CONTROLLER` 等设备名称常量
- `JOYPAD_BUTTON_NAME_MAP` - 不同手柄的按键名称映射
- `JOY_BUTTON_NAMES` - 手柄按钮通用名称
- `BUILT_IN_ACTION_NAME_MAP` - 内置 UI 动作的友好名称映射

**辅助方法：**

- `not_internal_ui_action(action_name: StringName) -> bool` - 判断是否为非内置 UI 动作（用于过滤 `ui_` 前缀的动作）

### InputButton

`InputButton` 是一个输入捕获按钮，继承自 `CommonButton`，新增了捕获输入并显示在按钮上的功能。不会捕捉鼠标移动输入。

**核心属性：**

- `initial_text: String` - 初始显示文本
- `waiting_text: String` - 等待输入时显示的文本
- `catch_mouse_move: bool` - 是否捕获鼠标移动
- `joypad_motion_deadzone: float` - 手柄摇杆死区（0-1）
- `mouse_motion_deadzone: float` - 鼠标移动死区

**核心信号：**

- `input_catched(event: InputEvent)` - 捕获到输入时发出

### InputContext（输入上下文资源）

`InputContext` 是一个 `Resource`，描述一组应当同时激活或同时禁用的 InputAction。

**属性：**
- `context_name: StringName` — 上下文的唯一标识名称（如 `&"gameplay"`、`&"dialogue"`）
- `include_ui_actions: bool` — 是否在 `actions` 下拉枚举中显示 Godot 内置的 `ui_` Action（默认 `false`）
- `actions: Array[StringName]` — 该上下文包含的 InputAction 名称列表

### InputManager（输入管理器）

`InputManager` 是一个 AutoLoad 单例，负责管理所有上下文的激活状态。

它维护一个**上下文集合（Context Set）**，集合中所有上下文的 Actions 均处于激活状态。

#### 核心方法

- `add_context(context: InputContext)` — 将一个上下文加入集合，其 Actions 立即生效
- `remove_context(context_name: StringName)` — 按名称从集合中移除上下文，该上下文的 Actions 不再生效
- `clear_context()` — 清空上下文集合，禁用所有 InputAction
- `get_active_actions() -> Array[StringName]` — 获取当前所有激活上下文中的 Actions 合集
- `is_context_active(context_name: StringName) -> bool` — 检查某个上下文是否在集合中

#### 核心信号

- `context_added(added: InputContext)` — 有上下文被加入集合时发出
- `context_removed(removed: InputContext)` — 有上下文被移除集合时发出

#### 默认行为

`InputManager` 在 `_ready()` 时会预加载一个默认的 UI 上下文（`UI_CONTEXT`，对应 `ui_context.tres`），并自动调用 `add_context()` 将其加入集合。这确保了所有 `ui_` 前缀的内置 Action（如 `ui_accept`、`ui_cancel` 等）在游戏启动后立即可用，无需手动添加。

#### 注意事项

1. **内置 UI 动作也受管理**：`ui_accept`、`ui_cancel`、`ui_up`、`ui_down` 等 `ui_` 前缀的内置动作同样纳入 `InputManager` 的管理范围。`InputManager` 在 `_ready()` 时会自动预加载并添加一个默认的 UI 上下文（`UI_CONTEXT`），确保 `ui_` 系列 Action 开箱即用。如需在某些场景下屏蔽 UI 输入，只需 `remove_context` 移除该 UI 上下文即可。

2. **上下文集合为空时的行为**：当上下文集合为空时，**所有** InputAction（包括 `ui_` 前缀的内置 Action）均被禁用。由于 `InputManager` 默认添加了 UI 上下文，正常情况下集合不会为空。

3. **多上下文叠加**：集合中所有上下文的 Actions 取并集同时生效。例如同时加入 `gameplay` 和 `ui` 上下文，两者的 Actions 均可响应。`remove_context` 按名称精确移除，不影响集合中其他上下文。

4. **与 SettingsManager 的初始化顺序**：`InputManager` 应在 `SettingsManager` 之后初始化，确保用户自定义按键映射已加载完毕后再进行上下文切换。

---

## UI 组件库

### 基本界面

模板提供了以下预制界面：

**开始游戏界面：** - `Content/Scene/UI/Menus/Start/`
- 游戏入口界面，包含开始游戏、设置、退出等按钮

**设置界面：** - `Content/Scene/UI/Menus/Settings/`
- 包含音频、视频、输入等设置选项卡
- 输入设置自动生成所有自定义动作的按键配置控件

**制作者名单界面：** - `Content/Scene/UI/Menus/Credit/`
- 显示游戏制作团队信息

### 通用 UI 组件

#### Common Button

`CommonButton` 是一个带有按下动画和音效的增强按钮。

**核心属性：**

- `duration: float` - 动画持续时间
- `ease_curve: Curve` - 动画缓动曲线
- `press_sound: AudioEvent` - 按下时播放的音效

**核心信号：**

- `button_anim_finish` - 按钮动画播放完成时发出

## 视觉特效库

### 精灵图效果

精灵图效果是作用于单个节点（Sprite2D、TextureRect 等）的 Shader，通过 `ShaderMaterial` 挂载使用。

#### Color — 基础颜色

将精灵所有不透明像素替换为指定的纯色，适用于角色死亡剪影、远景层叠、前景遮挡、隐藏在障碍物后的角色轮廓显示等场景。

**参数：**

- `base_color` : Color = 黑色 (0,0,0,1) — 着色颜色
- `color_amount` : float (0.0 ~ 1.0) = 1.0 — 着色强度。0.0 = 原始颜色，1.0 = 完全着色

#### Dissolve — 溶解

使用噪声纹理驱动的溶解效果，可实现角色消失、场景切换等过渡动画。

**参数：**

- `dissolve_texture` : Sampler2D = 白色 — 溶解噪声纹理（推荐使用 NoiseTexture2D 或自定义灰度噪声图）
- `dissolve_amount` : float (0.0 ~ 1.0) = 0.0 — 溶解进度。0.0 = 完全显示，1.0 = 完全溶解
- `edge_color` : Color = 白色 (1,1,1,1) — 溶解边缘发光颜色
- `edge_width` : float (0.0 ~ 0.2) = 0.05 — 溶解边缘宽度，值越大发光边缘越宽
- `invert` : bool = false — 是否反转溶解方向。true = 从亮到暗溶解，false = 从暗到亮溶解

#### Outline — 轮廓线

在精灵边缘绘制描边/轮廓线效果，适用于角色选中高亮、卡通风格描边等场景。

**参数：**

- `enabled` : bool = false — 是否启用轮廓线效果
- `outline_color` : Color = 白色 (1,1,1,1) — 轮廓线颜色
- `outline_width` : float (0.0 ~ 10.0, 步长 0.5) = 1.0 — 轮廓线宽度（像素数），值越大描边越粗

#### DropShadow — 投影

在精灵下方绘制一个偏移的半透明投影副本，模拟投射阴影效果。

**参数：**

- `enabled` : bool = false — 是否启用投影效果
- `shadow_color` : Color = 半透明黑色 (0,0,0,0.5) — 投影颜色
- `shadow_offset` : Vector2 = (3.0, 3.0) — 投影偏移量（像素数）。x 正方向为右，y 正方向为下

### 后处理效果

后处理效果系统提供一套基于 2D Shader 的全屏后处理效果框架。

控制器脚本 `PostProcessController` 是一个工具脚本，挂载在后处理场景中的 `CanvasLayer` 根节点（layer=127，确保在最顶层渲染）上。

根节点会自动获取子节点上的所有后处理 shader，从而可以快速调节相关参数。

#### 内置效果一览

- **ChromaticAberration** — 色差偏移，模拟镜头色散
  - `chromatic_aberration`：偏移强度（0.0 ~ 10.0，默认 1.0）

- **Scanline** — 扫描线，模拟 CRT 显示器
  - `scanline_density`：扫描线密度（1.0 ~ 2000.0，默认 200.0）
  - `scanline_strength`：强度（0.0 ~ 1.0，默认 0.3）
  - `scroll_speed`：滚动速度（0.0 ~ 50.0，默认 3.0）

- **Flicker** — 屏幕闪烁，模拟老旧显示器
  - `flicker_strength`：闪烁强度（0.0 ~ 0.2，默认 0.02）
  - `flicker_speed`：闪烁速度（0.0 ~ 30.0，默认 8.0）

- **Brightness** — 整体亮度调节
  - `brightness`：亮度倍率（0.5 ~ 1.5，默认 1.0）

- **Vignette** — 暗角效果，画面边缘变暗
  - `vignette_strength`：暗角强度（0.0 ~ 2.0，默认 0.4）
  - `vignette_radius`：暗角半径（0.0 ~ 1.5，默认 0.8）

- **Bloom** — 泛光/辉光，提取高亮区域并高斯模糊后叠加，模拟光晕效果
  - `threshold`：亮度阈值（0.0 ~ 2.0，默认 0.8），高于此亮度的像素才会产生辉光
  - `intensity`：辉光强度（0.0 ~ 2.0，默认 0.5）
  - `blur_size`：模糊扩散范围（0.0 ~ 5.0，默认 1.5）
  - `blur_samples`：模糊采样数（1 ~ 12，默认 6），越高越平滑，性能消耗越大

- **Transition** — 场景过渡效果，使用灰度遮罩纹理实现各种过渡动画（圆形擦除、菱形过渡、像素溶解等）
  - `progress`：过渡进度（0.0 ~ 1.0，默认 0.0），0 = 完全显示原画面，1 = 完全覆盖
  - `smoothness`：过渡边缘柔和度（0.0 ~ 0.5，默认 0.05），值越大边缘越柔和
  - `cover_texture`：覆盖纹理，过渡完成后显示的图片（默认黑色；如需纯色过渡，指定一张纯色纹理即可）
  - `edge_color`：边缘发光颜色（默认透明），设置 alpha > 0 启用边缘发光
  - `edge_width`：边缘宽度（0.0 ~ 0.2，默认 0.03）
  - `invert`：反转过渡方向（0 或 1，默认 0）
  - `transition_texture`：灰度遮罩纹理，在检查器面板中直接设置即可，不同的灰度图产生不同的过渡效果
  
  **使用方式**：在检查器面板中设置 `transition_texture` 灰度遮罩图，然后通过 Tween 控制 `progress` 参数从 0→1 实现渐入，1→0 实现渐出。不同的灰度图可以产生不同的过渡效果（如径向擦除、水平擦除、菱形过渡、噪声溶解等）。

#### 运行时 API

`PostProcessController` 提供以下公共方法：

**开关控制：**

- `enable_all()` - 启用所有后处理效果
- `disable_all()` - 禁用所有后处理效果
- `enable_effect(effect_name: String)` - 启用指定效果（传入节点名，如 `"Vignette"`）
- `disable_effect(effect_name: String)` - 禁用指定效果

**参数控制：**

- `set_effect_param(effect_name: String, shader_param: String, value: Variant)` - 设置指定效果的 shader 参数
- `get_effect_param(effect_name: String, shader_param: String) -> Variant` - 获取指定效果的 shader 参数

**恢复默认值：**

- `reset_effect_param(effect_name: String, shader_param: String)` - 恢复指定效果的单个参数到默认值
- `reset_effect_params(effect_name: String)` - 恢复指定效果的所有参数到默认值
- `reset_all_params()` - 恢复所有效果的所有参数到默认值

**查询：**

- `get_effect_material(effect_name: String) -> ShaderMaterial` - 获取指定效果的 ShaderMaterial
- `get_effect_names() -> Array` - 获取所有效果名列表

#### 添加新效果

添加一个新的后处理效果只需两步：

**第 1 步：编写 Shader**

在 `shaders/` 目录下创建新的 `.gdshader` 文件。

**第 2 步：在场景中添加节点**

每个效果由一对节点组成：`BackBufferCopy`（用于拷贝屏幕内容）+ `ColorRect`（用于应用 Shader）。

打开 `post_processing.tscn`，在末尾添加一对节点：

1. 添加一个 `BackBufferCopy` 节点（`copy_mode` 设为 `Viewport`）
2. 添加一个 `ColorRect` 节点，命名为效果名称（如 `MyEffect`）
   - 为其创建 `ShaderMaterial`，赋予刚才编写的 Shader
   - 将 `anchors_preset` 设为全屏（Full Rect）
   - 将 `mouse_filter` 设为 `Ignore`

完成后控制器会自动扫描新节点，在检查器面板中生成对应的开关和参数，无需修改任何 GDScript 代码。

---

## 本地化配置框架

目前的本地化配置框架采用 Godot 内置的本地化翻译框架，以 csv 文件作为本地化资源。

### LocalizationUtils

`LocalizationUtils` 是一个静态工具类，提供与本地化相关的逻辑支持。

**语言枚举**

**核心方法：**

- `get_default_lang() -> Lang` - 根据系统语言获取默认语言

- `get_lang_by_locale(locale: String) -> Lang` - 将 Godot 本地化代码转换为语言枚举

- `get_locale_by_lang(lang: Lang) -> String` - 将语言枚举转换为 Godot 本地化代码

### 扩展语言支持

如需添加新语言：

1. 在 `LocalizationUtils.Lang` 枚举中添加新值
2. 在 `LANG_LOCALE` 常量字典中添加新的语言代码和本地化代码的映射
3. 重新导入 csv 文件，确保 Godot 本地化系统识别到了新语言

## 其他 Godot 插件

### 已集成插件

- Code Editor Switch：可以在内部编辑器和外部编辑器间快速切换。

### 已收集插件

- GAEA：程序化生成世界/地图
- GUIDE：输入检测配置【类似UE增强输入系统的方案，涉及到大量配置，比较复杂】
- Phantom：相机控制（类似Cinemachine）
- Dialogic：对话系统
- TODO Manager：TODO注释
- LimboAI：AI行为树
- Scene Manager：场景管理器【过于复杂。可能还是需要定制一个自己的。】
- FMOD GDExtension：接入FMOD的音频管理器
