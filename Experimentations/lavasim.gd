@tool

extends MeshInstance3D

@export var step := false : set = do_step
@export var reset := false : set = do_reset
@export var heightmap : Texture2D = null : set = update_heightmap

@export var lava_points : Texture2D = null : set = update_points

var points : Array[Vector2i] = []

@export var lava_flow := 10.0
@export var height_penality := 10
@export var blur_steps : int = 8 : set = update_blur
@export var normal_scale : float = 1.0 : set = update_normal

@export var play : bool = false
@export var wait : float = 2.0

var heightmap_data : Array[float]
var lava_data : Array[float]


var timer : Timer
var playing := false


var lava_tex : ImageTexture
var normal_tex : ImageTexture

func update_flow_map():
	if heightmap == null:
		printerr("No heightmap defined.")
		show_error_tex()
	else:
		normal_tex = build_normal_map(heightmap_data)
		
		
func update_normal(value : float):
	normal_scale = value
	update_flow_map()
	update_material()

func update_blur(value : int):
	blur_steps = value
	update_flow_map()
	update_material()

func sample_height(i : int, j : int, w : int, h : int, data : Array[float]) -> float :
	if i < 0 or j < 0 or i >= h or j >= w:
		return 0.0
	return data[i*w+j]

func blur_vector(index : int, w : int, h : int, data : Array[Vector3]) -> Vector3:
	# find neighboors
	var vectors : Array[Vector3] = []
	var i := index / w
	var j := index % w
	if i > 0:
		vectors.append(data[(i-1)*w+j])
	if i < h-1:
		vectors.append(data[(i+1)*w+j])
	if j > 0:
		vectors.append(data[i*w+j-1])
	if j < w-1:
		vectors.append(data[i*w+j+1])
	var dir := Vector3(0.0, 0.0, 0.0)
	for v in vectors:
		dir += v
	return dir / len(vectors)

func calc_normal_vector(index : int, w : int, h : int, data : Array[float]) -> Vector3:
	# find neighboors
	var neighboors : Array[int] = []
	var i := index / w
	var j := index % w

	# sobel filter
	var s0 := sample_height(i-1,j-1,w,h, data) # top left
	var s1 := sample_height(i-1,j+1,w,h, data) # top right
	var s2 := sample_height(i+1,j-1,w,h, data) # bottom left
	var s3 := sample_height(i+1,j+1,w,h, data) # bottom right
	var s4 := sample_height(i-1,j,w,h, data) # top
	var s5 := sample_height(i+1,j,w,h, data) # bottom
	var s6 := sample_height(i,j-1,w,h, data) # left
	var s7 := sample_height(i,j+1,w,h, data) # right
	
	var n := Vector3( 2.0*s7+s1+s3 - 2.0*s6-s0-s2, -2.0*s4-s0-s1 + 2.0*s5+s2+s3, normal_scale)

	return n.normalized()
	

func build_normal_map(data : Array[float]) -> ImageTexture:
	
	var w := heightmap.get_width()
	var h := heightmap.get_height()
	
	# Generate vector data
	var vectors : Array[Vector3]
	vectors.resize(len(data))
	
	for i in range(len(data)):
		vectors[i] = calc_normal_vector(i, w, h, data)
	
	var vectors_blured : Array[Vector3]
	vectors_blured.resize(len(vectors))
	
	for k in range(blur_steps):
		for i in range(len(vectors)):
			vectors_blured[i] = blur_vector(i, w, h, vectors)
		vectors = vectors_blured
	
	
	# Generate image
	var img := Image.create(w, h, false, Image.FORMAT_RGBAF)
	for i in range(h):
		for j in range(w):
			var v = Vector3(0.5, 0.5, 0.5) + 0.5 * vectors[i*w+j]
			img.set_pixel(j, i, Color(v.x, v.y, v.z, 1.0))
	
	return ImageTexture.create_from_image(img)
	
	

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
		
	
func update_points(texture : Texture2D):
	
	lava_points = texture
	
	if lava_points == null:
		points = []
	else:
		var img := texture.get_image()
		for x in range(texture.get_width()):
			for y in range(texture.get_height()):
				if img.get_pixel(x, y).r > 0:
					points.append(Vector2i(x,y))

	do_reset()


func img_from_data(data : Array[float], w, h) -> Image:
	var img = Image.create(w, h, false, Image.FORMAT_RGBAF)
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
	get_surface_override_material(0).set_shader_parameter("normal_map", normal_tex)
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
		update_flow_map()
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
	
	
