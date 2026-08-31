class_name PlayerAttackComponent

extends Node

@export var hitForce=300

var cooldown_fur:float=0.25
var cooldown_hit:float=0.75
var cooldown_miss:float=0.1
var nowCooldown:float=0.0

@export var player:Player

func checkCouldAttack()->bool:
	return nowCooldown<=0

func _physics_process(delta: float) -> void:
	if(nowCooldown>0):
		nowCooldown-=delta

func triggerAttack():
	if not checkCouldAttack():
		return
	var hit:bool=false
	var hitEntity:bool=false
	
	var nearest_target = null
	var nearest_dist = INF
	var nearest_is_body = false
	var player_pos = player.global_position
	for i in player.attackArea.get_overlapping_bodies():
		if i == player:
			continue
		var d = player_pos.distance_squared_to(i.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest_target = i
			nearest_is_body = true
	for i in player.attackArea.get_overlapping_areas():
		var d = player_pos.distance_squared_to(i.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest_target = i
			nearest_is_body = false
	if nearest_target:
		hit = true
		if nearest_is_body:
			hitEntity = true
			if nearest_target.has_method("applyImpulse"):
				nearest_target.applyImpulse(
					player_pos.direction_to(nearest_target.global_position),
					hitForce
				)
	player.visual.addOtherSquashModifier(-0.4)
	player.containerComponent.addExtraYOffset(5)
	if hit:
		GlobalSoundManager.playSoundForAll("fx/kick",player.global_position,-2)
		nowCooldown=cooldown_fur
		if hitEntity:
			nowCooldown=cooldown_hit
		if nearest_target is AttackIneractableMark:
			nearest_target.onInteract(player,true)
		if nearest_target is MovingItem:
			var contained=nearest_target.contained
			var dir=Vector2.RIGHT.rotated(player.box.rotation)
			LevelControllerBase.INSTANCE.spawnEntity(
				"moving_item",nearest_target.global_position,
				{"dir":dir,"speed":300,"contain":contained.contain,"pp":contained.processPoint}
			)
			GlobalSoundManager.playSoundForAll("fx/item_grounded",player.global_position,-5)
			GlobalEntityManager.recycle(nearest_target.entity_uid)
	else:
		GlobalSoundManager.playSoundForAll("fx/smack",player.global_position,-3)
		nowCooldown=cooldown_miss
func triggerInteract():
	var hit:bool=false
	var hitEntity:bool=false
	
	var nearest_target = null
	var nearest_dist = INF
	var nearest_is_body = false
	var player_pos = player.global_position
	for i in player.attackArea.get_overlapping_bodies():
		if i == player:
			continue
		var d = player_pos.distance_squared_to(i.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest_target = i
			nearest_is_body = true
	for i in player.attackArea.get_overlapping_areas():
		var d = player_pos.distance_squared_to(i.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest_target = i
			nearest_is_body = false
	if nearest_target:
		hit = true
		if nearest_is_body:
			hitEntity = true
	if hit:
		player.visual.addOtherSquashModifier(-0.2)
		player.containerComponent.addExtraYOffset(1)
		if nearest_target is AttackIneractableMark:
			nearest_target.onInteract(player,false)
		if nearest_target is MovingItem:
			if player.items.size()<=0:
				var contained=nearest_target.contained
				player.tryToGetItem(contained)
				GlobalSoundManager.playSoundForAll("fx/itemDone1",player.global_position,-3)
				GlobalEntityManager.recycle(nearest_target.entity_uid)
	else:
		pass
