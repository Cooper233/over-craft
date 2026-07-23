extends Node
class_name CollideInteractableMark

var host:Node2D
var isValidFunc:Callable
var onInteractFunc:Callable

func register(host:Node2D):
	self.host=host
	if host.has_method("isValid"):
		isValidFunc=host.isValid
	if host.has_method("onCollideInteract"):
		onInteractFunc=host.onCollideInteract


func isValid()->bool:
	if isValidFunc:
		return isValidFunc.call()
	return false

func onInteract(player:Player)->bool:
	if not isValid():
		return false
	if onInteractFunc:
		return onInteractFunc.call(player)
	else:
		return true
