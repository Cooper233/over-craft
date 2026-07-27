extends Node


var controlled_player: Player = null
var aim_direction: Vector2 = Vector2.ZERO

func assign_player(player: Player) -> void:
	controlled_player = player
var mousePressed:bool=false

func _physics_process(_delta: float) -> void:
	if not controlled_player:
		return
	if not multiplayer.multiplayer_peer:
		return

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if multiplayer.is_server():
		controlled_player.move_direction = dir
	else:
		controlled_player.receive_input.rpc_id(1, dir)
	
	if Input.is_action_just_pressed("attack"):
		if multiplayer.is_server():
			controlled_player.tryToAttack()
		else:
			controlled_player.tryToAttackRemote.rpc_id(1)
	
	if Input.is_action_just_pressed("interact"):
		if multiplayer.is_server():
			controlled_player.tryToInteract()
		else:
			controlled_player.tryToInteractRemote.rpc_id(1)
	if Input.is_action_just_pressed("special"):
		if multiplayer.is_server():
			controlled_player.tryToSpecialMove()
		else:
			controlled_player.tryToSpecialMoveRemote.rpc_id(1)
	_update_aim()

func _update_aim() -> void:
	var angle: float
	if aim_direction.length() > 0:
		angle = aim_direction.angle()
	else:
		var mouse_pos = controlled_player.get_global_mouse_position()
		angle = (mouse_pos - controlled_player.global_position).angle()

	controlled_player.box.rotation = angle
	if not multiplayer.is_server():
		controlled_player.send_aim_angle.rpc_id(1, angle)
	elif controlled_player.is_multiplayer_authority():
		controlled_player._sync_aim.rpc(angle)
