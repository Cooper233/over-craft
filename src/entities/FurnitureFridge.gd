extends FurnitureBase
class_name FurnitureFridge

@export var collisionInteract:CollideInteractableMark
@export var attackInteract:AttackIneractableMark
@export var storePoint:Node2D
@export var instanceScale:float = 0.5
var storedId:String="steel"

@onready var sprite:Node2D=$Sprite

var interactCooldown:float=0
var _instance:ItemInstance

func _ready() -> void:
	collisionInteract.register(self)
	attackInteract.register(self)
	_rebuild_instance()

func _physics_process(delta: float) -> void:
	if interactCooldown>0:
		interactCooldown-=delta

func isValid()->bool:
	return interactCooldown<=0

func onCollideInteract(player:Player)->bool:
	genItem(player)
	return true
func onAttackInteract(player:Player)->bool:
	genItem(player)
	return true
func onInteract(player:Player):
	return false
func genItem(player:Player):
	GlobalSoundManager.playSoundForAll("fx/get_item",sprite.global_position)
	interactCooldown=0.2
	_play_get_animation()
	if is_multiplayer_authority():
		playGetAnimationRemote.rpc()
		player.tryToGetItem(ItemCompound.createCompound(storedId))
@rpc("unreliable", "call_remote")
func playGetAnimationRemote():
	_play_get_animation()
func _rebuild_instance():
	if _instance:
		_instance.queue_free()
	_instance = ItemInstance.new()
	_instance.sprite_scale = instanceScale
	_instance.set_compound(ItemCompound.createCompound(storedId))
	storePoint.add_child(_instance)
	_instance.position = Vector2.ZERO
	_instance.playEnter()

func _play_get_animation():
	var orig_pos = sprite.position
	var orig_scale = sprite.scale

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "position", orig_pos + Vector2(0, -16), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2(0.65, 1.4), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.set_parallel(false)
	tween.tween_interval(0.06)
	tween.set_parallel(true)
	tween.tween_property(sprite, "position", orig_pos, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", orig_scale, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
