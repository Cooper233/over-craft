extends ItemCompound
class_name ItemPlate

var isDirty:bool = true

static func createPlate(dirty:bool) -> ItemPlate:
	var plate:ItemPlate = ItemPlate.new()
	plate.isDirty = dirty
	plate.contain = {"dirtyplate" if dirty else "plate": 1}
	return plate

func canProcess() -> bool:
	return false

func addItem(_itemId:String) -> ItemCompound:
	return self

func toData() -> Dictionary:
	return {"itemKind": "plate", "isDirty": isDirty}
