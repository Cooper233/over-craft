extends Node
class_name AttackIneractableMark

var host:Node2D
var isValidFunc:Callable
var onAttackInteract:Callable
var onNormalInteract:Callable

func register(host:Node2D):
	self.host=host
	if host.has_method("isValid"):
		isValidFunc=host.isValid
	if host.has_method("onAttackInteract"):
		onAttackInteract=host.onAttackInteract
	if host.has_method("onInteract"):
		onNormalInteract=host.onInteract


func isValid()->bool:
	if isValidFunc:
		return isValidFunc.call()
	return false

func onInteract(player:Player,isAttack:bool)->bool:
	if not isValid():
		return false
	if onAttackInteract and isAttack:
		return onAttackInteract.call(player)
	if onInteract and not isAttack:
		return onNormalInteract.call(player)
	return true
