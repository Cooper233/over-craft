extends Control
class_name ItemIcon

@onready var backT:TextureRect=$IconBack
@onready var iconT:TextureRect=$Icon
@onready var numL:Label=$Num

var rare:int=0
var itemType:String=""
var itemNum:int=0

func _ready() -> void:
	refreash()

func refreash()->void:
	if not itemType:return
	
