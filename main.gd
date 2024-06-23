@tool
extends Node3D

@onready var viewport := get_viewport() if not Engine.is_editor_hint() else EditorInterface.get_editor_viewport_3d()
@onready var camera := viewport.get_camera_3d() if not Engine.is_editor_hint() else EditorInterface.get_editor_viewport_3d().get_camera_3d()
@onready var material : ShaderMaterial = $Viewport.get_surface_override_material(0)
@onready var path_tracer := PathTracer.new()
@onready var camera_fov := [camera.fov]
@onready var max_samples := [path_tracer.max_samples]

var previous_camera_transform : Transform3D
var previous_camera_projection : Projection
var camera_matrices_push_constant : PackedByteArray

func _ready() -> void:
	viewport.size_changed.connect(init_render_texture)
	
	init_render_texture()
	resize_window(DisplayServer.screen_get_size(DisplayServer.window_get_current_screen()) * 0.7)

func _process(delta: float) -> void:
	render_imgui()
	render_path_tracer()

func _notification(what):
	if what == NOTIFICATION_PREDELETE: 
		RenderingServer.call_on_render_thread(path_tracer.cleanup_gpu)

func init_render_texture() -> void:
	path_tracer.texture_size = viewport.size
	material.set_shader_parameter('render_texture', path_tracer.render_texture)
	path_tracer.update_objects($Objects.get_children())

func render_imgui() -> void:
	if OS.get_name() != 'Windows' or Engine.is_editor_hint(): return
	
	var pos := camera.global_position
	var fps := Engine.get_frames_per_second()
	ImGui.Begin(' ', [], ImGui.WindowFlags_AlwaysAutoResize | ImGui.WindowFlags_NoMove)
	ImGui.SetWindowPos(Vector2(20, 20))
	
	ImGui.SeparatorText('Path Tracing')
	ImGui.Text('FPS:             %d (%s)' % [fps, 'paused' if path_tracer.frame == path_tracer.max_samples else '%.2fms' % [1e3 / fps]])
	ImGui.Text('#Shapes:         %d' % [path_tracer.num_objects])
	ImGui.Text('#Samples:        %d (%.2f%%)' % [path_tracer.frame, path_tracer.frame / float(path_tracer.max_samples) * 1e2])
	ImGui.Text('#Max Samples:   '); ImGui.SameLine(); if ImGui.InputInt('##MaxSamples', max_samples): max_samples[0] = maxi(1, max_samples[0]); path_tracer.max_samples = max_samples[0]
	ImGui.SeparatorText('Camera')
	ImGui.Text('Camera Position: %+.2v' % [pos])
	ImGui.Text('Camera FOV:     '); ImGui.SameLine(); if ImGui.SliderFloat('##FOV', camera_fov, 20, 170): camera.fov = camera_fov[0]
	ImGui.End()

func render_path_tracer() -> void:
	# Reset accumulated image whenever camera attributes are changed.
	var current_transform := camera.get_camera_transform()
	var current_projection := camera.get_camera_projection()
	if path_tracer.context and (previous_camera_transform != current_transform or previous_camera_projection != current_projection) or not camera_matrices_push_constant: 
		camera_matrices_push_constant = RenderingContext.create_push_constant(FreeLookCamera.get_inverse_viewproj_matrices(camera))
		path_tracer.frame = 0
	previous_camera_transform = current_transform
	previous_camera_projection = current_projection
	
	material.set_shader_parameter('frame', path_tracer.frame)
	RenderingServer.call_on_render_thread(path_tracer.render.bind(camera_matrices_push_constant, $Sun.global_basis.z))

func resize_window(size : Vector2i) -> void:
	var old_size := DisplayServer.window_get_size()
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(DisplayServer.window_get_position() + (size - old_size).abs() / 2)

func _on_objects_child_entered_tree(node: Node) -> void:
	if not node is ShapePathTraced:
		printerr('ERROR: A non-path traced object was added to object node!')
		node.queue_free()
		return
	(node as ShapePathTraced).changed.connect(func(): 
		if path_tracer: path_tracer.update_objects($Objects.get_children()))
