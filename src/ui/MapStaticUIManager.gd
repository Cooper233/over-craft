extends Node
class_name MapStaticUIManager
const progressBarPrefab:PackedScene = preload("res://prefabs/AdvProgressBar.tscn")
const recipeTipPrefab:PackedScene = preload("res://prefabs/TipRecipe.tscn")

var recipeTips:Dictionary = {}

func _process(_delta:float) -> void:
	for anchor in recipeTips.keys():
		if not is_instance_valid(anchor):
			var orphanTip:TipRecipe = recipeTips[anchor]
			if is_instance_valid(orphanTip):
				orphanTip.queue_free()
			recipeTips.erase(anchor)
			continue
		var tip:TipRecipe = recipeTips[anchor]
		tip.setWorldPosition(anchor.global_position)

func spawnProgressBar(globalPosition:Vector2)->AdvProgressBar:
	var progressBar:AdvProgressBar = progressBarPrefab.instantiate()
	add_child(progressBar)
	progressBar.setPos(globalPosition.x, globalPosition.y)
	return progressBar

func registerRecipeTip(anchor:Node2D) -> TipRecipe:
	if recipeTips.has(anchor):
		return recipeTips[anchor]
	var tip:TipRecipe = recipeTipPrefab.instantiate()
	add_child(tip)
	recipeTips[anchor] = tip
	tip.setWorldPosition(anchor.global_position)
	return tip

func unregisterRecipeTip(anchor:Node2D) -> void:
	if not recipeTips.has(anchor):
		return
	var tip:TipRecipe = recipeTips[anchor]
	recipeTips.erase(anchor)
	if is_instance_valid(tip):
		tip.queue_free()
