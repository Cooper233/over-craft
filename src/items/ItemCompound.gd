extends RefCounted
class_name ItemCompound

var contain:Dictionary={}
var processPoint:int=0

static func createCompound(id:String)->ItemCompound:
	return ItemCompound.new().addItem(id)
func addItem(id:String)->ItemCompound:
	if not contain.has(id):
		contain[id]=0
	contain[id]+=1
	return self
func mergeCompound(compound:ItemCompound)->bool:
	if not compound or not canProcess() or not compound.canProcess():
		return false
	if processPoint>0 or compound.processPoint>0:
		return false
	for i in compound.contain.keys():
		if not contain.has(i):
			contain[i]=compound.contain[i]
		else:
			contain[i]+=compound.contain[i]
	return true
func getItemNum(id:String)->int:
	return contain[id] if contain.has(id) else 0;

func canProcess() -> bool:
	return true

func getDisplayItems() -> Dictionary:
	return contain.duplicate()

func toData() -> Dictionary:
	return {"itemKind": "compound", "contain": contain.duplicate(true), "processPoint": processPoint}

static func fromData(data:Dictionary) -> ItemCompound:
	if data.get("itemKind", "compound") == "plate":
		return ItemPlate.createPlate(bool(data.get("isDirty", true)))
	var item:ItemCompound
	if data.get("itemKind", "compound") == "packed":
		item = ItemPacked.new()
	else:
		item = ItemCompound.new()
	item.contain = data.get("contain", {}).duplicate(true)
	item.processPoint = 0 if not item.canProcess() else int(data.get("processPoint", data.get("pp", 0)))
	return item
