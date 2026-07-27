extends Node

var _registry:Dictionary={}
var _active:Dictionary={}
var _uid_counter:int=0

func register(id:String, scene:PackedScene):
	_registry[id]=scene

func spawn(id:String, parent:Node, data:Dictionary)->Node:
	var node=_registry[id].instantiate()
	node.entity_type=id
	node.entity_uid=_uid_counter
	_uid_counter+=1
	node.name="%s_%d"%[id,node.entity_uid]
	node.from_dict(data)
	parent.add_child(node)
	node.on_spawned()
	_active[node.entity_uid]=node
	return node

func spawn_networked(id:String, parent:Node, data:Dictionary)->Node:
	var node=spawn(id,parent,data)
	_rpc_spawn_entity.rpc(id,data,node.entity_uid)
	return node

func recycle(id:String, node:Node):
	var uid=node.entity_uid
	_active.erase(uid)
	if node.has_method("on_recycled"):
		node.on_recycled()
	if multiplayer.is_server():
		_rpc_recycle_entity.rpc(uid)
	node.queue_free()

@rpc("authority","unreliable")
func _rpc_spawn_entity(id:String, data:Dictionary, uid:int):
	if multiplayer.is_server():
		return
	var node=_registry[id].instantiate()
	node.entity_type=id
	node.entity_uid=uid
	node.name="%s_%d"%[id,uid]
	node.from_dict(data)
	var level=LevelControllerBase.INSTANCE
	if level:
		level.entities.add_child(node)
	node.on_spawned()
	_active[uid]=node

@rpc("authority","unreliable")
func _rpc_recycle_entity(uid:int):
	if multiplayer.is_server():
		return
	var node=_active.get(uid)
	if not node:
		return
	_active.erase(uid)
	if node.has_method("on_recycled"):
		node.on_recycled()
	node.queue_free()
