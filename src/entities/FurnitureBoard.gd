### 家具-菜板
### TODO: 状态切换代码巨烂，建议后面改成：主机向客机同步当前设备的状态与事件+内容物，而不是同步内容物与动画
extends FurnitureBase
class_name FurnitureBoard

enum AnimType {
	STORE,
	TAKE,
	SPAWN,
	DESPAWN,
	TIP_DESPAWN,
	TIP_DESPAWN_DONE
}

@export var collisionInteract:CollideInteractableMark
@export var attackInteract:AttackIneractableMark
@export var storepoint:Node2D
@export var instanceScale:float = 0.5
@export var acceptType:String = "board"
@export var progressTip:FurnitureProgressTip

@onready var sprite:Node2D=$Sprite

var interactCooldown:float=0
var storedItem:ItemCompound
var currentRecipe:ItemProcessRecipe
var instance:ItemInstance

func _ready() -> void:
	super()
	collisionInteract.register(self)
	attackInteract.register(self)

func _physics_process(delta: float) -> void:
	if interactCooldown>0:
		interactCooldown-=delta
func _process(delta: float) -> void:
	if progressTip:
		if storedItem and currentRecipe:
			progressTip.syncProgress(1.0*storedItem.processPoint/currentRecipe.pointNeed)
			progressTip.setShow()
		else:
			progressTip.syncProgress(0)
func isValid()->bool:
	return interactCooldown<=0

func _refresh_current_recipe():
	currentRecipe = GlobalProcessManager.find_recipe_for_item(acceptType, storedItem) if storedItem else null

func onCollideInteract(player:Player)->bool:
	if storedItem:
		return onAttackInteract(player)
	return _process_interact(player)

func onInteract(player:Player)->bool:
	return _process_interact(player)

func onAttackInteract(player:Player)->bool:
	if not storedItem:
		return false
	if currentRecipe:
		return _process_item(player)
	if player.items.size() == 0:
		return _take_item(player)
	return false
## 在被攻击互动时处理内含的物品
## 此函数仅会在服务端运行
## [return] 由于内部包含有效合成表，必定返回处理成功
func _process_item(player:Player) -> bool:
	GlobalSoundManager.playSoundForAll("fx/click", sprite.global_position)
	interactCooldown = 0.2
	if is_multiplayer_authority():
		storedItem.processPoint += 10
		var recipe = currentRecipe
		if recipe.checkCouldTransfer(storedItem):
			GlobalSoundManager.playSoundForAll("fx/itemDone1", sprite.global_position,-8)
			# 把物品设置为当前合成表的结果产物
			storedItem=ItemCompound.createCompound(recipe.result)
			# 将内含物品状态同步至所有客户端
			storeSyncRemote.rpc(storedItem.contain,0)
			# 主机客机播放动画
			tipDespawn(true)
			despawnInstance()
			spawnInstance()
		syncAnim(AnimType.STORE)
		syncAnim.rpc(AnimType.STORE)
		_refresh_current_recipe()
		storeSyncRemote.rpc(storedItem.contain.duplicate(), storedItem.processPoint)
	return true

func _take_item(player:Player) -> bool:
	GlobalSoundManager.playSoundForAll("fx/get_item", sprite.global_position)
	interactCooldown = 0.2
	if is_multiplayer_authority():
		player.tryToGetItem(storedItem)
		storedItem = null
		currentRecipe = null
		storeSyncRemote.rpc({}, 0)
		tipDespawn(false)
		despawnInstance()
		syncAnim(AnimType.TAKE)
		syncAnim.rpc(AnimType.TAKE)
	return true
func onItemCollide(item:MovingItem)->bool:
	addItemToStorange(item.contained)
	return true
func _process_interact(player:Player) -> bool:
	if player.items.size() == 0:
		return false
	GlobalSoundManager.playSoundForAll("fx/click", sprite.global_position)
	interactCooldown = 0.2
	if is_multiplayer_authority():
		var playerItem = player.items[0]
		player.items.remove_at(0)
		player.syncItemsToAll()
		player.containerComponent.rebuild()
		addItemToStorange(playerItem)
	return true
func addItemToStorange(item:ItemCompound):
	if storedItem:
		if storedItem.mergeCompound(item):
			storeSyncRemote.rpc(storedItem.contain.duplicate(), storedItem.processPoint)
			_refresh_current_recipe()
			tipDespawn(false)
			despawnInstance()
			spawnInstance()
			syncAnim.rpc(AnimType.DESPAWN)
			syncAnim.rpc(AnimType.SPAWN)
		else:
			storedItem = null
			currentRecipe = null
			tipDespawn(false)
			despawnInstance()
			takeSyncRemote.rpc()
	else:
		storedItem = item
		storeSyncRemote.rpc(storedItem.contain.duplicate(), storedItem.processPoint)
		_refresh_current_recipe()
		spawnInstance()
		syncAnim(AnimType.STORE)
		syncAnim.rpc(AnimType.STORE)
## 数据同步的实现
func _on_sync_request(requester_id: int) -> void:
	if storedItem:
		storeSyncRemote.rpc_id(requester_id, storedItem.contain.duplicate(), storedItem.processPoint)
		syncAnim.rpc_id(requester_id,AnimType.SPAWN)

## 动画函数
func _spawn_instance():
	if instance!=null:
		instance.playExit()
	instance = ItemInstance.new()
	instance.sprite_scale = instanceScale
	instance.set_compound(storedItem)
	storepoint.add_child(instance)
	instance.position = Vector2.ZERO
	instance.playEnter()
## 动画函数
func _despawn_instance():
	if instance:
		instance.playExit()
		instance = null
@rpc("unreliable", "call_remote")
func syncAnim(type:int):
	match type:
		AnimType.STORE: shake(4)
		AnimType.TAKE: shake(6)
		AnimType.SPAWN: _spawn_instance()
		AnimType.DESPAWN: _despawn_instance()
		AnimType.TIP_DESPAWN: tipDespawnAnim(false)
		AnimType.TIP_DESPAWN_DONE: tipDespawnAnim(true)
## 主机使用的despawn函数，自动同步至所有客户端
## 实际上客机也能使用。
func despawnInstance():
	# 主机自己播放一次动画
	_despawn_instance()
	# 判断是否为主机，若是则同步客户端
	if multiplayer.is_server():
		syncAnim.rpc(AnimType.DESPAWN)
## 主机使用的spawn函数，自动同步至所有客户端
func spawnInstance():
	_spawn_instance()
	if multiplayer.is_server():
		syncAnim.rpc(AnimType.SPAWN)
func tipDespawn(isDone:bool):
	tipDespawnAnim(isDone)
	if multiplayer.is_server():
		var sytc=AnimType.TIP_DESPAWN
		if isDone:sytc=AnimType.TIP_DESPAWN_DONE
		syncAnim.rpc(sytc)
func tipDespawnAnim(isDone:bool):
	progressTip.setHide(isDone)
## 客机收取物品同步信息的函数
@rpc("unreliable", "call_remote")
func storeSyncRemote(contain: Dictionary, processPoint: int):
	var compound = ItemCompound.new()
	compound.contain = contain
	compound.processPoint = processPoint
	storedItem = compound
	_refresh_current_recipe()
## 客机同步清空的函数
@rpc("unreliable", "call_remote")
func takeSyncRemote():
	storedItem = null
	currentRecipe = null

func shake(count:int):
	var orig_pos = sprite.position
	var tween = create_tween()
	for i in count:
		var offset = Vector2(randf_range(-3, 3), randf_range(-2, 2))
		tween.tween_property(sprite, "position", orig_pos + offset, 0.03).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position", orig_pos, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
