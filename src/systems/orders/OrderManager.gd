extends Node
class_name OrderManager
## Only the host mutates orders. Clients receive complete, reliable snapshots.
signal ordersChanged
signal settingsChanged
signal orderCompleted(order:Dictionary)

const DINEIN:String = "dinein"
const TAKEAWAY:String = "takeaway"
@export_range(0, 100) var maxOrderCount:int = 5
@export_range(0.1, 300.0) var publishInterval:float = 10.0
@export_range(0.1, 300.0) var consumptionDuration:float = 8.0

var availableItems:Array[String] = []
var completedCount:int = 0
var serverTime:float = 0.0
var publishRemaining:float = 10.0
var orders:Array[Dictionary] = []
var nextOrderId:int = 1
var consumptionTickets:Dictionary = {}
var heartbeatRemaining:float = 1.0

func _ready() -> void:
	maxOrderCount = maxi(0, maxOrderCount)
	publishInterval = maxf(0.1, publishInterval)
	consumptionDuration = maxf(0.1, consumptionDuration)
	publishRemaining = publishInterval
	for recipe in GlobalProcessManager.get_all_recipes():
		if not recipe.result.is_empty() and not availableItems.has(recipe.result):
			availableItems.append(recipe.result)
	bindStations(get_parent())
	if not is_multiplayer_authority():
		requestSnapshot.rpc_id(1)

func bindStations(root:Node) -> void:
	for child in root.get_children():
		if child is FurnitureDinein:
			child.orderResolver = findDineinOrder
			child.itemSubmitted.connect(onDineinSubmitted.bind(child))
		elif child is FurnitureDrivethrough:
			child.itemSubmitted.connect(onTakeawaySubmitted)
		bindStations(child)

## UI reads copies; changing a returned dictionary cannot change authoritative state.
func getOrders() -> Array[Dictionary]:
	return orders.duplicate(true)

func getSettings() -> Dictionary:
	return {"maxOrderCount":maxOrderCount, "publishInterval":publishInterval,
		"consumptionDuration":consumptionDuration}

func getAvailableItems() -> Array[String]:
	return availableItems.duplicate()

## Replaceable catalog interface. An empty list suspends publication.
func setAvailableItems(itemIds:Array[String]) -> bool:
	if not is_multiplayer_authority():
		return false
	availableItems.clear()
	for itemId in itemIds:
		if not itemId.is_empty() and itemId not in ["plate", "dirtyplate", "packed"] and not availableItems.has(itemId):
			availableItems.append(itemId)
	publishRemaining = publishInterval
	publishState()
	return true

func setSettings(orderLimit:int, intervalSeconds:float, consumeSeconds:float) -> bool:
	if not is_multiplayer_authority() or not is_finite(intervalSeconds) or not is_finite(consumeSeconds):
		return false
	maxOrderCount = maxi(0, orderLimit)
	publishInterval = maxf(0.1, intervalSeconds)
	consumptionDuration = maxf(0.1, consumeSeconds)
	publishRemaining = publishInterval
	settingsChanged.emit()
	publishState()
	return true

func _physics_process(delta:float) -> void:
	if not is_multiplayer_authority():
		return
	serverTime += delta
	# A full queue pauses publication, including the frame that frees a slot.
	var wasFull:bool = orders.size() >= maxOrderCount
	for order in orders.duplicate():
		if order.state == "consuming" and serverTime >= float(order.consumeUntil):
			var ticket:Dictionary = consumptionTickets.get(order.orderId, {})
			if not ticket.is_empty() and is_instance_valid(ticket.station):
				if not ticket.station.completeConsumption(ticket.ticketId):
					continue
			finishOrder(order)
	if wasFull or orders.size() >= maxOrderCount or availableItems.is_empty():
		publishRemaining = publishInterval
	else:
		publishRemaining -= delta
		if publishRemaining <= 0.0:
			generateOrder()
			publishRemaining = publishInterval
	heartbeatRemaining -= delta
	if heartbeatRemaining <= 0.0:
		heartbeatRemaining = 1.0
		publishState()

func generateOrder() -> bool:
	if not is_multiplayer_authority() or orders.size() >= maxOrderCount or availableItems.is_empty():
		return false
	orders.append({"orderId":str(nextOrderId), "itemId":availableItems.pick_random(),
		"serviceType":DINEIN if randi_range(0, 1) == 0 else TAKEAWAY,
		"state":"waiting", "createdAt":serverTime, "consumeUntil":0.0})
	nextOrderId += 1
	publishRemaining = publishInterval
	publishState()
	return true

func findMatchingOrder(item:ItemCompound, serviceType:String) -> String:
	if not item or item is ItemPlate or item.processPoint != 0 or item.contain.size() != 1:
		return ""
	if (serviceType == TAKEAWAY) != (item is ItemPacked):
		return ""
	for order in orders:
		if order.state == "waiting" and order.serviceType == serviceType and item.contain.get(order.itemId, 0) == 1:
			return order.orderId
	return ""

func findDineinOrder(item:ItemCompound) -> String:
	return findMatchingOrder(item, DINEIN)

func onDineinSubmitted(ticketId:int, item:ItemCompound, orderId:String, station:FurnitureDinein) -> void:
	if not is_multiplayer_authority() or orderId.is_empty() or findDineinOrder(item) != orderId:
		return
	for order in orders:
		if order.orderId == orderId:
			order.state = "consuming"
			order.consumeUntil = serverTime + consumptionDuration
			consumptionTickets[orderId] = {"station":station, "ticketId":ticketId}
			publishState()
			return

func onTakeawaySubmitted(item:ItemPacked) -> void:
	if not is_multiplayer_authority():
		return
	var orderId:String = findMatchingOrder(item, TAKEAWAY)
	for order in orders:
		if order.orderId == orderId:
			finishOrder(order)
			return

func finishOrder(order:Dictionary) -> void:
	if not is_multiplayer_authority() or not orders.has(order):
		return
	orders.erase(order)
	consumptionTickets.erase(order.orderId)
	completedCount += 1
	publishState(order)

func getSnapshot() -> Dictionary:
	return {"orders":getOrders(), "settings":getSettings(), "availableItems":getAvailableItems(),
		"completedCount":completedCount, "serverTime":serverTime, "publishRemaining":publishRemaining}

func publishState(completedOrder:Dictionary = {}) -> void:
	ordersChanged.emit()
	if not completedOrder.is_empty():
		orderCompleted.emit(completedOrder.duplicate(true))
	if multiplayer.has_multiplayer_peer():
		syncSnapshot.rpc(getSnapshot(), completedOrder)

@rpc("any_peer", "call_remote", "reliable")
func requestSnapshot() -> void:
	if is_multiplayer_authority():
		syncSnapshot.rpc_id(multiplayer.get_remote_sender_id(), getSnapshot(), {})

@rpc("authority", "call_remote", "reliable")
func syncSnapshot(data:Dictionary, completedOrder:Dictionary) -> void:
	var settings:Dictionary = data.settings
	var settingsDiffer:bool = settings != getSettings()
	maxOrderCount = settings.maxOrderCount
	publishInterval = settings.publishInterval
	consumptionDuration = settings.consumptionDuration
	orders.assign(data.orders.duplicate(true))
	availableItems.assign(data.availableItems)
	completedCount = data.completedCount
	serverTime = data.serverTime
	publishRemaining = data.publishRemaining
	if settingsDiffer:
		settingsChanged.emit()
	ordersChanged.emit()
	if not completedOrder.is_empty():
		orderCompleted.emit(completedOrder.duplicate(true))
