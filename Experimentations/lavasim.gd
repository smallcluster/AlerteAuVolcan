@tool

extends MeshInstance3D

@export var step := false : set = do_step
@export var reset := false : set = do_reset
@export var heightmap : Texture2D = null : set = update_heightmap

@export var points : Array[Vector2i] = [] : set = update_points

@export var lava_flow := 10.0
@export var height_penality := 10

@export var play : bool = false
@export var wait : float = 2.0

var heightmap_data : Array[float]
var lava_data : Array[float]

var timer : Timer
var playing := false


var lava_tex : ImageTexture

# Called when the node enters the scene tree for the first time.
func _ready():
	timer = Timer.new()
	timer.wait_time = wait
	add_child(timer)
	do_reset()
	
func simulate():
	playing = true
	print("playing")
	timer.wait_time = wait
	do_step()
	timer.start()
	await timer.timeout
	playing = false
	
func _process(delta):
	if play and not playing:
		simulate()
		
	
func update_points(value : Array[Vector2i]):
	points = value
	
	for p in points :
		p.x = clamp(p.x, 0, 32 if heightmap == null else heightmap.get_width())
		p.y = clamp(p.x, 0, 32 if heightmap == null else heightmap.get_height())

	do_reset()


func img_from_data(data : Array[float], w, h) -> Image:
	var img = Image.create(w, h, false, Image.FORMAT_RGB8)
	for i in range(h):
		for j in range(w):
			img.set_pixel(j, i, Color.from_hsv(0.0, 0.0, clamp(data[i*w+j], 0.0, 1.0) ))
	return img

func data_from_img(img : Image) -> Array[float]:
	var w := img.get_width()
	var h := img.get_height()
	
	var data : Array[float]
	data.resize(w*h)
	
	for i in range(h):
		for j in range(w):
			data[i*w+j] = img.get_pixel(j, i).v
	
	return data
	
	
func update_heightmap(texture : Texture2D):
	heightmap = texture
	
	if heightmap != null:
		var img := heightmap.get_image()
		var w := texture.get_width()
		var h := texture.get_height()
		heightmap_data = data_from_img(img)
		lava_data.resize(w*h)
	
	do_reset()
	

func update_material():
	get_surface_override_material(0).set_shader_parameter("lava_map", lava_tex)
	#mesh.surface_get_material(0).set_shader_parameter("lava_map", lava_tex)
	
func show_error_tex():
	var tmp_image = Image.create(32, 32, false, Image.FORMAT_RGB8)
	for i in range(32):
		for j in range(32):
			tmp_image.set_pixel(j,i, Color.BLACK if (i+j) % 2 == 0 else Color.MAGENTA)
	lava_tex = ImageTexture.create_from_image(tmp_image)
	update_material()
	
	

func do_reset(value : bool = true):
	# No texture => error texture
	if heightmap == null:
		printerr("No heightmap defined.")
		show_error_tex()
	else:
		var w := heightmap.get_width()
		var h := heightmap.get_height()
		
		lava_data.fill(0.0)
		
		for p in points:
			lava_data[p.y * w + p.x] = lava_flow
		
		var img := img_from_data(lava_data, w, h)
		lava_tex = ImageTexture.create_from_image(img)
		update_material()
		
func softmax(values : Array) -> Array :
	var d := 0.0
	for v in values:
		d += exp(v)
	return values.map(func (x): return exp(x) / d)
		

func update_neighboors(index : int, w : int, h : int, old_data, data):
	
	var amount : float = old_data[index]
	
	# find neighboors
	var neighboors : Array[int] = []
	var i := index / w
	var j := index % w
	
	if i > 0:
		neighboors.append((i-1)*w+j)
	if i < h-1:
		neighboors.append((i+1)*w+j)
	if j > 0:
		neighboors.append(i*w+j-1)
	if j < w-1:
		neighboors.append(i*w+j+1)
	
	# Apply score for neighboors
	var scores : Array[float] = []
	
	for n_index in neighboors:
		var diff := heightmap_data[index] - heightmap_data[n_index] 
		if diff < 0:
			diff *= height_penality
		scores.append(diff)

	# Get lava distribution
	var distribution := softmax(scores)
	
	# Propagate lava
	for d in range(len(distribution)):
		var n_index = neighboors[d]
		data[n_index] += amount * distribution[d]
	

func do_step(value : bool = true):
	
	if heightmap == null:
		printerr("No heightmap defined.")
		show_error_tex()
		return
		
	# Get texture infos
	var w := heightmap.get_width()
	var h := heightmap.get_height()
	
	
	# create new data
	var new_data : Array[float]
	new_data.resize(len(lava_data))
	new_data.fill(0.0)
	
	# cellular automata
	for index in range(len(lava_data)):
		update_neighboors(index, w, h, lava_data, new_data)
	
	# force lava creation 
	for p in points:
		new_data[p.y * w + p.x] = lava_flow
	
	# update data
	lava_data = new_data

	# update texture
	var img := img_from_data(lava_data, w, h)
	lava_tex = ImageTexture.create_from_image(img)
	update_material()
	
	
