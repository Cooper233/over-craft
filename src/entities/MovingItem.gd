extends RigidBody2D
class_name MovingItem

var entity_type:String=""
var entity_uid:int=-1

var contained:ItemCompound
var dir:Vector2=Vector2.ZERO
var energeTime:float=2.0
var speed:float=200.0
var instance:ItemInstance
var dying:bool=false

func eject(_dir:Vector2, _speed:float):
	dir=_dir.normalized()
	speed=_speed
	energeTime=2.0
	linear_velocity=dir*speed

func _physics_process(delta: float) -> void:
	if dying:return
	if not is_multiplayer_authority():
		return
	if energeTime>0:
		energeTime-=delta
		linear_velocity=dir*speed
	else:
		linear_velocity=linear_velocity.lerp(Vector2.ZERO, 2.0*delta)
		if linear_velocity.length()<1.0:
			playExit()
			

func rebuild():
	if instance:
		instance.queue_free()
	if not contained or contained.contain.is_empty():
		return
	instance=ItemInstance.new()
	instance.sprite_scale=0.35
	instance.rotation=dir.angle()
	instance.set_compound(contained)
	add_child(instance)
	instance.position=Vector2.ZERO

func to_dict()->Dictionary:
	return {
		"pos": global_position,
		"dir": dir,
		"speed": speed,
		"contain": contained.contain if contained else {},
		"pp": contained.processPoint if contained else 0,
		"et": energeTime,
	}

func from_dict(data:Dictionary):
	global_position=data.get("pos",Vector2.ZERO)
	dir=data.get("dir",Vector2.ZERO)
	speed=data.get("speed",200.0)
	energeTime=data.get("et",2.0)
	contained=ItemCompound.new()
	contained.contain=data.get("contain",{})
	contained.processPoint=data.get("pp",0)

func on_spawned():
	rebuild()
	if dir!=Vector2.ZERO:
		linear_velocity=dir*speed

func on_recycled():
	contained=null
	dir=Vector2.ZERO
	energeTime=2.0
	speed=200.0
	linear_velocity=Vector2.ZERO
	if instance:
		instance.queue_free()
		instance=null
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if dying:return
	_check_collision(state)
@rpc("any_peer","reliable")
func playExitRemote(mode:int):
	if multiplayer.is_server():return
	match mode:
		0:playExit()
		1:playExit1()
func playExit()->void:
	dying=true
	await instance.playExit()
	if is_multiplayer_authority():
		GlobalEntityManager.recycle(entity_uid)
func playExit1()->void:
	dying=true
	await instance.playExit1()
	if is_multiplayer_authority():
		GlobalEntityManager.recycle(entity_uid)
func _check_collision(state: PhysicsDirectBodyState2D) -> void:
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
	if layer & 2 :
		if collider is CollideInteractableMark:
			var mark:CollideInteractableMark=collider
			if(mark.onItemInteract(self)):
				if is_multiplayer_authority():
					GlobalEntityManager.recycle(entity_uid)
				GlobalSoundManager.play_sound("fx/item_grounded",global_position)
	elif layer & (1<<4):
		collision_layer=0
		collision_mask=0
		playExit1()
		GlobalSoundManager.play_sound("fx/item_grounded",global_position)
