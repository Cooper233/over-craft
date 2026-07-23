extends AnimatedSprite2D
class_name EntitySpriteController

@export var shake_intensity: float = 5.0
@export var shake_duration: float = 0.3
@export var hurt_white_duration: float = 0.1
@export var death_jump_height: float = 50.0
@export var death_duration: float = 0.5

@export var shadowEnable: bool = true
@export var shadowOffset: Vector2 = Vector2.ZERO
@export var shadowScale: float = 1.0

@export_group("Movement Animation")
@export var maxLeanAngle: float = 15.0
@export var leanSmooth: float = 10.0
@export var maxStretch: float = 0.2
@export var maxConstantStretch: float = 1.0
@export var squashSmooth: float = 12.0
@export var otherSquashSmooth: float = 15.0
@export var bounceOffsetAmplitude: float = 3.0

var originalPosition: Vector2
var isShaking: bool = false
var hurtCount: int = 0
var shakeMod: float = 0.0
var isDying: bool = false
var shadow: Node2D
var alpha: float = 1.0

var originSpriteScale: Vector2 = Vector2(1, 1)
var bounceTime: float = 0.0
var otherSquashModifier: float = 1.0
var bounceOffset: Vector2 = Vector2.ZERO
var leanOffset:float=0

var _sync_otherSquashModifier:float=1.0

func _ready() -> void:
	self.material = self.material.duplicate()
	originalPosition = position
	originSpriteScale = scale
	
@rpc("unreliable", "call_remote")
func _sync_state(otherSquash:float) -> void:
	self.otherSquashModifier = otherSquash
	
func _physics_process(delta: float) -> void:
	pass
	#otherSquashModifier += lerp(0.0, 1.0 - otherSquashModifier, otherSquashSmooth * delta)
	#if is_multiplayer_authority():
		#_sync_state.rpc(otherSquashModifier)
	#else:
		#otherSquashModifier=_sync_otherSquashModifier
func addOtherSquashModifier(val:float)->void:
	if is_multiplayer_authority():
		otherSquashModifier+=val
		_sync_state.rpc(otherSquashModifier)
func _process(delta: float) -> void:
	if delta>0.1:
		return
	if shakeMod > 0:
		shakeMod += lerp(0.0, 0.0 - shakeMod, 5 * delta)
	
	if shadowEnable and shadow:
		shadow.scale = Vector2(shadowScale, shadowScale) * scale
		shadow.position = shadowOffset + bounceOffset * 0.1
		shadow.modulate.a = alpha
	otherSquashModifier += lerp(0.0, 1.0 - otherSquashModifier, otherSquashSmooth * delta)


func updateMovement(delta: float, velocity: Vector2, sprintSpeed: float) -> void:
	handleLeanAnimation(delta, velocity.x, sprintSpeed)
	handleSquashAndStretch(delta, velocity, sprintSpeed)

func handleLeanAnimation(delta: float, velocityX: float, sprintSpeed: float) -> void:
	if delta >= 0.1:
		return
	
	var speedRatio = velocityX / sprintSpeed
	var targetRotation = speedRatio * deg_to_rad(maxLeanAngle)
	rotation = lerp_angle(rotation, targetRotation, leanSmooth * delta)
	leanOffset=rotation

func handleSquashAndStretch(delta: float, velocity: Vector2, sprintSpeed: float) -> void:
	if delta >= 0.1:
		return
	
	
	var speedFactor = velocity.length() / sprintSpeed
	var baseStretch = speedFactor * maxStretch
	var bounce = 0.0
	var targetBounceOffset = Vector2.ZERO
	
	if speedFactor > 0.1:
		bounceTime += delta * (0.5 + speedFactor * 2.0)
		bounce = sin(bounceTime * TAU) * 0.05 * speedFactor
		targetBounceOffset.y = sin(bounceTime * TAU) * bounceOffsetAmplitude * speedFactor
	
	var targetScale = Vector2(
		(1.0 + baseStretch + bounce*maxConstantStretch) * (2 - otherSquashModifier),
		(1.0 - (baseStretch * 0.5) - bounce*maxConstantStretch) * otherSquashModifier
	) * originSpriteScale
	
	scale = scale.lerp(targetScale, squashSmooth * delta)
	bounceOffset = bounceOffset.lerp(targetBounceOffset, squashSmooth * delta)
	position = originalPosition + bounceOffset

func setFlip(isX: bool, val: bool) -> void:
	if isX:
		material.set_shader_parameter("flip_x", val)
	else:
		material.set_shader_parameter("flip_y", val)

func setHurt(val):
	material.set_shader_parameter("hurt", val)
	
func hurt() -> void:
	hurtCount += 1
	shakeMod = 1
	setHurt(true)
	if not isShaking:
		startShake()
	await get_tree().create_timer(hurt_white_duration).timeout
	hurtCount -= 1
	if hurtCount <= 0:
		hurtCount = 0
		setHurt(false)

func setAnim(animName: String) -> void:
	self.animation = animName

func startShake() -> void:
	isShaking = true
	var elapsed = 0.0
	
	while elapsed < shake_duration:
		var shakeOffset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		position = originalPosition + shakeOffset * shakeMod + bounceOffset
		elapsed += get_process_delta_time()
		await get_tree().process_frame
	
	position = originalPosition + bounceOffset
	isShaking = false

func dead(callback: Callable = Callable(), mode: int = 0) -> void:
	if isDying:
		return
	isDying = true
	
	match mode:
		0:
			await deathMode0()
		_:
			await deathMode0()
	
	if callback.is_valid():
		callback.call()

func intro() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_method(setAlpha, 0.0, 1.0, death_duration)

func setAlpha(val: float) -> void:
	material.set_shader_parameter("alpha", val)
	alpha = val

func deathMode0() -> void:
	var halfDuration = death_duration / 2.0
	
	var tween1 = create_tween()
	tween1.set_parallel(false)
	tween1.tween_property(self, "position:y", originalPosition.y - death_jump_height, halfDuration)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_QUAD)
	tween1.tween_property(self, "position:y", originalPosition.y + 30, halfDuration)\
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
