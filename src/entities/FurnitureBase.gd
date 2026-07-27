extends Node2D
class_name FurnitureBase

func getSize()->Vector2i:
	return Vector2i(1,1)
func canRotate()->bool:
	return false
func setRotate(facing:int):
	pass
func onAttackInteract(player:Player):
	return true
func onCollideInteract(player:Player):
	return true
func onInteract(player:Player):
	return true
func onItemCollide(item:MovingItem)->bool:
	return true
func _ready() -> void:
	_request_sync()

func _request_sync() -> void:
	if not is_multiplayer_authority():
		_rpc_request_sync.rpc_id(1)

@rpc("any_peer", "unreliable")
func _rpc_request_sync() -> void:
	if not is_multiplayer_authority():
		return
	var requester = multiplayer.get_remote_sender_id()
	_on_sync_request(requester)

func _on_sync_request(requester_id: int) -> void:
	pass
