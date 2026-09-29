extends Control
class_name ItemIcon

@onready var backTexture:TextureRect = $IconBack
@onready var iconTexture:TextureRect = $Icon
@onready var numberLabel:Label = $Num

var rare:int=0
var itemType:String=""
var itemNum:int=0

func _ready() -> void:
	refresh()

func setItem(nextItemType:String, nextItemNum:int = 1) -> void:
	itemType = nextItemType
	itemNum = nextItemNum
	if is_node_ready():
		refresh()

func refresh() -> void:
	if itemType.is_empty():
		iconTexture.texture = null
		numberLabel.hide()
		return
	iconTexture.texture = GlobalTextureReader.getItemIcon(itemType)
	numberLabel.text = str(itemNum)
	numberLabel.visible = itemNum != 1
