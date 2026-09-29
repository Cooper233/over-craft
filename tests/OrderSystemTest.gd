extends Node

var failures:int = 0

func check(value:bool, message:String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _ready() -> void:
	var level:LevelControllerBase = load("res://scenes/test_level1.tscn").instantiate()
	add_child(level)
	var manager:OrderManager = level.orderManager
	manager.set_physics_process(false)
	var dinein:FurnitureDinein = level.get_node("Entities/Furniture_dinein")
	var dishback:FurnitureDishback = level.get_node("Entities/Furniture_dishback")
	var drive:FurnitureDrivethrough = level.get_node("Entities/Furniture_drivethrough")
	dinein.set_physics_process(false)
	manager.setAvailableItems(["gear"])
	manager.setSettings(2, 2.0, 3.0)
	manager._physics_process(1.99)
	check(manager.getOrders().is_empty(), "Publication must wait the interval")
	manager._physics_process(0.02)
	check(manager.orders.size() == 1 and manager.orders[0].itemId == "gear", "Catalog must determine target")
	manager.generateOrder()
	check(not manager.generateOrder(), "Maximum includes all active orders")
	manager.orders[0].serviceType = OrderManager.DINEIN
	manager.orders[1].serviceType = OrderManager.TAKEAWAY
	var copy:Array[Dictionary] = manager.getOrders()
	copy[0].itemId = "steel"
	check(manager.orders[0].itemId == "gear", "UI reads must be isolated copies")
	var meal:ItemCompound = ItemCompound.createCompound("gear")
	var mixed:ItemCompound = ItemCompound.createCompound("gear")
	mixed.addItem("steel")
	check(manager.findDineinOrder(mixed).is_empty(), "Extra ingredients must not match")
	check(manager.findDineinOrder(ItemPlate.createPlate(false)).is_empty(), "Plate must not match")
	check(dinein.acceptItem(meal), "Dinein must accept a matching meal")
	check(manager.orders[0].state == "consuming" and dinein.pendingReturnCount == 1, "Meal must reserve order and plate ticket")
	check(manager.findDineinOrder(meal).is_empty(), "Consuming order cannot be submitted twice")
	manager._physics_process(2.99)
	check(dishback.dirtyPlateCount == 0, "Consumption must wait")
	manager._physics_process(0.02)
	check(manager.completedCount == 1 and dishback.dirtyPlateCount == 1 and dinein.pendingReturnCount == 0, "Completion must return exactly one dirty plate")
	check(manager.orders.size() == 1 and is_equal_approx(manager.publishRemaining, 2.0), "Freeing full queue resets publication interval")
	check(drive.submitItem(ItemPacked.packItem(meal)), "Takeaway submission must accept package")
	check(manager.completedCount == 2 and manager.orders.is_empty(), "Takeaway must complete immediately")
	manager.onTakeawaySubmitted(ItemPacked.packItem(meal))
	check(manager.completedCount == 2, "No matching order cannot complete twice")
	manager.setAvailableItems([])
	manager._physics_process(100.0)
	check(manager.orders.is_empty(), "Empty catalog pauses publication")
	manager.setAvailableItems(["gear"])
	manager.setSettings(0, 1.0, 1.0)
	check(not manager.generateOrder(), "Zero cap pauses publication")
	manager.setSettings(2, 1.0, 1.0)
	manager.generateOrder()
	manager.generateOrder()
	manager.setSettings(1, 1.0, 1.0)
	check(manager.orders.size() == 2 and not manager.generateOrder(), "Reducing cap preserves existing orders")
	manager.set_multiplayer_authority(2)
	check(not manager.generateOrder() and not manager.setAvailableItems([]) and not manager.setSettings(10, 1, 1), "Non-authority cannot change gameplay")
	var previousTime:float = manager.serverTime
	manager._physics_process(10.0)
	check(manager.serverTime == previousTime, "Clients must not advance authoritative timers")
	manager.set_multiplayer_authority(1)
	for audioPlayer in GlobalSoundManager.pool:
		audioPlayer.stop()
		audioPlayer.stream = null
	await get_tree().create_timer(0.8).timeout
	print("OrderSystemTest: ", "PASS" if failures == 0 else "FAIL")
	get_tree().quit(0 if failures == 0 else 1)
