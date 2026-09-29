extends ItemCompound
class_name ItemPacked

## The contents are retained for order matching; there is no unpack operation.
static func packItem(item:ItemCompound) -> ItemPacked:
	if not item or not item.canProcess() or item.contain.is_empty():
		return null
	var packedItem:ItemPacked = ItemPacked.new()
	packedItem.contain = item.contain.duplicate(true)
	return packedItem

func canProcess() -> bool:
	return false

func addItem(_itemId:String) -> ItemCompound:
	return self

func getDisplayItems() -> Dictionary:
	return {"packed": 1}

func toData() -> Dictionary:
	return {"itemKind": "packed", "contain": contain.duplicate(true), "processPoint": 0}
