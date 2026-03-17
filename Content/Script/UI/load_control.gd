@abstract class_name LoadControl extends Control
## 加载代理界面的抽象基类 使用前需要传递 path 参数，并连接 load_finish 信号

@export var min_load_time: float = 0.5
@export var confirm_time: float = 0.3

signal load_finish(res)

var path:String

var _load_progress:float
var _curr_load_time:float

func _ready() -> void:
	if !path: CLog.e("Path not set")
	ResourceLoader.load_threaded_request(path)
	_curr_load_time = 0.0
	_init_progress_control()

func _process(delta: float) -> void:
	if _load_progress < 1.0:
		_curr_load_time += delta
		var p:Array
		ResourceLoader.load_threaded_get_status(path, p)
		_load_progress = minf(p[0], _curr_load_time / min_load_time)
		_update_progress_control(_load_progress)
		if _load_progress >= 1.0:
			_update_progress_control(1.0)
			get_tree().create_timer(confirm_time).timeout.connect(_on_confirm_timeout)

func _on_confirm_timeout() -> void:
	var res = ResourceLoader.load_threaded_get(path)
	if !res: 
		CLog.e("Resource load failed at :", path)
		return
	load_finish.emit(res)
	CLog.o("res loaded:", res)
	_free_progress_control()

@abstract func _init_progress_control() -> void

@abstract func _update_progress_control(value:float) -> void

@abstract func _free_progress_control() -> void
