class_name NodeUtils

## 深度优先递归遍历所有子孙节点，收集它们并返回
static func recursive_get_children(root:Node, include_internal = false) -> Array:
	var arr:Array
	for n in root.get_children(include_internal):
		arr.append(n)
		recursive_get_children(n, include_internal)
	return arr
