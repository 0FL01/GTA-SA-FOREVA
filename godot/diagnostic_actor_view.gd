extends Node3D

# Presentation only: source-owned CPU skin/car pose from the native diagnostic
# controller. No Godot physics or simulation feedback. Studio floor is synthetic.
# Deliberately unlit diagnostic material, NOT original lighting/vehicle pipeline.
const ACTOR_SHADER = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D source_texture : source_color, repeat_enable;
uniform bool textured = false;
void fragment() {
    vec4 c = COLOR;
    if (textured) { c *= texture(source_texture, UV); }
    ALBEDO = c.rgb;
    ALPHA = c.a;
    ALPHA_SCISSOR_THRESHOLD = 0.02;
}
"""

var _topology: Array = []
var _groups: Array = []
var _nodes: Array[MeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
var _epoch: int = 0


func configure(packet: Dictionary) -> void:
    assert(packet.ok and packet.diagnostic_approximation and packet.synthetic_floor and not packet.source_gameplay)
    assert(_nodes.is_empty())
    _epoch = packet.session_epoch
    _topology = packet.meshes.duplicate(true)
    var shader := Shader.new()
    shader.code = ACTOR_SHADER
    var blank := ShaderMaterial.new()
    blank.shader = shader
    _materials.append(blank)
    for source: Dictionary in packet.images:
        var image := Image.create_from_data(source.width, source.height, int(source.get("mipmaps", 1)) > 1, Image.FORMAT_RGBA8, source.rgba)
        var material := ShaderMaterial.new()
        material.shader = shader
        material.set_shader_parameter("source_texture", ImageTexture.create_from_image(image))
        material.set_shader_parameter("textured", true)
        _materials.append(material)
    for source: Dictionary in _topology:
        var groups: Dictionary = {}
        for triangle in source.triangles:
            var image_index: int = source.images[triangle] if not source.images.is_empty() else -1
            # Never turn a missing requested texture (-2) into a Ready fallback.
            assert(image_index >= -1 and image_index + 1 < _materials.size())
            if not groups.has(image_index):
                groups[image_index] = []
            groups[image_index].append(triangle)
        _groups.append(groups)
        var node := MeshInstance3D.new()
        node.mesh = ArrayMesh.new()
        add_child(node)
        _nodes.append(node)
    present(packet)


func present(packet: Dictionary) -> void:
    assert(packet.ok and packet.session_epoch == _epoch)
    for index in _nodes.size():
        var pose: Dictionary = packet.meshes[index]
        var source: Dictionary = _topology[index]
        var mesh: ArrayMesh = _nodes[index].mesh
        mesh.clear_surfaces()
        _nodes[index].visible = pose.triangles > 0
        if pose.triangles == 0:
            continue
        for image_index: int in _groups[index]:
            var positions := PackedVector3Array()
            var normals := PackedVector3Array()
            var uv := PackedVector2Array()
            var colors := PackedColorArray()
            for triangle: int in _groups[index][image_index]:
                for corner in 3:
                    var vertex := triangle * 3 + corner
                    positions.append(pose.positions[vertex])
                    normals.append(pose.normals[vertex])
                    uv.append(source.uv[vertex] if not source.uv.is_empty() else Vector2.ZERO)
                    colors.append(source.colors[triangle])
            var arrays: Array = []
            arrays.resize(Mesh.ARRAY_MAX)
            arrays[Mesh.ARRAY_VERTEX] = positions
            arrays[Mesh.ARRAY_NORMAL] = normals
            arrays[Mesh.ARRAY_TEX_UV] = uv
            arrays[Mesh.ARRAY_COLOR] = colors
            mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, 0)
            mesh.surface_set_material(mesh.get_surface_count() - 1, _materials[image_index + 1])
