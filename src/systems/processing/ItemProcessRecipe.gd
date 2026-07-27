class_name ItemProcessRecipe

var acceptType:Array = []
var itemNeed:Dictionary = {}
var pointNeed:int = 0x3f3f3f3f
var result:String = ""

func checkItemCorrect(item:ItemCompound)->bool:
	if itemNeed.keys().size()!=item.contain.size():return false
	for i in itemNeed.keys():
		if item.getItemNum(i) != itemNeed[i]:
			return false
	return true
func checkCouldTransfer(item:ItemCompound)->bool:
	if itemNeed.keys().size()!=item.contain.size():return false
	if item.processPoint < pointNeed:
		return false
	for i in itemNeed.keys():
		if item.getItemNum(i) != itemNeed[i]:
			return false
	return true

static func from_dict(data:Dictionary) -> ItemProcessRecipe:
	var recipe = ItemProcessRecipe.new()
	recipe.acceptType = data.get("acceptType", []).duplicate()
	recipe.itemNeed = data.get("itemNeed", {}).duplicate()
	recipe.pointNeed = data.get("pointNeed", 0x3f3f3f3f)
	recipe.result = data.get("result", "")
	return recipe

func to_dict() -> Dictionary:
	return {
		"acceptType": acceptType.duplicate(),
		"itemNeed": itemNeed.duplicate(),
		"pointNeed": pointNeed,
		"result": result
	}
