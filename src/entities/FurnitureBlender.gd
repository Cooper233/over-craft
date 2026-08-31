### 家具-搅拌机
### TODO:问题与菜板类似，建议后期修改
extends FurnitureBase
class_name FurnitureBlender

enum AnimType {
	STORE,
	TAKE,
	SPAWN,
	DESPAWN,
	PROCESS,
	TIP_DESPAWN,
	TIP_DESPAWN_DONE
}

@export var collisionInteract:CollideInteractableMark
@export var attackInteract:AttackIneractableMark
@export var storepoint:Node2D
@export var instanceScale:float = 0.5
@export var acceptType:String = "blender"
@export var progressTip:FurnitureProgressTip

@onready var sprite:Node2D=$Sprite

var interactCooldown:float=0
var storedItem:ItemCompound
var currentRecipe:ItemProcessRecipe
var instance:ItemInstance
var isProcessing:bool=false
var processCooldown:float=0

func _ready() -> void:
	super()
	collisionInteract.register(self)
	attackInteract.register(self)

func _physics_process(delta: float) -> void:
	if interactCooldown>0:
		interactCooldown-=delta
	if is_multiplayer_authority() and isProcessing and storedItem and currentRecipe:
		processCooldown-=delta
		if processCooldown<=0:
			processCooldown=1.0
			storedItem.processPoint+=10
			if currentRecipe.checkCouldTransfer(storedItem):
				GlobalSoundManager.playSoundForAll("fx/itemDone", sprite.global_position,-5)
				storedItem=ItemCompound.createCompound(currentRecipe.result)
				storeSyncRemote.rpc(storedItem.contain, 0)
				isProcessing=false
				tipDespawn(true)
				_refresh_current_recipe()
				despawnInstance()
				spawnInstance()
			else:
				syncAnim(AnimType.PROCESS)
				syncAnim.rpc(AnimType.PROCESS)
				storeSyncRemote.rpc(storedItem.contain.duplicate(), storedItem.processPoint)
			
			
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
		if is_multiplayer_authority() and not isProcessing:
			GlobalSoundManager.playSoundForAll("fx/machineStart", sprite.global_position)
			isProcessing=true
			processCooldown=1.0
			syncAnim(AnimType.PROCESS)
			syncAnim.rpc(AnimType.PROCESS)
		return true
	if player.items.size() == 0:
		return _take_item(player)
	return false

func _take_item(player:Player) -> bool:
	GlobalSoundManager.playSoundForAll("fx/get_item", sprite.global_position)
	interactCooldown = 0.2
	if is_multiplayer_authority():
		player.tryToGetItem(storedItem)
		storedItem = null
		currentRecipe = null
		isProcessing = false
		processCooldown = 0
		storeSyncRemote.rpc({}, 0)
		despawnInstance()
		syncAnim(AnimType.TAKE)
		syncAnim.rpc(AnimType.TAKE)
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
func onItemCollide(item:MovingItem)->bool:
	addItemToStorange(item.contained)
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
func _on_sync_request(requester_id: int) -> void:
	if storedItem:
		_rpc_sync_state.rpc_id(requester_id, storedItem.contain.duplicate(), storedItem.processPoint, isProcessing)

@rpc("authority", "unreliable")
func _rpc_sync_state(contain: Dictionary, processPoint: int, _isProcessing: bool) -> void:
	storedItem = ItemCompound.new()
	storedItem.contain = contain
	storedItem.processPoint = processPoint
	isProcessing = _isProcessing
	if isProcessing:
		processCooldown = 1.0
	_refresh_current_recipe()
	_spawn_instance()

func _spawn_instance():
	if instance!=null:
		instance.playExit()
	instance = ItemInstance.new()
	instance.sprite_scale = instanceScale
	instance.set_compound(storedItem)
	storepoint.add_child(instance)
	instance.position = Vector2.ZERO
	instance.playEnter()

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
		AnimType.PROCESS:longshake()
		AnimType.TIP_DESPAWN: tipDespawnAnim(false)
		AnimType.TIP_DESPAWN_DONE: tipDespawnAnim(true)

func despawnInstance():
	_despawn_instance()
	if multiplayer.is_server():
		syncAnim.rpc(AnimType.DESPAWN)

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
@rpc("unreliable", "call_remote")
func storeSyncRemote(contain: Dictionary, processPoint: int):
	var compound = ItemCompound.new()
	compound.contain = contain
	compound.processPoint = processPoint
	storedItem = compound
	_refresh_current_recipe()

@rpc("unreliable", "call_remote")
func takeSyncRemote():
	storedItem = null
	currentRecipe = null
	isProcessing = false
	processCooldown = 0
func longshake():
	GlobalSoundManager.playSoundForAll("fx/machineConstant.ogg", sprite.global_position,-8)
	var orig_pos = sprite.position
	var tween = create_tween()
	var count:int=floor(1.0/0.03)
	for i in count:
		var offset = Vector2(randf_range(-1,1), randf_range(-1, 1))
		tween.tween_property(sprite, "position", orig_pos + offset, 0.03).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position", orig_pos, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
func shake(count:int):
	var orig_pos = sprite.position
	var tween = create_tween()
	for i in count:
		var offset = Vector2(randf_range(-3, 3), randf_range(-2, 2))
		tween.tween_property(sprite, "position", orig_pos + offset, 0.03).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position", orig_pos, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
