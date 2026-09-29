extends Node

var cache: Dictionary = {}

func get_texture(path: String) -> Texture2D:
	if cache.has(path):
		return cache[path]
	var tex = load(path) as Texture2D
	if tex:
		cache[path] = tex
	else:
		push_error("TextureReader: 贴图文件不存在 -> " + path)
	return tex
func getItemIcon(itemId:String)->Texture2D:
	return get_texture("res://assets/images/item/item_" + itemId + ".png")
