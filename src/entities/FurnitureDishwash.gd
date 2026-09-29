extends FurniturePlateStation
class_name FurnitureDishwash

@export_range(1, 30) var washSteps:int = 5
@export var attackCooldown:float = 0.2
@export var progressTip:FurnitureProgressTip

var storedItem:ItemPlate
var washProgress:int = 0
var cooldownRemaining:float = 0.0

func _physics_process(delta:float) -> void:
	cooldownRemaining = maxf(0.0, cooldownRemaining - delta)
	if progressTip and is_instance_valid(progressTip.bar):
		if storedItem and storedItem.isDirty:
			progressTip.syncProgress(float(washProgress) / maxi(1, washSteps))
			progressTip.setShow()
		else:
			progressTip.setHide(storedItem != null)

func getTipItem() -> ItemCompound:
	return storedItem

func getTipRecipe() -> ItemProcessRecipe:
	if not storedItem or not storedItem.isDirty:
		return null
	var recipe:ItemProcessRecipe = ItemProcessRecipe.new()
	recipe.itemNeed = {"dirtyplate": 1}
	recipe.result = "plate"
	return recipe

func storePlate(item:ItemCompound) -> bool:
	if not is_multiplayer_authority() or storedItem or not item is ItemPlate or not item.isDirty:
		return false
	storedItem = ItemPlate.createPlate(true)
	washProgress = 0
	cooldownRemaining = 0.0
	publishState()
	return true

func onInteract(player:Player) -> bool:
	if player.items.is_empty() or not storePlate(player.items[0]):
		return false
	player.items.remove_at(0)
	syncPlayer(player)
	return true

func onItemCollide(item:MovingItem) -> bool:
	return storePlate(item.contained)

func onCollideInteract(player:Player) -> bool:
	return onInteract(player)

func onAttackInteract(player:Player) -> bool:
	if not is_multiplayer_authority() or not storedItem or cooldownRemaining > 0.0:
		return false
	if storedItem.isDirty:
		washProgress += 1
		cooldownRemaining = attackCooldown
		if washProgress >= maxi(1, washSteps):
			storedItem = ItemPlate.createPlate(false)
		publishState()
		GlobalSoundManager.playSoundForAll("fx/click", storePoint.global_position)
		return true
	if not player.items.is_empty():
		return false
	player.tryToGetItem(storedItem)
	storedItem = null
	washProgress = 0
	publishState()
	return true

func publishState() -> void:
	var data:Dictionary = storedItem.toData() if storedItem else {}
	syncState(data, washProgress, washSteps)
	syncState.rpc(data, washProgress, washSteps)

func _on_sync_request(requesterId:int) -> void:
	syncState.rpc_id(requesterId, storedItem.toData() if storedItem else {}, washProgress, washSteps)

@rpc("authority", "call_remote", "reliable")
func syncState(data:Dictionary, progress:int, requiredSteps:int = -1) -> void:
	if requiredSteps > 0:
		washSteps = requiredSteps
	storedItem = ItemCompound.fromData(data) as ItemPlate if not data.is_empty() else null
	washProgress = progress
	refreshDisplay()
