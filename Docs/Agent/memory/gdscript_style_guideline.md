# 代码顺序
第一节主要讨论代码顺序。

我们建议按以下方式来组织 GDScript 代码：

```
1.  @tool, @icon, @static_unload
2.  class_name
3.  extends
4.  ## doc comment
5.  signals
6.  enums
7.  constants
8.  static variables
9.  @export variables
10. remaining regular variables
11. @onready variables

12. _static_init()
13. remaining static methods
14. overridden built-in virtual methods:
	1. _init()
	2. _enter_tree()
	3. _ready()
	4. _process()
	5. _physics_process()
	6. remaining virtual methods
15. overridden custom methods
16. remaining methods
17. inner classes
```

按以下顺序排列类方法和变量，具体取决于访问修饰符：

```
1. public
2. private
```

我们优化了代码顺序，从上往下阅读代码更加容易，帮助第一次阅读代码的开发人员了解代码的工作原理，同时避免与变量声明顺序相关的错误。

此代码顺序遵循四个经验法则：

1. 先写信号和属性，然后再写方法。
2. 先写公共成员，然后再写私有成员。
3. 先写虚函数回调，然后再写类的接口。
4. 先写对象的构造函数和初始化函数 _init 和 _ready，然后再写运行时修改对象的函数。

## 类声明
如果代码要在编辑器中运行，请将 @tool 注解写在脚本的第一行。

Follow with the optional @icon then the class_name if necessary. You can turn a GDScript file into a global type in your project using class_name. For more information, see 注册具名类. If the class is meant to be an abstract class, add @abstract before the class_name keyword.

然后，如果该类扩展了内置类型，请添加 extends 关键字。

接下来，你应该有该类的可选文档注释。例如，你可以用它来向你的队友解释你的类的作用、它是如何工作的、以及其他开发人员应该如何使用它。

```
@abstract
class_name MyNode
extends Node
## A brief description of the class's role and functionality.
##
## The description of the script, what it can do,
## and any further detail.
```

内部类采用单行形式声明：

```
## A brief description of the class's role and functionality.
##
## The description of the script, what it can do,
## and any further detail.
@abstract class MyNode extends Node:
	pass
```

## 信号和属性
先声明信号，然后声明属性（即成员变量），这些都写在文档注释（docstring）之后。

在信号之后声明枚举，枚举可以用作其他属性的导出提示。

然后，按该顺序依次写入常量、导出变量、公共变量、私有变量和就绪加载（onready）变量。

```
signal player_spawned(position)

enum Job {
	KNIGHT,
	WIZARD,
	ROGUE,
	HEALER,
	SHAMAN,
}

const MAX_LIVES = 3

@export var job: Job = Job.KNIGHT
@export var max_health = 50
@export var attack = 5

var health = max_health:
	set(new_health):
		health = new_health

var _speed = 300.0

@onready var sword = get_node("Sword")
@onready var gun = get_node("Gun")
```

> 备注
> GDScript 在 _ready 回调之前评估 @onready 变量。你可以使用它来缓存节点依赖项，也就是说，获取你的类所依赖的场景中的子节点。这就是上面的例子所展示的。

## 成员变量
如果变量只在方法中使用，请勿将该变量声明为成员变量，因为难以定位在何处使用了该变量。相反，你应该将这些变量在方法内部定义为局部变量。

## 局部变量
局部变量的声明位置离首次使用该局部变量的位置越近越好，让人更容易跟上代码的思路，而不需要上翻下找该变量的声明位置。

## 方法和静态函数
先声明类的属性，再声明类的方法。

从 _init() 回调方法开始，引擎将在内存创建对象时调用该方法，然后是 _ready() 回调，Godot 在向场景树添加一个节点时会调用该回调。

这些函数应声明在脚本最前面，以便显示该对象的初始化方式。

_unhandling_input() 和 _physics_process 等其他内置的虚回调则应该放在后面，控制对象的主循环和与游戏引擎的交互。

类的其余接口、公共和私有方法，均按照这个顺序呈现。

```
func _init():
	add_to_group("state_machine")


func _ready():
	state_changed.connect(_on_state_changed)
	_state.enter()


func _unhandled_input(event):
	_state.unhandled_input(event)


func transition_to(target_state_path, msg={}):
	if not has_node(target_state_path):
		return

	var target_state = get_node(target_state_path)
	assert(target_state.is_composite == false)

	_state.exit()
	self._state = target_state
	_state.enter(msg)
	Events.player_state_changed.emit(_state.name)


func _on_state_changed(previous, new):
	print("state changed")
	state_changed.emit()
```
