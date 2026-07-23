extends FurnitureBase
class_name FurnitureTrashcan

@export var collisionInteract:CollideInteractableMark
@export var attackInteract:AttackIneractableMark
@export var storepoint:Node2D
@export var instanceScale:float = 0.5

@onready var sprite:Node2D=$Sprite

var interactCooldown:float=0

func _ready() -> void:
	collisionInteract.register(self)
	attackInteract.register(self)

func _physics_process(delta: float) -> void:
	if interactCooldown>0:
		interactCooldown-=delta

func isValid()->bool:
	return interactCooldown<=0

func onCollideInteract(player:Player)->bool:
	return false

func onAttackInteract(player:Player)->bool:
	return false

func onInteract(player:Player)->bool:
	if player.items.size() == 0:
		return false
	GlobalSoundManager.playSoundForAll("fx/click", sprite.global_position)
	interactCooldown = 0.2
	if is_multiplayer_authority():
		var compound = player.items[0]
		_spoil_instance(compound)
		_play_trash_animation()
		playTrashAnimationRemote.rpc(compound.contain.duplicate(), compound.processPoint)
		player.items.remove_at(0)
		player.syncItemsToAll()
		player.containerComponent.rebuild()
	return true

func _spoil_instance(compound: ItemCompound):
	var inst = ItemInstance.new()
	inst.sprite_scale = instanceScale
	inst.set_compound(compound)
	storepoint.add_child(inst)
	inst.position = Vector2.ZERO
	inst.playExit()

@rpc("unreliable", "call_remote")
func playTrashAnimationRemote(contain: Dictionary, processPoint: int):
	var compound = ItemCompound.new()
	compound.contain = contain
	compound.processPoint = processPoint
	_spoil_instance(compound)
	_play_trash_animation()

func _play_trash_animation():
	var orig_pos = sprite.position

	var tween = create_tween()
	for i in 5:
		var offset = Vector2(randf_range(-3, 3), randf_range(-2, 2))
		tween.tween_property(sprite, "position", orig_pos + offset, 0.03).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position", orig_pos, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
