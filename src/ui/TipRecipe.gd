extends Control
class_name TipRecipe

const itemIconPrefab:PackedScene = preload("res://prefabs/ItemIcon.tscn")

@onready var panel:NinePatchRect = $Panel
@onready var contentContainer:HBoxContainer = $Panel/Content
@onready var ingredientContainer:HBoxContainer = $Panel/Content/Ingredients
@onready var arrowTexture:TextureRect = $Panel/Content/Arrow
@onready var resultIcon:ItemIcon = $Panel/Content/ResultIcon

@export var showDuration:float = 0.16
@export var hideDuration:float = 0.12
@export var displayScale:float = 0.34

var currentItem:ItemCompound
var currentRecipe:ItemProcessRecipe
var anchorPosition:Vector2 = Vector2.ZERO
var verticalOffset:float = 0.0
var isNearby:bool = false
var isShown:bool = false
var activeTween:Tween
var flashTween:Tween
var rebuildVersion:int = 0
var expandedSize:Vector2 = Vector2(104.0, 88.0)

const collapsedWidth:float = 8.0

func _ready() -> void:
	expandedSize = size
	modulate.a = 0.0
	scale = Vector2.ONE * displayScale
	hide()

func setContent(item:ItemCompound, recipe:ItemProcessRecipe) -> void:
	currentItem = item
	currentRecipe = recipe
	_rebuildContent()
	_updateVisibility()

func setNearby(value:bool) -> void:
	if isNearby == value:
		return
	isNearby = value
	_updateVisibility()

func setDisplayScale(value:float) -> void:
	displayScale = max(value, 0.01)
	if activeTween and activeTween.is_valid():
		activeTween.kill()
	if flashTween and flashTween.is_valid():
		flashTween.kill()
	custom_minimum_size = expandedSize
	size = expandedSize
	scale = Vector2.ONE * displayScale
	verticalOffset = 0.0
	modulate.a = 1.0 if isShown else 0.0
	panel.modulate = Color.WHITE
	_updatePosition()

func setWorldPosition(worldPosition:Vector2) -> void:
	anchorPosition = worldPosition
	_updatePosition()

func _rebuildContent() -> void:
	rebuildVersion += 1
	var currentVersion:int = rebuildVersion
	for child in ingredientContainer.get_children():
		child.queue_free()

	if not currentItem or currentItem.contain.is_empty():
		return

	var itemIds:Array = currentItem.contain.keys()
	itemIds.sort()
	for itemId in itemIds:
		var itemIcon:ItemIcon = itemIconPrefab.instantiate()
		ingredientContainer.add_child(itemIcon)
		itemIcon.setItem(str(itemId), int(currentItem.contain[itemId]))

	var hasRecipe:bool = currentRecipe != null and not currentRecipe.result.is_empty()
	arrowTexture.visible = hasRecipe
	resultIcon.visible = hasRecipe
	if hasRecipe:
		resultIcon.setItem(currentRecipe.result, 1)
	var ingredientWidth:float = itemIds.size() * 64.0 + max(itemIds.size() - 1, 0) * 5.0
	var recipeWidth:float = 122.0 if hasRecipe else 0.0
	expandedSize = Vector2(max(ingredientWidth + recipeWidth + 30.0, 104.0), 88.0)
	custom_minimum_size = expandedSize
	size = expandedSize

	await get_tree().process_frame
	if not is_instance_valid(self) or currentVersion != rebuildVersion:
		return
	var contentSize:Vector2 = contentContainer.get_combined_minimum_size()
	expandedSize = Vector2(max(contentSize.x + 30.0, 104.0), max(contentSize.y + 24.0, 88.0))
	custom_minimum_size = expandedSize
	reset_size()
	_updatePosition()

func _updateVisibility() -> void:
	var shouldShow:bool = isNearby and currentItem != null and not currentItem.contain.is_empty()
	if shouldShow == isShown:
		return
	isShown = shouldShow
	if activeTween and activeTween.is_valid():
		activeTween.kill()
	if flashTween and flashTween.is_valid():
		flashTween.kill()
	panel.modulate = Color.WHITE
	if shouldShow:
		_showFlat()
	else:
		_hideFlat()

func _showFlat() -> void:
	show()
	modulate.a = 0.0
	scale = Vector2.ONE * displayScale
	custom_minimum_size = Vector2(0.0, expandedSize.y)
	_setAnimatedWidth(collapsedWidth)
	_setVerticalOffset(2.0)
	activeTween = create_tween().set_parallel(true)
	activeTween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	activeTween.tween_property(self, "modulate:a", 1.0, showDuration * 0.55)
	activeTween.tween_method(_setVerticalOffset, 2.0, 0.0, showDuration)
	activeTween.tween_method(_setAnimatedWidth, collapsedWidth, expandedSize.x, showDuration) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	activeTween.chain().tween_callback(_finishShow)
	_playDoubleFlash()

func _hideFlat() -> void:
	if not visible:
		return
	custom_minimum_size = Vector2(0.0, expandedSize.y)
	activeTween = create_tween().set_parallel(true)
	activeTween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	activeTween.tween_property(self, "modulate:a", 0.0, hideDuration)
	activeTween.tween_method(_setVerticalOffset, 0.0, -3.0, hideDuration)
	activeTween.tween_method(_setAnimatedWidth, size.x, collapsedWidth, hideDuration) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	activeTween.chain().tween_callback(_finishHide)

func _finishShow() -> void:
	custom_minimum_size = expandedSize
	size = expandedSize
	_updatePosition()

func _finishHide() -> void:
	hide()
	custom_minimum_size = expandedSize
	size = expandedSize
	scale = Vector2.ONE * displayScale
	_updatePosition()

func _playDoubleFlash() -> void:
	flashTween = create_tween()
	flashTween.tween_interval(showDuration * 0.18)
	for flashIndex in 2:
		var flashColor:Color = Color(1.45, 1.45, 1.3, 1.0) if flashIndex == 0 \
			else Color(1.25, 1.4, 1.35, 1.0)
		flashTween.tween_property(panel, "modulate", flashColor, 0.035)
		flashTween.tween_property(panel, "modulate", Color.WHITE, 0.055)

func _setVerticalOffset(value:float) -> void:
	verticalOffset = value
	_updatePosition()

func _setAnimatedWidth(value:float) -> void:
	size = Vector2(value, expandedSize.y)
	_updatePosition()

func _updatePosition() -> void:
	pivot_offset = Vector2(size.x * 0.5, size.y)
	position = anchorPosition - pivot_offset + Vector2(0.0, verticalOffset)
