extends Node2D
class_name FurnitureBase

func getSize()->Vector2i:
	return Vector2i(1,1)
func canRotate()->bool:
	return false
## 设置家具朝向，0~3分别代表[南,西,北,东]
func setRotate(facing:int):
	pass
## 玩家与该家具攻击交互时触发
func onAttackInteract(player:Player):
	return true
## 玩家与该家具碰撞交互时触发
func onCollideInteract(player:Player):
	return true
## 玩家与该家具普通交互时触发
func onInteract(player:Player):
	return true
## 物品与家具碰撞触发
func onItemCollide(item:MovingItem)->bool:
	return true
## Rejected projectiles can use the same impact behavior as a wall.
func shouldTreatItemAsWall(_item:ItemCompound) -> bool:
	return false
func _ready() -> void:
	_request_sync()
## 客户端执行，用于向主机请求数据同步
func _request_sync() -> void:
	if not is_multiplayer_authority():
		_rpc_request_sync.rpc_id(1)
## 主机执行，用于向请求的客户端同步数据
@rpc("any_peer", "reliable")
func _rpc_request_sync() -> void:
	if not is_multiplayer_authority():
		return
	var requester = multiplayer.get_remote_sender_id()
	_on_sync_request(requester)
## 数据同步基类，每个家具自行实现
func _on_sync_request(requester_id: int) -> void:
	pass
