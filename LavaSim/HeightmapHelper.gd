class_name HeightmapHelper

# Heights
static func height_from_image(heightmap : Image) -> Array[float]:
	var size := heightmap.get_width()
	var data : Array[float]
	data.resize(size*size)
	
	for i in range(size):
		for j in range(size):
			data[i*size+j] = heightmap.get_pixel(j, i).v;
	
	return data
	
# Normals
static func normals_from_height(heights : Array[float], normal_scale : float) -> Array[Vector3]:
	var size := int(sqrt(len(heights)))
	var data : Array[Vector3]
	data.resize(size*size)
	for i in range(len(data)):
		data[i] = _calc_normal_vector(i, size, heights, normal_scale)
	return data	

static func blur_normals(normals : Array[Vector3], steps : int) -> Array[Vector3]:
	var size := int(sqrt(len(normals)))
	var data : Array[Vector3]
	data.resize(size*size)
	data.assign(normals)
	
	for k in range(steps):
		var tmp : Array[Vector3]
		tmp.assign(data)
		for i in range(len(data)):
			tmp[i] = _blur_vector(i, size, data)
		data = tmp
			
	return data	
	
# Images
static func image_from_heights(heights : Array[float]) -> Image:
	var size := int(sqrt(len(heights)))
	var img = Image.create(size, size, false, Image.FORMAT_RGBAF)
	for i in range(size):
		for j in range(size):
			var v := heights[i*size+j]
			img.set_pixel(j, i, Color(v,v,v))
	return img

static func image_from_normals(normals : Array[Vector3]) -> Image:
	var size := int(sqrt(len(normals)))
	var img = Image.create(size, size, false, Image.FORMAT_RGBAF)
	for i in range(size):
		for j in range(size):
			var v = Vector3(0.5, 0.5, 0.5) + 0.5 * normals[i*size+j]
			img.set_pixel(j, i, Color(v.x, v.y, v.z))
	return img
	

# Private func
static func _blur_vector(index : int, size : int, normals : Array[Vector3]) -> Vector3:
	# find neighboors
	var vectors : Array[Vector3] = []
	var i := index / size
	var j := index % size
	if i > 0:
		vectors.append(normals[(i-1)*size+j])
	if i < size-1:
		vectors.append(normals[(i+1)*size+j])
	if j > 0:
		vectors.append(normals[i*size+j-1])
	if j < size-1:
		vectors.append(normals[i*size+j+1])
	var dir := Vector3(0.0, 0.0, 0.0)
	for v in vectors:
		dir += v
	return dir / len(vectors)
	
	
static func _sample_height(i : int, j : int, size : int, heights : Array[float]) -> float :
	if i < 0 or j < 0 or i >= size or j >= size:
		return 0.0
	return heights[i*size+j]
	
	
static func _calc_normal_vector(index : int, size : int, heights : Array[float], normal_scale : float) -> Vector3:
	var i := index / size
	var j := index % size

	# sobel filter
	var s0 := _sample_height(i-1,j-1,size, heights) # top left
	var s1 := _sample_height(i-1,j+1,size, heights) # top right
	var s2 := _sample_height(i+1,j-1,size, heights) # bottom left
	var s3 := _sample_height(i+1,j+1,size, heights) # bottom right
	var s4 := _sample_height(i-1,j,size, heights) # top
	var s5 := _sample_height(i+1,j,size, heights) # bottom
	var s6 := _sample_height(i,j-1,size, heights) # left
	var s7 := _sample_height(i,j+1,size, heights) # right
	
	var n := Vector3( 2.0*s7+s1+s3 - 2.0*s6-s0-s2, -2.0*s4-s0-s1 + 2.0*s5+s2+s3, normal_scale)

	return n.normalized()	
	
