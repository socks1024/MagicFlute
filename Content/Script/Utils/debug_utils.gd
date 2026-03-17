class_name DebugUtils

## Use CLog for logging instead.
static func log_debug(message: String, color: Color = Color.WHITE, depth: int = 1) -> void:

	var stack: Array = get_stack()

	if stack == null || depth >= stack.size():
		print("无法获取目标调用堆栈信息。")
		return

	var caller: Dictionary = stack[depth]  # 获取调用者信息
	var file: String = caller["source"]
	var line: int = caller["line"]
	var function: String = caller["function"]

	var colored_message = "[color=%s]%s[/color]" % [color.to_html(false), message]
	print_rich("[%s:%s @%s] %s" % [file, function, line, colored_message])

## Use CLog for logging instead.
static func log_info(message: String, _depth: int = 1) -> void:
	# log_debug(message, Color.WHITE, depth + 1)
	CLog.o(message)

## Use CLog for logging instead.
static func log_warning(message: String, _depth: int = 1) -> void:
	# log_debug(message, Color.YELLOW, depth + 1)
	CLog.w(message)

## Use CLog for logging instead.
static func log_error(message: String, _depth: int = 1) -> void:
	# log_debug(message, Color.RED, depth + 1)
	CLog.e(message)
