extends FurnitureBase
class_name FurnitureDrivethrough

## Host-only submission hook consumed by OrderManager.
signal itemSubmitted(item:ItemPacked)

@export var collisionInteract:CollideInteractableMark
@export var attackInteract:AttackIneractableMark
@export var storePoint:Node2D
@export var instanceScale:float = 0.25

var submittedCount:int = 0
var lastSubmittedItem:ItemPacked
var interactCooldown:float = 0.0

func _ready() -> void:
	super()
	collisionInteract.register(self)
	attackInteract.register(self)

func _physics_process(delta:float) -> void:
	interactCooldown = maxf(0.0, interactCooldown - delta)

func isValid() -> bool:
	return interactCooldown <= 0.0

func canSubmitItem(item:ItemCompound) -> bool:
	return item is ItemPacked and not item.contain.is_empty()

func onInteract(player:Player) -> bool:
	if not is_multiplayer_authority() or not isValid() or player.items.is_empty():
		return false
	var item:ItemCompound = player.items[0]
	if not canSubmitItem(item):
		return false
	player.items.remove_at(0)
	player.syncItemsToAll()
	player.containerComponent.rebuild()
	return submitItem(item)

func onAttackInteract(player:Player) -> bool:
	return onInteract(player)

func onCollideInteract(player:Player) -> bool:
	return onInteract(player)

func onItemCollide(item:MovingItem) -> bool:
	if shouldTreatItemAsWall(item.contained):
		item.hitWall()
		return false
	return submitItem(item.contained)

func shouldTreatItemAsWall(item:ItemCompound) -> bool:
	return not item is ItemPacked

func submitItem(item:ItemCompound) -> bool:
	if not is_multiplayer_authority() or not isValid() or not canSubmitItem(item):
		return false
	interactCooldown = 0.2
	submittedCount += 1
	lastSubmittedItem = ItemCompound.fromData(item.toData()) as ItemPacked
	syncSubmission(submittedCount, lastSubmittedItem.toData(), true)
	syncSubmission.rpc(submittedCount, lastSubmittedItem.toData(), true)
	GlobalSoundManager.playSoundForAll("fx/itemDone1", storePoint.global_position, -5)
	itemSubmitted.emit(lastSubmittedItem)
	return true

func _on_sync_request(requesterId:int) -> void:
	syncSubmission.rpc_id(requesterId, submittedCount, lastSubmittedItem.toData() if lastSubmittedItem else {}, false)

@rpc("authority", "call_remote", "reliable")
func syncSubmission(count:int, itemData:Dictionary, playAnimation:bool) -> void:
	submittedCount = count
	lastSubmittedItem = ItemCompound.fromData(itemData) as ItemPacked if not itemData.is_empty() else null
	if playAnimation and lastSubmittedItem:
		var itemInstance:ItemInstance = ItemInstance.new()
		itemInstance.sprite_scale = instanceScale
		itemInstance.set_compound(lastSubmittedItem)
		storePoint.add_child(itemInstance)
		itemInstance.playExit()
