extends Node

var failures:int = 0
var submissionEvents:int = 0

func check(value:bool, message:String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _ready() -> void:
	var level:LevelControllerBase = load("res://scenes/test_level1.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	level.spawn_player(1, Vector2(300, 140))
	var player:Player = level.get_players()[0]
	var pack: FurniturePack = level.get_node("Entities/Furniture_pack")
	var submit: FurnitureDrivethrough = level.get_node("Entities/Furniture_drivethrough")
	var desk:FurnitureDesk = level.get_node("Entities/Furniture_desk")
	var board:FurnitureBoard = level.get_node("Entities/Furniture_board")
	var blender:FurnitureBlender = level.get_node("Entities/Furniture_blender")
	submit.itemSubmitted.connect(func(_item:ItemPacked): submissionEvents += 1)

	var raw:ItemCompound = ItemCompound.createCompound("steel")
	player.items = [raw]
	check(not submit.onInteract(player), "Drive-through must reject unpacked input")
	check(not submit.onCollideInteract(player) and player.items[0] == raw, "Player collision must retain non-packed carried items")
	check(pack.onInteract(player) and pack.storedItem == raw, "Raw input must be stored without automatic packing")
	pack.interactCooldown = 0
	player.items = [ItemCompound.createCompound("vodka")]
	check(pack.onInteract(player) and pack.storedItem.contain.size() == 2, "Unpacked station must merge like a desk")
	pack.interactCooldown = 0
	check(pack.onAttackInteract(player) and pack.storedItem is ItemPacked, "Attack must pack mixed raw materials")
	check(player.items.is_empty(), "Packing must leave the package in the slot")
	pack.interactCooldown = 0
	check(not pack.onInteract(player) and not pack.onCollideInteract(player), "Packed slot must reject non-attack retrieval")
	player.items = [ItemCompound.createCompound("gear")]
	check(not pack.onInteract(player) and not pack.onAttackInteract(player), "Packed slot must reject insertion and full-hand retrieval")
	player.items.clear()
	check(pack.onAttackInteract(player) and pack.storedItem == null, "Second attack must retrieve the package")
	check(player.items[0].getItemNum("vodka") == 1, "Mixed contents must survive packing")
	pack.interactCooldown = 0
	check(pack.onInteract(player) and pack.storedItem is ItemPacked, "Empty station must also accept existing packages")
	pack.storeSyncRemote({})
	pack.interactCooldown = 0
	var product:ItemCompound = ItemCompound.createCompound("steelplate")
	product.processPoint = 10
	check(pack.canPackItem(product), "Partially processed products can be packed")
	player.items = [product]
	check(pack.onInteract(player) and player.items.is_empty() and pack.storedItem == product, "Placement must store without packing")
	pack.interactCooldown = 0
	check(pack.onAttackInteract(player) and pack.storedItem is ItemPacked, "Attack must pack the stored product")
	pack.interactCooldown = 0
	check(pack.onAttackInteract(player) and pack.storedItem == null, "Empty hand must retrieve the package")
	var packedItem:ItemPacked = player.items[0] as ItemPacked
	check(packedItem.getItemNum("steelplate") == 1, "Original contents must be retained")
	check(not packedItem.mergeCompound(raw) and not raw.mergeCompound(packedItem), "Packages cannot be merged in either direction")
	check(not pack.canPackItem(packedItem), "Packages cannot be repacked")
	check(not GlobalProcessManager.find_recipe_for_item("blender", packedItem), "Packed steelplate cannot match the gear recipe")
	check(not board.onInteract(player) and not blender.onInteract(player), "Processors must reject packages without removing them")
	check(player.items[0] == packedItem, "Rejected package must stay in the player's hand")
	check(desk.onInteract(player), "Empty desk must accept packages")
	var deskData:Dictionary = desk.storedItem.toData()
	desk.storeSyncRemote(deskData)
	check(desk.storedItem is ItemPacked, "Desk snapshot must preserve package type")
	check(desk.instance.get_child(0).get_child(0).texture.resource_path.ends_with("item_packed.png"), "Desk visual must use the package icon")
	player.items = [raw]
	check(not desk.onInteract(player) and player.items[0] == raw, "Occupied package desk must preserve rejected input")
	player.items.clear()
	check(desk.onAttackInteract(player), "Desk must return package intact")
	player._sync_items([player.items[0].toData()])
	check(player.items[0] is ItemPacked, "Player inventory snapshot must preserve package type")
	player.ejectItem()
	var moving:MovingItem
	for child in level.entities.get_children():
		if child is MovingItem:
			moving = child
	check(moving != null and moving.contained is ItemPacked, "Throw must preserve package type")
	var restored:MovingItem = MovingItem.new()
	restored.from_dict(moving.to_dict())
	check(restored.contained is ItemPacked, "Moving-item snapshot must preserve package type")
	check(not board.onItemCollide(restored) and not blender.onItemCollide(restored), "Thrown packages must be rejected by processors")
	check(submit.onItemCollide(restored), "Drive-through must accept a thrown package")
	check(submit.submittedCount == 1 and submissionEvents == 1, "A submission must be recorded exactly once")
	check(submit.lastSubmittedItem.getItemNum("steelplate") == 1, "Submission must retain contents for order matching")
	check(not submit.onItemCollide(restored), "Cooldown must reject duplicate submissions")
	submit.interactCooldown = 0
	player.items = [packedItem]
	check(submit.onCollideInteract(player) and player.items.is_empty(), "Player collision must submit the carried package")
	check(submit.submittedCount == 2 and submissionEvents == 2, "Hand submission must emit one event")
	submit.syncSubmission(2, packedItem.toData(), false)
	check(submit.lastSubmittedItem is ItemPacked and submissionEvents == 2, "Restoring submission state must not submit again")
	pack.interactCooldown = 0
	restored.contained = ItemCompound.createCompound("gear")
	check(pack.onItemCollide(restored) and not pack.storedItem is ItemPacked, "Thrown items must be stored without automatic packing")
	pack.interactCooldown = 0
	check(pack.onAttackInteract(player) and pack.storedItem is ItemPacked, "Attack must pack a thrown item")
	pack.interactCooldown = 0
	check(not pack.onItemCollide(restored), "Packed station must reject thrown input")
	restored.free()
	GlobalEntityManager.recycle(moving.entity_uid)
	var rejected:MovingItem = level.spawnEntity("moving_item", Vector2(300, 140), {"item":raw.toData()}) as MovingItem
	submit.interactCooldown = 1.0
	check(not submit.collisionInteract.onItemInteract(rejected), "Wall impact must not immediately consume the projectile")
	check(rejected.dying and rejected.collision_mask == 0, "Non-packed projectile must use wall impact even during cooldown")
	check(submit.submittedCount == 2 and submissionEvents == 2, "Wall impacts must not count as submissions")
	desk.storeSyncRemote({})
	check(desk.storedItem == null, "Empty desk snapshot must clear stored data")
	await get_tree().create_timer(0.5).timeout
	check(not is_instance_valid(rejected), "Wall impact must recycle the rejected projectile after animation")
	for audioPlayer in GlobalSoundManager.pool:
		audioPlayer.stop()
		audioPlayer.stream = null
	await get_tree().create_timer(0.1).timeout
	print("PackedItemTest: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	get_tree().quit(0 if failures == 0 else 1)
