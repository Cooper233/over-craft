extends Node2D
class_name ItemInstance

var contained: ItemCompound

const MAX_SLOTS = 6
const SLOT_RADIUS = 10.0
const LERP_SPEED = 12.0
const DUP_OFFSET = 1.5

@export var sprite_scale: float = 0.5

var _slots: Array[Node2D] = []
var _target_positions: Array[Vector2] = []

func playEnter() -> void:
	var target_y = position.y
	position.y += 12*sprite_scale
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", target_y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func playExit() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 10*sprite_scale, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
	await tween.finished
var death_duration:float=0.4
var death_jump_height:float=10
func setAlpha(val:float):
	self.modulate.a=val
func playExit1() -> void:
	var halfDuration = death_duration / 2.0
	
	var tween1 = create_tween()
	tween1.set_parallel(false)
	tween1.tween_property(self, "position:y", position.y - death_jump_height, halfDuration)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_QUAD)
	tween1.tween_property(self, "position:y", position.y + 30, halfDuration)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_QUAD)
	
	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.tween_method(setAlpha, 1.0, 0.0, death_duration)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_EXPO)
	
	var tween3 = create_tween()
	var rot = (randf() * 90 - 45) * 3.14 / 180
	tween3.tween_property(self, "rotation", rot, death_duration)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_SINE)
	
	await tween2.finished
func set_compound(compound: ItemCompound) -> void:
	contained = compound
	_rebuild()

func _rebuild() -> void:
	for s in _slots:
		s.queue_free()
	_slots.clear()
	_target_positions.clear()

	if not contained or contained.contain.is_empty():
		return

	var ids = contained.contain.keys()
	var flat: Array[String] = []
	for id in ids:
		var cnt = contained.contain[id] as int
		for j in cnt:
			if flat.size() >= MAX_SLOTS:
				break
			flat.append(id)
		if flat.size() >= MAX_SLOTS:
			break

	var count = flat.size()
	var spacing = 8.0*sprite_scale
	var start = - (count - 1) * spacing / 2.0
	var dup_index: Dictionary = {}

	for i in count:
		var item_id = flat[count - 1 - i]

		var slot = Node2D.new()
		add_child(slot)
		_slots.append(slot)

		var sprite = Sprite2D.new()
		sprite.texture = GlobalTextureReader.get_texture(
			"res://assets/images/item/item_" + item_id + ".png"
		)
		sprite.centered = true
		sprite.scale = Vector2(sprite_scale, sprite_scale)
		slot.add_child(sprite)

		var base = Vector2(start + i * spacing, start + i * spacing)

		if not dup_index.has(item_id):
			dup_index[item_id] = 0
		var di = dup_index[item_id]
		dup_index[item_id] = di + 1
		var target = base + Vector2(-di, di) * DUP_OFFSET
		_target_positions.append(target)
		slot.position = target

func _process(delta: float) -> void:
	if delta > 0.1:
		return
	for i in range(_slots.size()):
		_slots[i].position = _slots[i].position.lerp(_target_positions[i], LERP_SPEED * delta)
