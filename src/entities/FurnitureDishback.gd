extends FurniturePlateStation
class_name FurnitureDishback

@export_range(0, 99) var dirtyPlateCount:int = 0

func getTipItem() -> ItemCompound:
	var item:ItemCompound = ItemCompound.new()
	item.contain = {"dirtyplate": dirtyPlateCount}
	return item

func returnPlate() -> void:
	if not is_multiplayer_authority():
		return
	syncPlateCount(dirtyPlateCount + 1)
	syncPlateCount.rpc(dirtyPlateCount)

func onInteract(player:Player) -> bool:
	return false # Retrieval only: attack or collision with an empty hand.

func onAttackInteract(player:Player) -> bool:
	if not is_multiplayer_authority() or not player.items.is_empty() or dirtyPlateCount <= 0:
		return false
	player.tryToGetItem(ItemPlate.createPlate(true))
	syncPlateCount(dirtyPlateCount - 1)
	syncPlateCount.rpc(dirtyPlateCount)
	return true

func onCollideInteract(player:Player) -> bool:
	return onAttackInteract(player)

func onItemCollide(_item:MovingItem) -> bool:
	return false

func _on_sync_request(requesterId:int) -> void:
	syncPlateCount.rpc_id(requesterId, dirtyPlateCount)

@rpc("authority", "call_remote", "reliable")
func syncPlateCount(count:int) -> void:
	dirtyPlateCount = maxi(0, count)
	refreshDisplay()
