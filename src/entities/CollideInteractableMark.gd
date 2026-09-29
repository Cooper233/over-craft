extends Node
class_name CollideInteractableMark

var host:Node2D
var isValidFunc:Callable
var onInteractFunc:Callable
var onItemInteractFunc:Callable

func register(host:Node2D):
	self.host=host
	if host.has_method("isValid"):
		isValidFunc=host.isValid
	if host.has_method("onCollideInteract"):
		onInteractFunc=host.onCollideInteract
	if host.has_method("onItemCollide"):
		onItemInteractFunc=host.onItemCollide


func isValid()->bool:
	if isValidFunc:
		return isValidFunc.call()
	return false
func onItemInteract(item:MovingItem)->bool:
	# Wall impacts are physical responses and must not be blocked by interaction cooldowns.
	if host is FurnitureBase and host.shouldTreatItemAsWall(item.contained):
		item.hitWall()
		return false
	if not isValid():
		return false
	if onItemInteractFunc:
		return onItemInteractFunc.call(item)
	else:
		return false
func onInteract(player:Player)->bool:
	if not isValid():
		return false
	if onInteractFunc:
		return onInteractFunc.call(player)
	else:
		return true
