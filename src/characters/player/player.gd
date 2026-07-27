extends RigidBody2D

class_name Player

@export var speed: float = 400.0
@export var acceleration: float = 8.0
@export var turn_rate: float = 0.0
@export var sync_smooth: float = 15.0
@export_group("collision settings")
@export var attackArea:Area2D

var player_owner_id: int = 0
var move_direction: Vector2 = Vector2.ZERO
var _smoothed_direction: Vector2 = Vector2.ZERO
var input_influence: float = 1.0
var input_influence_timer: float = 0.0
const INFLUENCE_RECOVERY_SPEED: float = 5.0
var _sync_target_pos: Vector2
var _sync_target_vel: Vector2
var _sync_target_rot: float

@onready var visual: EntitySpriteController = $Visual
@onready var box:Node2D=$boxCenter
@onready var attackComponent:PlayerAttackComponent=$AttackComponent
@onready var containerComponent:PlayerItemContainer=$ItemContainer
@onready var _physics_material: PhysicsMaterial = PhysicsMaterial.new()


var items:Array=[]

func _ready() -> void:
	_sync_target_pos = global_position
	_sync_target_rot = rotation
	_physics_material.absorbent = false
	physics_material_override = _physics_material
	if player_owner_id == multiplayer.get_unique_id():
		PlayerController.assign_player(self)
	if not is_multiplayer_authority():
		freeze = true
		requestFullSync()
	#items.append(ItemCompound.creas

func _physics_process(delta: float) -> void:
	if input_influence_timer > 0.0:
		input_influence_timer -= delta
	elif input_influence < 1.0:
		input_influence = lerp(input_influence, 1.0, 1.0 - exp(-INFLUENCE_RECOVERY_SPEED * delta))

	if is_multiplayer_authority():
		if turn_rate > 0.0:
			_smoothed_direction = _smoothed_direction.lerp(
				move_direction, 1.0 - exp(-turn_rate * delta)
			)
		else:
			_smoothed_direction = move_direction
		_sync_state.rpc(global_position, linear_velocity, rotation)
	else:
		var weight = 1.0 - exp(-sync_smooth * delta)
		global_position = global_position.lerp(_sync_target_pos, weight)
		rotation = lerp_angle(rotation, _sync_target_rot, weight)
		linear_velocity = _sync_target_vel
	if linear_velocity.length() > 0.1:
		visual.setFlip(true, linear_velocity.x < 0)
	visual.updateMovement(delta,linear_velocity,speed)
	$ItemContainer.updateMovement(delta,linear_velocity,speed)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	_physics_material.bounce = 1.0 - input_influence
	_physics_material.friction = input_influence
	if not is_multiplayer_authority():
		return
	var target_velocity = _smoothed_direction * speed
	if input_influence < 1.0:
		target_velocity = target_velocity.lerp(state.linear_velocity, 1.0 - input_influence)
	var velocity_diff = target_velocity - state.linear_velocity
	state.apply_central_force(velocity_diff * acceleration)

	_check_collision(state)

func _check_collision(state: PhysicsDirectBodyState2D) -> void:
	if not is_multiplayer_authority():
		return
	var vel = state.linear_velocity
	if vel.length() < 0.01:
		return
	var col = KinematicCollision2D.new()
	if not test_move(state.transform, vel * state.step, col):
		return
	var collider = col.get_collider()
	var layer:int=0
	if not collider is CollisionObject2D:
		if collider is TileMapLayer:
			var tm:TileMapLayer=collider
			layer=tm.tile_set.get_physics_layer_collision_layer(0)
		else:
			return
	else:
		layer = collider.collision_layer
	if layer & 2 and input_influence < 0.9:
		var reflection = vel.normalized().bounce(col.get_normal())
		if reflection.length() > 0.01:
			apply_central_impulse(reflection * 30.0)
			apply_move_inertia(0, 0.1)
		if collider is CollideInteractableMark:
			collider.onInteract(self)
	elif layer & 1:
		var move_dir = _smoothed_direction
		if move_dir.length() < 0.01:
			move_dir = vel.normalized()
		if move_dir.length() > 0.01:
			var lateral = Vector2(-move_dir.y, move_dir.x)
			var to_collider = collider.global_position - global_position
			apply_central_impulse((lateral if lateral.dot(to_collider) > 0 else -lateral) * 30.0)
			apply_move_inertia(0, 0.05)
			visual.addOtherSquashModifier(0.1)
			$ItemContainer.addExtraYOffset(-5)

func apply_move_inertia(coefficient: float, duration: float) -> void:
	input_influence = clampf(coefficient, 0.0, 1.0)
	input_influence_timer = duration

func applyImpulse(dir:Vector2,force:float,recover:float=0.35):
	apply_central_impulse(dir*force)
	apply_move_inertia(0,recover)

@rpc("unreliable", "call_remote")
func _sync_state(pos: Vector2, vel: Vector2, rot: float) -> void:
	_sync_target_pos = pos
	_sync_target_vel = vel
	_sync_target_rot = rot

@rpc("any_peer", "call_remote", "unreliable")
func send_aim_angle(angle: float) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != player_owner_id:
		return
	box.rotation = angle
	aimingRotation=angle
	_sync_aim.rpc(angle)
var aimingRotation:float=0
@rpc("authority", "call_remote", "unreliable")
func _sync_aim(angle: float) -> void:
	box.rotation = angle
	aimingRotation=angle

@rpc("any_peer", "call_remote", "unreliable")
func receive_input(direction: Vector2) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != player_owner_id:
		return
	move_direction = direction
func tryToAttack()->void:
	attackComponent.triggerAttack()
@rpc("any_peer", "call_remote", "unreliable")
func tryToAttackRemote()->void:
	if multiplayer.get_remote_sender_id() != player_owner_id:
		return
	tryToAttack()
func tryToInteract()->void:
	attackComponent.triggerInteract()
@rpc("any_peer", "call_remote", "unreliable")
func tryToInteractRemote()->void:
	if multiplayer.get_remote_sender_id() != player_owner_id:
		return
	tryToInteract()
func requestFullSync() -> void:
	if is_multiplayer_authority():
		return
	_request_full_sync.rpc_id(1)

@rpc("any_peer", "call_remote", "unreliable")
func _request_full_sync() -> void:
	if not multiplayer.is_server():
		return
	syncItemsToAll()

func tryToGetItem(item:ItemCompound):
	if not is_multiplayer_authority():return
	if items.size()>0:
		return
	items.append(item)
	syncItemsToAll()
	$ItemContainer.rebuild()
@rpc("any_peer", "call_remote", "unreliable")
func tryToSpecialMoveRemote()->void:
	if multiplayer.get_remote_sender_id() != player_owner_id:
		return
	tryToSpecialMove()
func tryToSpecialMove():
	if items.size()>0:
		ejectItem()
func ejectItem():
	var compound=items[0]
	items.remove_at(0)
	var dir=Vector2.RIGHT.rotated(box.rotation)
	LevelControllerBase.INSTANCE.spawnEntity(
		"moving_item",box.global_position,
		{"dir":dir,"speed":300,"contain":compound.contain,"pp":compound.processPoint}
	)
	$ItemContainer.rebuild()
	syncItemsToAll()
	
	
func syncItemsToAll() -> void:
	if not is_multiplayer_authority():
		return
	var data: Array = []
	for c in items:
		var compound = c as ItemCompound
		if compound:
			data.append({
				"contain": compound.contain.duplicate(),
				"processPoint": compound.processPoint
			})
	_sync_items.rpc(data)

@rpc("authority", "call_remote", "unreliable")
func _sync_items(data: Array) -> void:
	items.clear()
	for d in data:
		var c = ItemCompound.new()
		c.contain = d.contain
		c.processPoint = d.processPoint
		items.append(c)
	$ItemContainer.rebuild()
