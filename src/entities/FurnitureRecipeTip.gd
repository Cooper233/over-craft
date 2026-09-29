extends Node2D
class_name FurnitureRecipeTip

@export var showDistance:float = 64.0
@export var mouseShowDistance:float = 48.0
@export var refreshInterval:float = 0.1
@export_range(0.1, 1.5, 0.05) var displayScale:float = 0.34:
	set(value):
		displayScale = value
		if is_instance_valid(tip):
			tip.setDisplayScale(displayScale)

var host:Node
var tip:TipRecipe
var refreshCooldown:float = 0.0
var lastContentSignature:String = ""

func _ready() -> void:
	host = get_parent()
	await get_tree().process_frame
	if not is_instance_valid(LevelControllerBase.INSTANCE):
		return
	tip = LevelControllerBase.INSTANCE.mapStaticUI.registerRecipeTip(self)
	tip.setDisplayScale(displayScale)
	_refreshTipContent()

func _process(delta:float) -> void:
	if not is_instance_valid(tip):
		return
	refreshCooldown -= delta
	if refreshCooldown <= 0.0:
		refreshCooldown = refreshInterval
		_refreshTipContent()
		_refreshNearbyState()

func _exit_tree() -> void:
	if is_instance_valid(LevelControllerBase.INSTANCE) and LevelControllerBase.INSTANCE.mapStaticUI:
		LevelControllerBase.INSTANCE.mapStaticUI.unregisterRecipeTip(self)

func _refreshTipContent() -> void:
	var storedItem:ItemCompound = host.getTipItem() if host.has_method("getTipItem") else host.get("storedItem") as ItemCompound
	var currentRecipe:ItemProcessRecipe = host.getTipRecipe() if host.has_method("getTipRecipe") else host.get("currentRecipe") as ItemProcessRecipe
	var nextSignature:String = _buildContentSignature(storedItem, currentRecipe)
	if nextSignature == lastContentSignature:
		return
	lastContentSignature = nextSignature
	tip.setContent(storedItem, currentRecipe)

func _refreshNearbyState() -> void:
	var player:Player = PlayerController.controlled_player
	var isPlayerNearby:bool = is_instance_valid(player) \
		and player.global_position.distance_squared_to(global_position) <= showDistance * showDistance
	var mousePosition:Vector2 = get_global_mouse_position()
	var isMouseNearby:bool = mousePosition.distance_squared_to(global_position) \
		<= mouseShowDistance * mouseShowDistance
	tip.setNearby(isPlayerNearby or isMouseNearby)

func _buildContentSignature(item:ItemCompound, recipe:ItemProcessRecipe) -> String:
	if not item:
		return "empty"
	var itemIds:Array = item.contain.keys()
	itemIds.sort()
	var parts:PackedStringArray = []
	for itemId in itemIds:
		parts.append("%s:%s" % [itemId, item.contain[itemId]])
	parts.append("->" + (recipe.result if recipe else ""))
	return "|".join(parts)
