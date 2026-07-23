extends Camera2D

class_name CinemaCamera

var _target: Node2D = null

@export var enable_damping: bool = true
@export var damping_position: Vector2 = Vector2(8.0, 8.0)

@export var follow_offset: Vector2 = Vector2.ZERO

@export var dead_zone: Vector2 = Vector2.ZERO

@export var max_speed: float = 0.0

@export var look_ahead: Vector2 = Vector2.ZERO

@export var zoom_damping: float = 8.0
@export var default_zoom: Vector2 = Vector2.ONE

var _zoom_target: Vector2 = Vector2.ONE

var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_remaining: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	_find_target()
	zoom = default_zoom
	_zoom_target = default_zoom

func _physics_process(delta: float) -> void:
	if not _target or not _target.is_inside_tree():
		_find_target()
		return
	_follow(delta)
	_update_zoom(delta)
	_update_shake(delta)

func _find_target() -> void:
	if is_instance_valid(PlayerController.controlled_player):
		_target = PlayerController.controlled_player

func _follow(delta: float) -> void:
	var target_pos: Vector2 = _target.global_position + follow_offset

	var body := _target as RigidBody2D
	if body and look_ahead != Vector2.ZERO:
		target_pos += body.linear_velocity * look_ahead

	var diff: Vector2 = target_pos - global_position

	if dead_zone.x > 0 and absf(diff.x) < dead_zone.x:
		diff.x = 0.0
	if dead_zone.y > 0 and absf(diff.y) < dead_zone.y:
		diff.y = 0.0

	if diff == Vector2.ZERO:
		return

	var target_global: Vector2 = global_position + diff

	if enable_damping:
		target_global.x = _smooth_damp(
			global_position.x, target_global.x, delta, damping_position.x
		)
		target_global.y = _smooth_damp(
			global_position.y, target_global.y, delta, damping_position.y
		)

	if max_speed > 0.0:
		var move: Vector2 = target_global - global_position
		var len: float = move.length()
		if len > max_speed * delta:
			move = move.normalized() * max_speed * delta
			target_global = global_position + move

	global_position = target_global + _shake_offset

static func _smooth_damp(from: float, to: float, delta: float, damping: float) -> float:
	if damping <= 0.0:
		return to
	return lerpf(from, to, 1.0 - exp(-damping * delta))

func set_zoom_target(zoom_target: Vector2) -> void:
	_zoom_target = zoom_target

func zoom_to(zoom_target: Vector2) -> void:
	_zoom_target = zoom_target

func _update_zoom(delta: float) -> void:
	if zoom == _zoom_target:
		return
	zoom.x = _smooth_damp(zoom.x, _zoom_target.x, delta, zoom_damping)
	zoom.y = _smooth_damp(zoom.y, _zoom_target.y, delta, zoom_damping)

func shake(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_duration = duration
	_shake_remaining = duration

func _update_shake(delta: float) -> void:
	if _shake_remaining <= 0.0:
		_shake_offset = Vector2.ZERO
		return
	var decay := _shake_remaining / _shake_duration
	var mag := _shake_intensity * decay
	_shake_offset = Vector2(
		randf_range(-mag, mag),
		randf_range(-mag, mag)
	)
	_shake_remaining -= delta
