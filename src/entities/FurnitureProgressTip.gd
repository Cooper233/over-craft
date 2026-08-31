extends Node2D
class_name FurnitureProgressTip

var nowProgress:float=0
var displayProgress:float=0.0
var bar:AdvProgressBar
var isHidden:bool=true

func _ready() -> void:
	await get_tree().process_frame
	bar=LevelControllerBase.INSTANCE.mapStaticUI.spawnProgressBar(self.global_position)
	bar.hide()
	#setShow()
func _process(delta: float) -> void:
	if not isHidden:
		displayProgress+=lerpf(0,1.0*nowProgress-displayProgress,30.0)*delta
		bar.setProgress(displayProgress)
func syncProgress(progress:float):
	nowProgress=progress
func setShow()->void:
	if not isHidden:return
	bar.intro()
	isHidden=false
func setHide(isDone:bool)->void:
	if isHidden:return
	isHidden=true
	if isDone:
		bar.outroDone()
	else:
		bar.outro()	
