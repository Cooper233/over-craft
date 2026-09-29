extends FurnitureBase
class_name FurnitureDesk

enum AnimType {
	STORE,
	TAKE,
	SPAWN,
	DESPAWN,
}

@export var collisionInteract:CollideInteractableMark
@export var attackInteract:AttackIneractableMark
@export var storepoint:Node2D
@export var instanceScale:float = 0.5

@onready var sprite:Node2D=$Sprite

var interactCooldown:float=0
var storedItem:ItemCompound
var instance:ItemInstance

func _ready() -> void:
	super()
	collisionInteract.register(self)
	attackInteract.register(self)

func _physics_process(delta: float) -> void:
	if interactCooldown>0:
		interactCooldown-=delta

func isValid()->bool:
	return interactCooldown<=0

func onCollideInteract(player:Player)->bool:
	return false

func onItemCollide(item:MovingItem)->bool:
	if not is_multiplayer_authority() or not canStoreItem(item.contained):
		return false
	if is_multiplayer_authority():
		if storedItem:
			if storedItem.mergeCompound(item.contained):
				storeSyncRemote.rpc(storedItem.toData())
				_despawn_instance()
				_spawn_instance()
				syncAnim.rpc(AnimType.DESPAWN)
				syncAnim.rpc(AnimType.SPAWN)
		else:
			storedItem = item.contained
			storeSyncRemote.rpc(storedItem.toData())
			_spawn_instance()
			syncAnim.rpc(AnimType.SPAWN)
			syncAnim.rpc(AnimType.STORE)
	return true

func onInteract(player:Player)->bool:
	if not is_multiplayer_authority() or player.items.size() == 0:
		return false
	if not canStoreItem(player.items[0]):
		return false
	GlobalSoundManager.playSoundForAll("fx/click", sprite.global_position)
	interactCooldown = 0.2
	if is_multiplayer_authority():
		var playerItem = player.items[0]
		player.items.remove_at(0)
		player.syncItemsToAll()
		player.containerComponent.rebuild()
		if storedItem:
			if storedItem.mergeCompound(playerItem):
				storeSyncRemote.rpc(storedItem.toData())
				_despawn_instance()
				_spawn_instance()
				syncAnim.rpc(AnimType.DESPAWN)
				syncAnim.rpc(AnimType.SPAWN)
		else:
			storedItem = playerItem
			storeSyncRemote.rpc(storedItem.toData())
			_spawn_instance()
			syncAnim.rpc(AnimType.SPAWN)
			syncAnim.rpc(AnimType.STORE)
	return true

func onAttackInteract(player:Player)->bool:
	if not is_multiplayer_authority() or not storedItem:
		return false
	if player.items.size() > 0:
		return false
	GlobalSoundManager.playSoundForAll("fx/get_item", sprite.global_position)
	interactCooldown = 0.2
	if is_multiplayer_authority():
		_play_get_animation()
		syncAnim.rpc(AnimType.TAKE)
		player.tryToGetItem(storedItem)
		storedItem = null
		storeSyncRemote.rpc({})
		_despawn_instance()
		syncAnim.rpc(AnimType.DESPAWN)
	return true

func _on_sync_request(requester_id: int) -> void:
	_rpc_sync_state.rpc_id(requester_id, storedItem.toData() if storedItem else {})

@rpc("authority", "reliable")
func _rpc_sync_state(data:Dictionary) -> void:
	storeSyncRemote(data)

func canStoreItem(item:ItemCompound) -> bool:
	if not item or item.contain.is_empty():
		return false
	if not storedItem:
		return true
	return storedItem.canProcess() and item.canProcess() and storedItem.processPoint == 0 and item.processPoint == 0

func _spawn_instance():
	if not storedItem:
		return
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
		AnimType.STORE: _play_store_animation()
		AnimType.TAKE: _play_get_animation()
		AnimType.SPAWN: pass # The reliable content snapshot owns the item visual.
		AnimType.DESPAWN: pass

@rpc("authority", "reliable", "call_remote")
func storeSyncRemote(data:Dictionary):
	storedItem = ItemCompound.fromData(data) if not data.is_empty() else null
	_despawn_instance()
	if storedItem:
		_spawn_instance()

@rpc("unreliable", "call_remote")
func takeSyncRemote():
	storedItem = null

func _play_store_animation():
	var orig_pos = sprite.position

	var tween = create_tween()
	for i in 4:
		var offset = Vector2(randf_range(-3, 3), randf_range(-2, 2))
		tween.tween_property(sprite, "position", orig_pos + offset, 0.03).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position", orig_pos, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _play_get_animation():
	var orig_pos = sprite.position

	var tween = create_tween()
	for i in 6:
		var offset = Vector2(randf_range(-4, 4), randf_range(-3, 3))
		tween.tween_property(sprite, "position", orig_pos + offset, 0.03).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position", orig_pos, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
