class_name ModelPrimitives
extends RefCounted
static var materials: Dictionary = {}
static func material(hex: String) -> StandardMaterial3D:
 if not materials.has(hex):
  var value := StandardMaterial3D.new()
  value.albedo_color = Color(hex)
  value.roughness = 0.88
  var ink := ShaderMaterial.new()
  var shader := Shader.new()
  shader.code = "shader_type spatial; render_mode unshaded, cull_front; void vertex(){ VERTEX += NORMAL * 0.008; } void fragment(){ ALBEDO=vec3(0.12,0.09,0.07); }"
  ink.shader = shader
  value.next_pass = ink
  materials[hex] = value
 return materials[hex]
static func mesh(parent: Node3D, shape: Mesh, at: Vector3, color: String) -> MeshInstance3D:
 var node := MeshInstance3D.new()
 node.mesh = shape
 node.material_override = material(color)
 node.position = at
 parent.add_child(node)
 return node
static func box(parent: Node3D, at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
 var shape := BoxMesh.new()
 shape.size = size
 return mesh(parent,shape,at,color)
static func ball(parent: Node3D, at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
 var shape := SphereMesh.new()
 shape.radial_segments = 16
 shape.rings = 8
 var node := mesh(parent,shape,at,color)
 node.scale = size
 return node
static func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: String, top: float = -1.0) -> MeshInstance3D:
 var shape := CylinderMesh.new()
 shape.top_radius = radius if top < 0.0 else top
 shape.bottom_radius = radius
 shape.height = height
 shape.radial_segments = 16
 return mesh(parent,shape,at,color)
static func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: String) -> MeshInstance3D:
 var node := cylinder(parent,(a+b)*0.5,radius,a.distance_to(b),color)
 node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
 return node
static func camera(viewport: SubViewport, density: float, target: Vector3) -> Camera3D:
 var camera_node := Camera3D.new()
 camera_node.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera_node.size = viewport.size.y/density
 camera_node.position = target+Vector3(10,8.1649658,10)
 viewport.add_child(camera_node)
 camera_node.look_at(target)
 camera_node.current = true
 var light := DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-55,-35,0)
 light.light_energy = 0.85
 light.shadow_enabled = true
 light.shadow_bias = 0.025
 viewport.add_child(light)
 var env := WorldEnvironment.new()
 var settings := Environment.new()
 settings.background_mode = Environment.BG_CLEAR_COLOR
 settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 settings.ambient_light_color = Color("d9deeb")
 settings.ambient_light_energy = 0.32
 settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
 env.environment = settings
 viewport.add_child(env)
 return camera_node
