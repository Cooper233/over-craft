extends FurnitureBase
class_name FurnitureDesk

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

func onInteract(player:Player)->bool:
	if storedItem:
		return false
	if player.items.size() == 0:
		return false
	GlobalSoundManager.playSoundForAll("fx/click", sprite.global_position)
	interactCooldown = 0.2
	if is_multiplayer_authority():
		storedItem = player.items[0]
		_spawn_instance()
		_play_store_animation()
		storeSyncRemote.rpc(storedItem.contain.duplicate(), storedItem.processPoint)
		player.items.remove_at(0)
		player.syncItemsToAll()
		player.containerComponent.rebuild()
	return true

func onAttackInteract(player:Player)->bool:
	if not storedItem:
		return false
	if player.items.size() > 0:
		return false
	GlobalSoundManager.playSoundForAll("fx/get_item", sprite.global_position)
	interactCooldown = 0.2
	if is_multiplayer_authority():
		_play_get_animation()
		player.tryToGetItem(storedItem)
		storedItem = null
		_despawn_instance()
		takeSyncRemote.rpc()
	return true

func _on_sync_request(requester_id: int) -> void:
	if storedItem:
		_rpc_sync_state.rpc_id(requester_id, storedItem.contain.duplicate(), storedItem.processPoint)

@rpc("authority", "unreliable")
func _rpc_sync_state(contain: Dictionary, processPoint: int) -> void:
	storedItem = ItemCompound.new()
	storedItem.contain = contain
	storedItem.processPoint = processPoint
	_spawn_instance()

func _spawn_instance():
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
func storeSyncRemote(contain: Dictionary, processPoint: int):
	var compound = ItemCompound.new()
	compound.contain = contain
	compound.processPoint = processPoint
	storedItem = compound
	_spawn_instance()
	_play_store_animation()

@rpc("unreliable", "call_remote")
func takeSyncRemote():
	_despawn_instance()
	_play_get_animation()

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
