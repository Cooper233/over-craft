extends FurniturePlateStation
class_name FurnitureDinein

signal itemSubmitted(ticketId:int, item:ItemCompound, orderId:String)

@export_range(0, 99) var plateCount:int = 3
@export var dishback:FurnitureDishback
@export var fallbackReturnSeconds:float = 5.0

## Optional order-system hook: returns a matching order ID, or an empty string.
var orderResolver:Callable
var submittedCount:int = 0
var nextTicketId:int = 0
var pendingReturns:Dictionary = {}
## Replicated UI count; ticket timers remain host-only.
var pendingReturnCount:int = 0

func getTipItem() -> ItemCompound:
	var item:ItemCompound = ItemCompound.new()
	item.contain = {"plate": plateCount}
	return item

func _physics_process(delta:float) -> void:
	if not is_multiplayer_authority():
		return
	for ticketId in pendingReturns.keys():
		if pendingReturns[ticketId] < 0.0:
			continue
		pendingReturns[ticketId] = maxf(0.0, pendingReturns[ticketId] - delta)
		if pendingReturns[ticketId] == 0.0:
			completeConsumption(ticketId)

func acceptItem(item:ItemCompound) -> bool:
	if not is_multiplayer_authority() or not item:
		return false
	if item is ItemPlate:
		if item.isDirty:
			return false
		plateCount += 1
		publishState()
		return true
	if plateCount <= 0 or not item.canProcess() or item.contain.is_empty() or not is_instance_valid(dishback):
		return false
	var orderId:String = str(orderResolver.call(item)) if orderResolver.is_valid() else ""
	var ticketId:int = nextTicketId
	nextTicketId += 1
	pendingReturns[ticketId] = -1.0 if not orderId.is_empty() else maxf(0.0, fallbackReturnSeconds)
	plateCount -= 1
	submittedCount += 1
	publishState()
	itemSubmitted.emit(ticketId, ItemCompound.fromData(item.toData()), orderId)
	return true

## Called by the order system when eating is complete; repeated calls are harmless.
func completeConsumption(ticketId:int) -> bool:
	if not is_multiplayer_authority() or not pendingReturns.has(ticketId) or not is_instance_valid(dishback):
		return false
	pendingReturns.erase(ticketId)
	dishback.returnPlate()
	publishState()
	return true

func onInteract(player:Player) -> bool:
	if player.items.is_empty() or not acceptItem(player.items[0]):
		return false
	player.items.remove_at(0)
	syncPlayer(player)
	return true

func onItemCollide(item:MovingItem) -> bool:
	return acceptItem(item.contained)

func publishState() -> void:
	syncState(plateCount, submittedCount, pendingReturns.size())
	syncState.rpc(plateCount, submittedCount, pendingReturns.size())

func _on_sync_request(requesterId:int) -> void:
	syncState.rpc_id(requesterId, plateCount, submittedCount, pendingReturns.size())

@rpc("authority", "call_remote", "reliable")
func syncState(count:int, submissions:int, pendingCount:int = 0) -> void:
	plateCount = maxi(0, count)
	pendingReturnCount = pendingCount
	submittedCount = submissions
	refreshDisplay()
