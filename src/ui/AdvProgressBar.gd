extends Control
class_name AdvProgressBar

@export var bar:TextureRect
@export var front:TextureRect
@export var introDuration:float = 0.3
@export var outroDuration:float = 0.3

var barMaterial:ShaderMaterial
var originPosition:Vector2=Vector2.ZERO

func _ready() -> void:
	barMaterial = bar.material.duplicate()
	bar.material = barMaterial

func setPos(x:float, y:float) -> void:
	position = Vector2(x, y)
	originPosition=position

func setProgress(val:float) -> void:
	barMaterial.set_shader_parameter("progress", clampf(val, 0.0, 1.0))

func setAlpha(val:float) -> void:
	barMaterial.set_shader_parameter("alpha", val)
	front.modulate.a = val

func intro() -> void:
	show()
	position.y=originPosition.y+30
	rotation=0
	setAlpha(0.0)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_method(setAlpha, 0.0, 1.0, introDuration*0.5)\
		.set_trans(Tween.TRANS_CIRC)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(self,"position:y",originPosition.y,introDuration)\
		.set_trans(Tween.TRANS_EXPO)\
		.set_ease(Tween.EASE_OUT)
func outro() -> void:
	var tween = create_tween()
	tween.tween_method(setAlpha, 1.0, 0.0, outroDuration)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self,"position",originPosition+Vector2(0,10),introDuration)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_CIRC)
	await tween.finished
	hide()
func outroDone()->void:
	var halfDuration = 0.25
	
	var tween1 = create_tween()
	tween1.set_parallel(false)
	tween1.tween_property(self, "position:y", originPosition.y - 5, halfDuration*1.25)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_QUAD)
	tween1.tween_property(self, "position:y", originPosition.y + 30, halfDuration*0.75)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_QUAD)
	
	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.tween_method(setAlpha, 1.0, 0.0, halfDuration*2)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_EXPO)
	
	var tween3 = create_tween()
	var rot = (randf() * 90 - 45) * 3.14 / 180
	tween3.tween_property(self, "rotation", rot, halfDuration*2)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_SINE)
	
	await tween2.finished
