extends Node

var recipes_by_type:Dictionary = {}
var all_recipes:Array[ItemProcessRecipe] = []

const DEFAULT_RECIPES_DIR:String = "res://resources/recipes/"

func _ready():
	load_recipes_from_directory(DEFAULT_RECIPES_DIR)

func load_recipes_from_directory(dir_path:String):
	var dir = DirAccess.open(dir_path)
	if not dir:
		push_error("Cannot open recipes directory: ", dir_path)
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			load_recipes_from_file(dir_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()

func load_recipes_from_file(file_path:String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Cannot open recipe file: ", file_path)
		return
	var text = file.get_as_text()
	var json = JSON.new()
	var parse_result = json.parse(text)
	if parse_result != OK:
		push_error("JSON parse error in ", file_path, ": ", json.get_error_message())
		return
	var data = json.data
	if data is Array:
		for entry in data:
			_add_recipe(ItemProcessRecipe.from_dict(entry))
	elif data is Dictionary:
		_add_recipe(ItemProcessRecipe.from_dict(data))

func _add_recipe(recipe:ItemProcessRecipe):
	all_recipes.append(recipe)
	for t in recipe.acceptType:
		if not recipes_by_type.has(t):
			recipes_by_type[t] = []
		recipes_by_type[t].append(recipe)

func get_recipes_by_accept_type(accept_type:String) -> Array[ItemProcessRecipe]:
	return recipes_by_type.get(accept_type, []).duplicate()

func get_recipe_by_result(result_id:String) -> ItemProcessRecipe:
	for recipe in all_recipes:
		if recipe.result == result_id:
			return recipe
	return null

func find_recipe_for_item(accept_type:String, item:ItemCompound) -> ItemProcessRecipe:
	var candidates = recipes_by_type.get(accept_type, [])
	for recipe in candidates:
		if recipe.checkItemCorrect(item):
			return recipe
	return null

func has_any_recipe(accept_type:String) -> bool:
	return recipes_by_type.has(accept_type) and (recipes_by_type[accept_type] as Array).size() > 0

func get_all_recipes() -> Array[ItemProcessRecipe]:
	return all_recipes.duplicate()

func get_recipe_count() -> int:
	return all_recipes.size()
