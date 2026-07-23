extends Node

signal load_progress(percent: float)
signal load_done()

var _path: String = ""
var _callback: Callable

func load_scene(path: String, callback: Callable = Callable()) -> void:
	if not _path.is_empty():
		return
	_path = path
	_callback = callback
	ResourceLoader.load_threaded_request(path)

func _process(_delta: float) -> void:
	if _path.is_empty():
		return
	var progress: Array = []
	var status = ResourceLoader.load_threaded_get_status(_path, progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			load_progress.emit(progress[0])
		ResourceLoader.THREAD_LOAD_LOADED:
			var scene = ResourceLoader.load_threaded_get(_path)
			_path = ""
			get_tree().change_scene_to_packed(scene)
			load_progress.emit(1.0)
			load_done.emit()
			if _callback:
				_callback.call_deferred()
		ResourceLoader.THREAD_LOAD_FAILED:
			_path = ""
			push_error("Failed to load scene: ", _path)
