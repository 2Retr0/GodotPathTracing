@tool
class_name PathTracer extends Resource

var context : RenderingContext
var pipelines : Dictionary
var descriptors : Dictionary
var descriptor_sets : Dictionary

var render_texture := Texture2DRD.new()
var texture_size : Vector2i :
	set(value):
		texture_size = value
		if not context: return 
		
		cleanup_gpu()
		init_gpu()
var frame := 0 :
	set(value):
		frame = value
		if frame != 0 or not context: return
		context.device.texture_clear(descriptors['render_texture'].rid, Color.BLACK, 0, 1, 0, 1)
var max_samples := int(100e3) :
	set(value):
		max_samples = value
		frame = 0
var num_objects := 0
var tris_offset := 0

func init_gpu() -> void:
	# --- DEVICE/SHADER CREATION ---
	# We have to use `RenderingServer.get_rendering_device()` as Texture2DRD can only be used
	# on the main rendering device.
	if not context: context = RenderingContext.create(RenderingServer.get_rendering_device())
	var projection_shader := context.load_shader('res://resources/shaders/compute/path_trace.glsl')
	
	# --- DESCRIPTOR PREPARATION ---
	descriptors['uniforms'] = context.create_uniform_buffer(8*4)
	descriptors['shapes'] = context.create_uniform_buffer(100*12*4)
	descriptors['materials'] = context.create_uniform_buffer(100*16*4)
	descriptors['render_texture'] = context.create_texture(texture_size, RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT)
	
	var projection_set := context.create_descriptor_set([descriptors['uniforms'], descriptors['shapes'], descriptors['materials'], descriptors['render_texture']], projection_shader, 0)
	render_texture.texture_rd_rid = descriptors['render_texture'].rid
	
	# --- COMPUTE PIPELINE CREATION ---
	pipelines['path_trace'] = context.create_pipeline([ceili(texture_size.x/16.0), ceili(texture_size.y/16.0), 1], [projection_set], projection_shader)
	#pipelines['radix_sort_histogram'] = context.create_pipeline([], [], radix_sort_histogram_shader)
	#pipelines['radix_sort'] = context.create_pipeline([], [], radix_sort_shader)
	frame = 0
	
func cleanup_gpu():
	render_texture.texture_rd_rid = RID()
	if context: context.free()

func update_objects(shapes : Array) -> void:
	if not context: init_gpu()
	
	var spheres_buffer := PackedByteArray()
	var spheres_material_buffer := PackedByteArray()
	var tris_buffer := PackedByteArray()
	var tris_material_buffer := PackedByteArray()
	num_objects = 0
	for shape in shapes:
		if not shape.visible: continue 
		if shape is SpherePathTraced:
			spheres_buffer += shape.to_byte_array()
			spheres_material_buffer += shape.material.to_byte_array()
		elif shape is TriPathTraced:
			tris_buffer += shape.to_byte_array()
			tris_material_buffer += shape.material.to_byte_array()
		else:
			assert(false, 'Encountered unknown shape!')
		num_objects += 1
	context.device.buffer_update(descriptors['shapes'].rid, 0, len(spheres_buffer) + len(tris_buffer), spheres_buffer + tris_buffer)
	context.device.buffer_update(descriptors['materials'].rid, 0, len(spheres_material_buffer) + len(tris_material_buffer), spheres_material_buffer + tris_material_buffer)
	tris_offset = roundi(float(num_objects) * (len(spheres_buffer) / float(len(spheres_buffer) + len(tris_buffer))))
	#print(context.device.buffer_get_data(descriptors['materials'].rid, 0, len(spheres_material_buffer) + len(tris_material_buffer)).to_float32_array())
	frame = 0

func render(camera_matrices_push_constant : PackedByteArray, light_direction : Vector3) -> void:
	if not context: init_gpu()
	if frame >= max_samples : return
	
	context.device.buffer_update(descriptors['uniforms'].rid, 0, 8*4, RenderingContext.create_push_constant([
		light_direction.x, 
		light_direction.y, 
		light_direction.z, 
		frame, 
		Time.get_ticks_msec()*1e-3,
		num_objects,
		tris_offset]))
	frame += 1
	
	var compute_list := context.compute_list_begin()
	pipelines['path_trace'].call(context, compute_list, camera_matrices_push_constant)
	context.compute_list_end()
	
	#for shift in range(0, 32, 8):
		#var descriptor_set = [descriptor_sets['radix_sort%d' % ((shift / 8) % 2)]]
		#pipelines['radix_sort_histogram'].call(context, compute_list, [shift], descriptor_set, radix_sort_dims)
		#pipelines['radix_sort'].call(context, compute_list, [shift], descriptor_set, radix_sort_dims)
	#pipelines['boundaries'].call(context, compute_list, [], [], boundaries_dims)
	#pipelines['rasterize'].call(context, compute_list)
