extends FurnitureBase
class_name FurniturePlateStation

@export var collisionInteract:CollideInteractableMark
@export var attackInteract:AttackIneractableMark
@export var storePoint:Node2D
@export var instanceScale:float = 0.25

var plateInstance:ItemInstance

func _ready() -> void:
	collisionInteract.register(self)
	attackInteract.register(self)
	super()
	refreshDisplay()

func isValid() -> bool:
	return true

func getTipItem() -> ItemCompound:
	return null

func getTipRecipe() -> ItemProcessRecipe:
	return null

func refreshDisplay() -> void:
	if is_instance_valid(plateInstance):
		plateInstance.queue_free()
	plateInstance = ItemInstance.new()
	plateInstance.sprite_scale = instanceScale
	plateInstance.set_compound(getTipItem())
	storePoint.add_child(plateInstance)

func syncPlayer(player:Player) -> void:
	player.syncItemsToAll()
	player.containerComponent.rebuild()

func onAttackInteract(player:Player) -> bool:
	return onInteract(player)

func onCollideInteract(player:Player) -> bool:
	return onInteract(player)
