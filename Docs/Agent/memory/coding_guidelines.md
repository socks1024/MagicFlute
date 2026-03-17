# AI 编码规范与常见错误避免

> 本文档用于指导 AI 在本项目中编写 GDScript / GDShader 代码时避免常见错误。
> 每当进行代码编写或修改时，请参考此文档中的规则。

---

## 一、总则

### 1. 注释语言

- 代码中的注释使用**中文**。

---

## 二、GDScript 规范

### 1. 自动类型推断 `:=`

- GDScript 使用 `:=` 进行自动类型推断，**仅当右值类型明确时使用**。
- ✅ 正确：`var key := "hello"`（右值是明确的 String）
- ✅ 正确：`var rect := child as ColorRect`（as 转换后类型明确）
- ✅ 正确：`var count := 0`（右值是明确的 int）
- ❌ 错误：`var x := null`（null 无法推断类型，编译错误）
- ❌ 错误：`var value := dict.get("key")`（get 返回 Variant，不能用 `:=`）
- 当右值类型不明确（如字典取值、Variant 返回值）时，应**显式标注类型**：
  - `var value: Variant = dict.get("key")`
  - `var node: Node = some_func()`

### 2. 变量声明不要冗余标注

- 当使用 `:=` 时，不要同时写类型标注，这是语法错误。
- ❌ 错误：`var key: String := "hello"`（`:=` 和 `: String` 不能同时使用）
- ✅ 正确：`var key := "hello"` 或 `var key: String = "hello"`

---

## 三、GDShader 规范

### 1. 入口函数不能使用 return 返回值

- gdshader 的 `fragment()`、`vertex()`、`light()` 等入口函数返回类型为 **void**，不能使用 `return <值>` 返回值。
- 正确做法是直接赋值给内置变量。
- ✅ 正确：
  ```glsl
  void fragment() {
      COLOR = texture(TEXTURE, UV);
  }
  ```
- ❌ 错误：
  ```glsl
  void fragment() {
      return texture(TEXTURE, UV); // 编译错误：void 函数不能返回值
  }
  ```
- 注意：`return;`（不带值的提前返回）在 void 函数中是**允许的**。

### 2. 自定义函数的 return

- 自定义的有返回值的函数可以正常使用 `return`：
  ```glsl
  float my_func(float x) {
      return x * 2.0;
  }
  ```

---

## 四、工具与插件偏好

### 1. 日志处理

- 处理 log 逻辑时，**优先使用 clog 库**，而非原生的 `print` / `push_warning` / `push_error` 等方法。

### 2. 相机处理

- 处理相机逻辑和相机相关节点时，**优先使用 Phantom Camera**（插件），而非原生的 `Camera2D` / `Camera3D`。
