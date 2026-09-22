extends SceneTree

const Factory = preload("res://materials/legacy_materials.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("material-render requires a rendering display")
		quit(2)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.add_child(environment)
	var camera := Camera3D.new()
	camera.position.z = 2
	world.add_child(camera)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-2,-2,0), Vector3(0,2,0), Vector3(2,-2,0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color(0.25,0.25,0.25,1), Color(0.25,0.25,0.25,1), Color(0.25,0.25,0.25,1)])
	arrays[Mesh.ARRAY_CUSTOM0] = PackedFloat32Array([0.75,0.75,0.75,1, 0.75,0.75,0.75,1, 0.75,0.75,0.75,1])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	world.add_child(instance)
	var image := Image.create(1,1,false,Image.FORMAT_RGBA8)
	image.fill(Color(128.0/255,128.0/255,128.0/255,1))
	var material := Factory.make_surface({"texture": ImageTexture.create_from_image(image), "color": Color(0.8,0.8,0.8,1), "ambient": 0.5, "diffuse": 1.0, "alpha_mode": "opaque", "family": "world", "filter": 0x1101})
	instance.material_override = material
	for night in [0.0, 1.0]:
		material.set_shader_parameter("vertex_only", true)
		material.set_shader_parameter("night_blend", night)
		for frame in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		var channel := viewport.get_texture().get_image().get_pixel(32,32)
		if absf(channel.r - lerpf(0.25, 0.75, night)) > 3.0/255:
			printerr("material-render-fail day/night channel ", channel)
			quit(1)
			return
	var env := {"ambient": Color(0.1,0.1,0.1,1), "ambient_objects": Color.BLACK, "directional": Color.BLACK, "sky_top": Color.BLACK, "sky_bottom": Color.BLACK, "fog_start": 0.0, "far_clip": 1000.0, "night_blend": 0.5, "hour": 12.0, "weather": "SYNTHETIC"}
	Factory.set_environment([material], env, {"textures": true, "prelight": true, "fog": false, "post": false, "vertex_only": false})
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var pixel := viewport.get_texture().get_image().get_pixel(32,32)
	var expected := (0.5 + 0.1 * 0.5) * 0.8 * (128.0 / 255.0)
	print("material-render-grey actual=", pixel, " expected=", expected, " renderer=", RenderingServer.get_current_rendering_method())
	if absf(pixel.r-expected) > 3.0/255 or absf(pixel.g-expected) > 3.0/255 or absf(pixel.b-expected) > 3.0/255:
		printerr("material-render-fail source RGB propagation")
		quit(1)
		return
	# Boundary alpha checks use a black framebuffer, not source-code matching.
	for alpha_case in [["cutout", 0.5, false], ["cutout", 0.51, true], ["blend", 0.0, false], ["blend", 1.0, true]]:
		var alpha_material := Factory.make_surface({"texture": ImageTexture.create_from_image(image), "color": Color(0.8,0.8,0.8,float(alpha_case[1])), "ambient": 0.5, "diffuse": 1.0, "alpha_mode": alpha_case[0], "family": "world", "filter": 0x1101})
		Factory.set_environment([alpha_material], env, {"textures": true, "prelight": true, "fog": false, "post": false, "vertex_only": false})
		instance.material_override = alpha_material
		for frame in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		var alpha_pixel := viewport.get_texture().get_image().get_pixel(32,32)
		var alpha_expected := expected if bool(alpha_case[2]) else 0.0
		if absf(alpha_pixel.r - alpha_expected) > 3.0/255:
			printerr("material-render-fail alpha boundary ", alpha_case, " pixel=", alpha_pixel)
			quit(1)
			return
	# Standard RW MatFX ENVMAP: camera-normal UV, source coefficient and
	# premultiplied ONE/inverse-alpha composition over black.
	var black_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	black_image.fill(Color(0, 0, 0, 1))
	var env_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	env_image.fill(Color(102.0 / 255.0, 0, 0, 1))
	var env_material := Factory.make_surface({"texture": ImageTexture.create_from_image(black_image),
		"color": Color.WHITE, "ambient": 0.5, "diffuse": 1.0, "alpha_mode": "opaque",
		"family": "vehicle", "filter": 0x1102, "matfx_type": 2,
		"env_texture": ImageTexture.create_from_image(env_image), "env_coefficient": 0.5,
		"env_framebuffer_alpha": false})
	Factory.set_environment([env_material], env, {"textures": true, "prelight": true, "fog": false, "post": false, "vertex_only": false})
	instance.material_override = env_material
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var env_pixel := viewport.get_texture().get_image().get_pixel(32,32)
	if absf(env_pixel.r - 0.2) > 4.0 / 255.0 or env_pixel.g > 2.0 / 255.0 or env_pixel.b > 2.0 / 255.0:
		printerr("material-render-fail MatFX env ", env_pixel)
		quit(1)
		return
	# Explicit source mip chain: high UV derivatives select authored lower levels.
	# Trilinear mode may blend green level1 with blue level2; point/no-mip stays red.
	var mip_bytes := PackedByteArray()
	for i in 16:
		mip_bytes.append_array(PackedByteArray([255, 0, 0, 255]))
	for i in 4:
		mip_bytes.append_array(PackedByteArray([0, 255, 0, 255]))
	mip_bytes.append_array(PackedByteArray([0, 0, 255, 255]))
	var mip_image := Image.create_from_data(4, 4, true, Image.FORMAT_RGBA8, mip_bytes)
	var mip_texture := ImageTexture.create_from_image(mip_image)
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2(64, 0), Vector2(0, 64)])
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	var mip_info := {"texture": mip_texture, "color": Color.WHITE, "ambient": 0.5, "diffuse": 1.0,
		"alpha_mode": "opaque", "family": "world", "filter": 0x1106}
	var mip_material := Factory.make_surface(mip_info)
	Factory.set_environment([mip_material], env, {"textures": true, "prelight": true, "fog": false, "post": false, "vertex_only": false})
	instance.material_override = mip_material
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var mip_pixel := viewport.get_texture().get_image().get_pixel(32,32)
	mip_info.filter = 0x1101
	var base_material := Factory.make_surface(mip_info)
	Factory.set_environment([base_material], env, {"textures": true, "prelight": true, "fog": false, "post": false, "vertex_only": false})
	instance.material_override = base_material
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var base_pixel := viewport.get_texture().get_image().get_pixel(32,32)
	if maxf(mip_pixel.g, mip_pixel.b) <= mip_pixel.r * 3.0 or \
		base_pixel.r <= maxf(base_pixel.g, base_pixel.b) * 3.0:
		printerr("material-render-fail mip selection mip=", mip_pixel, " base=", base_pixel)
		quit(1)
		return
	instance.visible = false
	var sky_material := Factory.make_sky()
	env.sky_top = Color(0.3, 0.3, 0.3, 1)
	env.sky_bottom = env.sky_top
	Factory.set_environment([sky_material], env, {"textures": true, "prelight": true, "fog": false, "post": false, "vertex_only": false})
	environment.environment.background_mode = Environment.BG_SKY
	environment.environment.sky = Sky.new()
	environment.environment.sky.sky_material = sky_material
	for frame in range(6):
		await process_frame
		await RenderingServer.frame_post_draw
	var sky_pixel := viewport.get_texture().get_image().get_pixel(32,32)
	if absf(sky_pixel.r - 0.3) > 3.0/255:
		printerr("material-render-fail sky RGB ", sky_pixel)
		quit(1)
		return
	var post := ColorRect.new()
	post.size = Vector2(64,64)
	post.material = ShaderMaterial.new()
	post.material.shader = preload("res://materials/legacy_post.gdshader")
	post.material.set_shader_parameter("pass1", Vector4(0.2,0.2,0.2,0.5))
	post.material.set_shader_parameter("pass2", Vector4(0.4,0.4,0.4,0.25))
	viewport.add_child(post)
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var post_pixel := viewport.get_texture().get_image().get_pixel(32,32)
	if absf(post_pixel.r - 0.36) > 4.0/255:
		printerr("material-render-fail PC filter ", post_pixel)
		quit(1)
		return
	print("material-render-ok sky=", sky_pixel, " post=", post_pixel, " env=", env_pixel,
		" mip=", mip_pixel, " base=", base_pixel)
	viewport.free()
	quit(0)
