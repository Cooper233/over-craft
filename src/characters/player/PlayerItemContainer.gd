extends Node2D
class_name PlayerItemContainer

@export var radius: float = 28.0
@export var instance_scale: float = 0.5

@export_group("Movement Animation")
@export var maxLeanAngle: float = 8.0
@export var leanSmooth: float = 10.0
@export var bounceAmplitude: float = 2.0
@export var bouncePhaseOffset: float = 2.0
@export var bounceSmooth: float = 8.0
@export var extraYOffsetSmooth: float = 12.0

var extraYOffset: float = 0.0

var _instances: Array[ItemInstance] = []
var _bounce_time: float = 0.0
var _origin_pos: Vector2
var _bounce_offsety: float = 0.0

func _ready() -> void:
	_origin_pos = position

func rebuild() -> void:
	for inst in _instances:
		inst.playExit()
	_instances.clear()

	var parent_player = get_parent() as Player
	if not parent_player:
		return

	var count = parent_player.items.size()
	if count == 0:
		return

	var angle_step = PI / (count+1)
	var start_angle = -PI

	for i in count:
		var compound = parent_player.items[i]
		var inst = ItemInstance.new()
		inst.sprite_scale = instance_scale
		inst.set_compound(compound)
		add_child(inst)
		_instances.append(inst)

		var angle = start_angle + (i+1) * angle_step
		inst.position = Vector2(cos(angle), sin(angle)) * radius
		inst.playEnter()

@rpc("unreliable", "call_remote")
func _sync_extraYOffset(val: float) -> void:
	extraYOffset = val

func addExtraYOffset(val: float) -> void:
	var player = get_parent() as Player
	if not player or not player.is_multiplayer_authority():
		return
	extraYOffset += val
	_sync_extraYOffset.rpc(extraYOffset)

func updateMovement(delta: float, velocity: Vector2, sprintSpeed: float) -> void:
	if delta >= 0.1:
		return

	var speedFactor = velocity.length() / sprintSpeed

	if speedFactor > 0.1:
		_bounce_time += delta * (0.5 + speedFactor * 2.0)
		var target = sin(_bounce_time * TAU + bouncePhaseOffset) * bounceAmplitude * speedFactor
		_bounce_offsety = lerp(_bounce_offsety, target, bounceSmooth * delta)
	else:
		_bounce_offsety = lerp(_bounce_offsety, 0.0, bounceSmooth * delta)

	extraYOffset = lerp(extraYOffset, 0.0, extraYOffsetSmooth * delta)
	position.y = _origin_pos.y + _bounce_offsety + extraYOffset

	var speedRatio = velocity.x / sprintSpeed
	var targetRotation = speedRatio * deg_to_rad(maxLeanAngle)
	rotation = lerp_angle(rotation, targetRotation, leanSmooth * delta)
