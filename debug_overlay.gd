extends Label
## Playtest readout (bottom centre): FPS, frame time and the GPU's name.
## Shown in debug builds only (editor runs and debug exports, including one-click deploy to a phone);
## hidden in release exports. F3 toggles it on desktop.

const REFRESH := 0.25   # seconds between updates, so the numbers stay readable

var _gpu := ""
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = OS.is_debug_build()
	_gpu = RenderingServer.get_video_adapter_name()
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	if _t >= REFRESH:
		_t = 0.0
		_refresh()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F3:
		visible = not visible


func _refresh() -> void:
	var fps := Engine.get_frames_per_second()
	text = "FPS %d (%.1f ms)  |  GPU: %s" % [int(fps), 1000.0 / maxf(fps, 1.0), _gpu]
