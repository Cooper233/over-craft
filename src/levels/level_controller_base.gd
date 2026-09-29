extends Node2D
class_name LevelControllerBase

signal level_ready

@export var entities: Node2D
@export var spawn_points: Array[Marker2D]
@export var mapStaticUI:MapStaticUIManager

var orderManager:OrderManager

static var INSTANCE:LevelControllerBase

const PLAYER_SCENE = preload("res://src/characters/player/player.tscn")

const UI_PROGRESSBAR=preload("res://prefabs/AdvProgressBar.tscn")

func _ready() -> void:
	if not entities:
		entities = get_node_or_null("Entities")
	GlobalEntityManager.register("moving_item", preload("res://prefabs/MovingItem.tscn"))
	INSTANCE=self
	orderManager = get_node_or_null("OrderManager") as OrderManager
	level_ready.emit()

func spawn_player(for_peer: int, pos: Vector2) -> void:
	var node_name = "Player_%d" % for_peer
	if not entities or entities.has_node(node_name):
		return
	var player = PLAYER_SCENE.instantiate()
	player.name = node_name
	player.player_owner_id = for_peer
	player.global_position = pos
	entities.add_child(player)
	if multiplayer.is_server():
		player.set_multiplayer_authority(1)

func spawnEntity(entity_id:String, glob_pos:Vector2, data:Dictionary={}) -> Node:
	data["pos"]=glob_pos
	return GlobalEntityManager.spawn_networked(entity_id,entities,data)

func remove_player(for_peer: int) -> void:
	if not entities:
		return
	var node = entities.get_node_or_null("Player_%d" % for_peer)
	if node:
		node.queue_free()

func get_players() -> Array[Player]:
	if not entities:
		return []
	var result: Array[Player] = []
	for child in entities.get_children():
		if child is Player:
			result.append(child)
	return result

func get_spawn_position(index: int) -> Vector2:
	if spawn_points.is_empty():
		return Vector2(295, 142)
	return spawn_points[index % spawn_points.size()].global_position
