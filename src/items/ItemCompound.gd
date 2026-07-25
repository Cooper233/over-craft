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
