extends Node
## Run two processes with -- --host and -- --client (port 23459).
var level:LevelControllerBase
var failures:int = 0
var stage:int = 0

func check(value:bool, message:String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _ready() -> void:
	get_tree().create_timer(25.0).timeout.connect(func():
		push_error("OrderNetworkTest timed out")
		get_tree().quit(1))
	var peer:ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	if "--host" in OS.get_cmdline_user_args():
		check(peer.create_server(23459) == OK, "Server must start")
		multiplayer.multiplayer_peer = peer
		createLevel()
		level.orderManager.setSettings(3, 30.0, 4.0)
		level.orderManager.setAvailableItems(["gear"])
		level.orderManager.generateOrder()
		level.orderManager.orders[0].serviceType = OrderManager.DINEIN
		level.get_node("Entities/Furniture_dinein").acceptItem(ItemCompound.createCompound("gear"))
		level.get_node("Entities/Furniture_dishback").returnPlate()
		var washer:FurnitureDishwash = level.get_node("Entities/Furniture_dishwash")
		washer.washSteps = 7
		washer.storePlate(ItemPlate.createPlate(true))
		washer.washProgress = 2
		print("OrderNetworkTest: HOST READY")
	else:
		check(peer.create_client("127.0.0.1", 23459) == OK, "Client must start")
		multiplayer.multiplayer_peer = peer
		await multiplayer.connected_to_server
		createLevel()
		await get_tree().create_timer(0.6).timeout
		var manager:OrderManager = level.orderManager
		check(manager.maxOrderCount == 3 and manager.publishInterval == 30.0, "Late join must receive settings")
		check(manager.orders.size() == 1 and manager.orders[0].state == "consuming", "Late join must restore consuming order")
		var dinein:FurnitureDinein = level.get_node("Entities/Furniture_dinein")
		var washer:FurnitureDishwash = level.get_node("Entities/Furniture_dishwash")
		check(dinein.plateCount == 2 and dinein.pendingReturnCount == 1, "Late join must restore plate counts")
		check(washer.storedItem != null and washer.storedItem.isDirty and washer.washProgress == 2 and washer.washSteps == 7, "Late join must restore washer state and denominator")
		check(not manager.generateOrder() and not manager.setSettings(99, 1, 1), "Client mutation APIs must reject")
		advanceHost.rpc_id(1)
		await get_tree().create_timer(0.6).timeout
		check(manager.orders.is_empty() and manager.completedCount == 1, "Completion must replicate")
		check(dinein.pendingReturnCount == 0 and level.get_node("Entities/Furniture_dishback").dirtyPlateCount == 2, "Returned dirty plate must replicate exactly once")
		finishHost.rpc_id(1, failures)
		await get_tree().create_timer(0.2).timeout
		print("OrderNetworkTest client: ", "PASS" if failures == 0 else "FAIL")
		get_tree().quit(0 if failures == 0 else 1)

func createLevel() -> void:
	level = load("res://scenes/test_level1.tscn").instantiate()
	add_child(level)
	level.orderManager.set_physics_process(false)
	level.get_node("Entities/Furniture_dinein").set_physics_process(false)

@rpc("any_peer", "call_remote", "reliable")
func advanceHost() -> void:
	if multiplayer.is_server() and stage == 0:
		stage = 1
		level.orderManager._physics_process(4.1)

@rpc("any_peer", "call_remote", "reliable")
func finishHost(clientFailures:int) -> void:
	if multiplayer.is_server():
		print("OrderNetworkTest host: ", "PASS" if clientFailures == 0 and failures == 0 else "FAIL")
		await get_tree().create_timer(0.5).timeout
		get_tree().quit(0 if clientFailures == 0 and failures == 0 else 1)
