@tool
extends SubViewport

@export var material : ShaderMaterial
@export var normal_scale : float = 3.0 :
	set(x):
		normal_scale = x
		_build_normal_map()
@export var normal_blur : int = 2 :
	set(x):
		normal_blur = x
		_build_normal_map()
@export var reset : bool = false : set = do_reset
@export var step : bool = false : set = do_step
@export var heightmap : Texture2D = null : set = set_heightmap
@export var lavamap : Texture2D = null : set = set_lavamap
@export var lava_flow := 1.7 : 
	set(x):
		lava_flow = x
		_sim.lava_flow = x
@export var height_penality := 400 :
	set(x):
		height_penality = x
		_sim.height_penality = x
@export var simulate : bool = false :
	set(x):
		simulate = x
		if simulate:
			if _timer == null: await ready
			_timer.start()
@export var wait_time : float = 2.0 :
	set(x):
		wait_time = x
		if _timer == null: await ready
		_timer.wait_time = x


var _sim : LavaSim = null
var _normal_map : ImageTexture
@onready var _timer := $UpdateTimer
@onready var _texture_rect := $LavaMaskRect

func _ready():
	_timer.wait_time = wait_time
	_change_sim_textures()

# setters
func do_reset(value : bool = false) -> void:
	if _sim != null:
		_sim.reset()
		update_texture()
	
func do_step(value : bool = false) -> void:
	if _sim != null:
		_sim.step()
		update_texture()
	
func set_heightmap(texture : Texture2D) -> void:
	heightmap = texture
	_change_sim_textures()

func set_lavamap(texture : Texture2D) -> void:
	lavamap = texture
	_change_sim_textures()
	
func _build_normal_map() -> void:
	if heightmap != null:
		var normals = HeightmapHelper.normals_from_height(HeightmapHelper.height_from_image(heightmap.get_image()), normal_scale)
		var img =  HeightmapHelper.image_from_normals(HeightmapHelper.blur_normals(normals, normal_blur))
		_normal_map = ImageTexture.create_from_image(img)
		material.set_shader_parameter("normal_map", _normal_map) # update shader uniform
	
func _change_sim_textures() -> void:
	if heightmap != null and lavamap != null:
		_sim = LavaSim.new().create_from_textures(heightmap, lavamap)
		_sim.lava_flow = lava_flow
		_sim.height_penality = height_penality
		do_reset()
		_build_normal_map()
	
func img_from_data(data : Array[float]) -> Image:
	var size := int(sqrt(len(data)))
	var img = Image.create(size, size, false, Image.FORMAT_RGBAF)
	for i in range(size):
		for j in range(size):
			img.set_pixel(j, i, Color.from_hsv(0.0, 0.0, clamp(data[i*size+j], 0.0, 1.0) ))
	return img
	
	
func update_texture() -> void:
	var lava_tex := _sim.get_texture()
	if _timer == null: await ready
	material.set_shader_parameter("lava_map", lava_tex)
	_texture_rect.material.set("shader_parameter/lava_map", lava_tex)

func _on_update_timer_timeout():
	do_step()
	# Restart
	if simulate:
		_timer.start()
		
	
