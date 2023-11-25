class_name LavaSim

# Public Simulation params
var lava_flow := 10.0
var height_penality := 10



# Private Simulation state
var _source_points : Array[Vector2i]
var _heightmap_data : Array[float]
var _lava_data : Array[float]
var _map_size : int

# Constructors
func create_from_data(heightmap : Array[float], source_points : Array[Vector2i]) -> LavaSim:
	_source_points = source_points
	_heightmap_data = heightmap
	_map_size = int(sqrt(len(heightmap)))
	_lava_data.resize(_map_size*_map_size)
	reset()
	return self
	
	
func create_from_images(heightmap : Image, lavamap : Image) -> LavaSim:
	_map_size = heightmap.get_width()
	_heightmap_data = HeightmapHelper.height_from_image(heightmap)
	_lava_data.resize(_map_size*_map_size)
	
	for i in range(_map_size):
		for j in range(_map_size):
			if lavamap.get_pixel(j, i).r > 0:
				_source_points.append(Vector2i(i,j))
				
	reset()
	return self

func create_from_textures(heightmap : Texture2D, lavamap : Texture2D) -> LavaSim:
	return create_from_images(heightmap.get_image(), lavamap.get_image())
	
# Texture

func get_texture() -> ImageTexture:
	var clamped_map : Array[float]
	clamped_map.assign(_lava_data.map(func (x): return clampf(x, 0.0, 1.0)))
	var img := HeightmapHelper.image_from_heights(clamped_map)
	return ImageTexture.create_from_image(img)

# Simulation progress

func reset() -> void:
	_lava_data.fill(0.0)
	for v in _source_points:
		_lava_data[v.x * _map_size + v.y] = lava_flow
	

func _softmax(values : Array[float]) -> Array[float] :
	var d := 0.0
	for v in values:
		d += exp(v)
	var r : Array[float]
	r.assign(values.map(func (x): return exp(x) / d))
	return r

func _update_neighboors(index : int, old_data : Array[float], data : Array[float]):
	var amount := old_data[index]
	# find neighboors
	var neighboors : Array[int] = []
	var i := index / _map_size
	var j := index % _map_size
	if i > 0:
		neighboors.append((i-1)*_map_size+j)
	if i < _map_size-1:
		neighboors.append((i+1)*_map_size+j)
	if j > 0:
		neighboors.append(i*_map_size+j-1)
	if j < _map_size-1:
		neighboors.append(i*_map_size+j+1)
	
	# Apply score for neighboors
	var scores : Array[float] = []
	for n_index in neighboors:
		var diff := _heightmap_data[index] - _heightmap_data[n_index] 
		if diff < 0:
			diff *= height_penality
		scores.append(diff)
	# Get lava distribution
	var distribution := _softmax(scores)
	# Propagate lava
	for k in range(len(distribution)):
		var n_index = neighboors[k]
		data[n_index] += amount * distribution[k]

func step() -> void:
	# create new data
	var new_data : Array[float]
	new_data.resize(_map_size*_map_size)
	new_data.fill(0.0)
	
	# cellular automata
	for index in range(len(_lava_data)):
		_update_neighboors(index, _lava_data, new_data)
	
	# force lava creation 
	for p in _source_points:
		new_data[p.x * _map_size + p.y] = lava_flow
	
	# update data
	_lava_data = new_data
