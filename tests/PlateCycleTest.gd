extends Node

var failures:int = 0
var lastTicket:int = -1

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
	var dinein:FurnitureDinein = level.get_node("Entities/Furniture_dinein")
	var dishback:FurnitureDishback = level.get_node("Entities/Furniture_dishback")
	var dishwash:FurnitureDishwash = level.get_node("Entities/Furniture_dishwash")
	dinein.itemSubmitted.connect(func(ticketId:int, _item:ItemCompound, _orderId:String): lastTicket = ticketId)
	dinein.set_physics_process(false)
	dinein.syncState(1, 0)
	var meal:ItemCompound = ItemCompound.createCompound("gear")
	player.items = [meal]
	check(dinein.onInteract(player) and player.items.is_empty(), "Meal must consume one plate and leave the player's hand")
	check(dinein.plateCount == 0 and dishback.dirtyPlateCount == 0, "Plate must not return immediately")
	player.items = [meal]
	check(not dinein.onInteract(player) and player.items[0] == meal, "Zero plates must reject meals without consuming them")
	dinein._physics_process(4.99)
	check(dishback.dirtyPlateCount == 0, "No-order return must wait five seconds")
	dinein._physics_process(0.02)
	check(dishback.dirtyPlateCount == 1, "No-order plate must return dirty after five seconds")
	check(not dinein.completeConsumption(lastTicket), "Completed ticket must not return a second plate")
	check(not dishback.onInteract(player) and not dishback.onAttackInteract(player), "Dishback must not accept items or give to a full hand")
	player.items.clear()
	check(dishback.onAttackInteract(player) and dishback.dirtyPlateCount == 0, "Dishback must give exactly one plate")
	var dirty:ItemPlate = player.items[0] as ItemPlate
	check(dirty != null and dirty.isDirty, "Returned item must be a dirty plate")
	check(not dirty.mergeCompound(meal) and not meal.mergeCompound(dirty), "Plates must not merge in either direction")
	player._sync_items([dirty.toData()])
	check(player.items[0] is ItemPlate and player.items[0].isDirty, "Inventory sync must preserve dirty plate type")
	check(not dinein.onInteract(player), "Dirty plates must not refill dinein")
	check(dishwash.onInteract(player) and player.items.is_empty(), "Dishwash must take one dirty plate")
	check(not dishwash.storePlate(dirty), "Occupied washer must reject another plate")
	check(not dishwash.onCollideInteract(player), "Collision must not wash or retrieve plates")
	check(dishwash.onAttackInteract(player), "Attack must advance washing")
	check(not dishwash.onAttackInteract(player), "Repeated attack during cooldown must be rejected")
	dishwash.syncState(dishwash.storedItem.toData(), dishwash.washProgress)
	check(dishwash.storedItem.isDirty and dishwash.washProgress == 1, "Washer snapshot must restore contents and partial progress")
	for step in range(1, dishwash.washSteps):
		dishwash.cooldownRemaining = 0
		check(dishwash.onAttackInteract(player), "Each attack must advance washing")
	check(not dishwash.storedItem.isDirty and player.items.is_empty(), "Clean plate must stay in the washer")
	dishwash.cooldownRemaining = 0
	player.items = [meal]
	check(not dishwash.onAttackInteract(player), "Clean plate must not overwrite a full hand")
	player.items.clear()
	check(dishwash.onAttackInteract(player) and dishwash.storedItem == null, "Next empty-hand attack must retrieve the clean plate")
	check(dinein.onInteract(player) and dinein.plateCount == 1, "Clean plate must refill dinein even at zero plates")
	dinein.orderResolver = func(_item:ItemCompound) -> String: return "test-order"
	player.items = [meal]
	check(dinein.onInteract(player), "Matched order must be accepted")
	dinein._physics_process(10.0)
	check(dishback.dirtyPlateCount == 0, "Matched order must not use fallback timeout")
	check(dinein.completeConsumption(lastTicket) and dishback.dirtyPlateCount == 1, "Order consumption callback must return one plate")
	check(not dinein.completeConsumption(lastTicket), "Order callback must be idempotent")
	dishback.returnPlate()
	var bottom:Node2D = dishback.plateInstance.get_child(0)
	var top:Node2D = dishback.plateInstance.get_child(1)
	check(top.position.x == bottom.position.x and top.position.y < bottom.position.y, "Plate display must stack vertically")
	var clean:ItemPlate = ItemPlate.createPlate(false)
	var projectile:MovingItem = MovingItem.new()
	projectile.from_dict({"item":clean.toData()})
	check(projectile.contained is ItemPlate and not projectile.contained.isDirty, "Projectile sync must preserve clean plate state")
	check(not dishback.onItemCollide(projectile), "Dishback must refuse thrown input")
	check(not dishwash.onItemCollide(projectile), "Washer must refuse clean plates")
	check(dinein.onItemCollide(projectile), "Thrown clean plates must refill dinein")
	projectile.free()
	dinein.syncState(0, dinein.submittedCount)
	player.global_position = dinein.get_node("RecipeTip").global_position
	await get_tree().create_timer(0.3).timeout
	var anchor:FurnitureRecipeTip = dinein.get_node("RecipeTip")
	check(anchor.tip.isShown and anchor.tip.currentItem.getItemNum("plate") == 0, "Nearby tip must show zero remaining plates")
	check(anchor.tip.ingredientContainer.get_child(0).numberLabel.text == "0", "Zero plate label must be visible")
	for audioPlayer in GlobalSoundManager.pool:
		audioPlayer.stop()
		audioPlayer.stream = null
	await get_tree().create_timer(0.1).timeout
	print("PlateCycleTest: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	get_tree().quit(0 if failures == 0 else 1)
