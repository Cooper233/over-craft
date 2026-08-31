extends Node
class_name MapStaticUIManager
const pbPrefab=preload("res://prefabs/AdvProgressBar.tscn")



func spawnProgressBar(glob:Vector2)->AdvProgressBar:
	var pb:AdvProgressBar=pbPrefab.instantiate()
	add_child(pb)
	pb.setPos(glob.x,glob.y)
	return pb
