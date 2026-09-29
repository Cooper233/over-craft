extends FurnitureDesk
class_name FurniturePack

## Store like a desk; attack seals the slot, then a second empty-hand attack collects it.
func canPackItem(item:ItemCompound) -> bool:
	return item != null and item.canProcess() and not item.contain.is_empty()

func canStoreItem(item:ItemCompound) -> bool:
	if storedItem is ItemPacked:
		return false
	return super(item)

func onInteract(player:Player) -> bool:
	if not isValid() or storedItem is ItemPacked:
		return false
	return super(player)

func onCollideInteract(player:Player) -> bool:
	return super(player)

func onItemCollide(item:MovingItem) -> bool:
	if not isValid() or storedItem is ItemPacked:
		return false
	return super(item)

func onAttackInteract(player:Player) -> bool:
	if not is_multiplayer_authority() or not isValid():
		return false
	if storedItem is ItemPacked:
		return super(player)
	if not canPackItem(storedItem):
		return false
	storedItem = ItemPacked.packItem(storedItem)
	interactCooldown = 0.2
	_spawn_instance()
	storeSyncRemote.rpc(storedItem.toData())
	_play_store_animation()
	syncAnim.rpc(AnimType.STORE)
	GlobalSoundManager.playSoundForAll("fx/itemDone", sprite.global_position, -5)
	return true
