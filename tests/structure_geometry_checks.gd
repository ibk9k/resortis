extends SceneTree
var failures: Array[String] = []
# Independent observations: full base, including the front step, planter rim,
# outer pool deck and bench feet. Not the old three registration points.
const BASES := {
 "cabin": [[Vector2(48,350),Vector2(286,487),Vector2(495,351),Vector2(257,214)],[Vector2(559,351),Vector2(796,488),Vector2(1007,353),Vector2(770,216)]],
 "reception": [[Vector2(1064,405),Vector2(1294,505),Vector2(1487,405),Vector2(1257,305)]],
 "cafe": [[Vector2(51,845),Vector2(271,960),Vector2(492,842),Vector2(272,727)]],
 "pool": [[Vector2(44,735),Vector2(576,1105),Vector2(1236,734),Vector2(704,364)]],
 "hedge": [[Vector2(795,543),Vector2(850,579),Vector2(1138,459),Vector2(1082,424)]],
 "flowers": [[Vector2(1190,515),Vector2(1290,572),Vector2(1440,558),Vector2(1490,502),Vector2(1370,452),Vector2(1235,468)]],
 "bench": [[Vector2(77,851),Vector2(355,942),Vector2(421,905),Vector2(145,815)]]
}
func _initialize() -> void:
 _run.call_deferred()
func _run() -> void:
 var library := ResortAssets.new()
 for kind: String in ResortCatalog.DEFINITIONS:
  for facing in ResortCatalog.definition(kind).frames.size():
   var item := PlacedResortObject.new()
   item.configure({"id":1,"kind":kind,"position":Vector2.ZERO,"orientation":facing},library)
   root.add_child(item)
   var basis := item.sprite.transform
   if absf(basis.y.x) > 0.00001 or absf(basis.x.y) > 0.00001 or absf(absf(basis.x.x)-absf(basis.y.y)) > 0.00001:
    failures.append("%s/%d warps upright art: %s" % [kind,facing,basis])
   if BASES.has(kind) and kind not in FacilityStaff.KINDS:
    var tex := item.sprite.texture as AtlasTexture
    if tex != null:
     var fp := ResortCatalog.footprint(kind,facing)
     for point: Vector2 in BASES[kind][facing]:
      var ground := IsometricGrid.unproject(item.sprite.to_global(point-tex.region.position))
      if ground.x < -0.5-0.02 or ground.y < -0.5-0.02 or ground.x > fp.x-0.5+0.02 or ground.y > fp.y-0.5+0.02:
       failures.append("%s/%d base outside reserved tiles at %s" % [kind,facing,ground])
   item.free()
 # Exact physical geometry bounds for modeled objects, independent of the
 # sprite transform. Every vertex must project onto the reserved XZ footprint.
 for kind: String in GroundRegistration.MODELED:
  var model := StructureModels.new()
  model.build(kind)
  root.add_child(model)
  _check_meshes(model,ResortCatalog.footprint(kind),kind)
  model.free()
 print("STRUCTURE_GEOMETRY_CHECKS ",JSON.stringify(failures))
 quit(0 if failures.is_empty() else 1)
func _check_meshes(node: Node3D,size: Vector2i,kind: String) -> void:
 if node is MeshInstance3D:
  var mesh := node as MeshInstance3D
  var arrays: Array = mesh.mesh.get_mesh_arrays() if mesh.mesh is PrimitiveMesh else []
  if not arrays.is_empty():
   for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
    var vertex := mesh.global_transform*point
    if vertex.x < -0.5-0.001 or vertex.z < -0.5-0.001 or vertex.x > size.x-0.5+0.001 or vertex.z > size.y-0.5+0.001:
     failures.append("3D %s vertex outside reservation: %s"%[kind,vertex])
     break
 for child in node.get_children():
  if child is Node3D: _check_meshes(child,size,kind)
