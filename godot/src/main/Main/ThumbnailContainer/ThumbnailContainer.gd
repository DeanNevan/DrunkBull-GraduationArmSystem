extends MarginContainer

@onready var _ThumbnailColor = %ThumbnailColor
@onready var _ThumbnailSimDepth = %ThumbnailSimDepth
@onready var _ThumbnailSynDepth = %ThumbnailSynDepth
@onready var _ButtonShow = %ButtonShow
@onready var _ThumbnailContainer = %ThumbnailContainer

var texture_color : Texture
var texture_sim_depth : Texture
var texture_syn_depth : Texture

var is_show := false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func update_all():
	_ThumbnailColor.texture = texture_color
	_ThumbnailSimDepth.texture = texture_sim_depth
	_ThumbnailSynDepth.texture = texture_syn_depth
	if is_show:
		_ThumbnailContainer.show()
		_ButtonShow.icon = preload("res://assets/art/icon/universal/backward.png")
	else:
		_ThumbnailContainer.hide()
		_ButtonShow.icon = preload("res://assets/art/icon/universal/forward.png")
		
	pass

func _on_button_show_pressed():
	is_show = !is_show
	update_all()
	pass # Replace with function body.
