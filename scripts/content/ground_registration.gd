class_name GroundRegistration
extends RefCounted
## Ground envelopes include the ENTIRE rigid base, not three idealized corners.
## Uniform scale/translation only: no affine shear, rotation or anisotropic scale.
const BASE := {
 "cabin": [[Vector2(44,350),Vector2(257,211),Vector2(499,351),Vector2(286,494)], [Vector2(556,351),Vector2(770,213),Vector2(1011,353),Vector2(796,494)]],
 "reception": [[Vector2(1062,402),Vector2(1273,280),Vector2(1503,405),Vector2(1294,511)]],
 "cafe": [[Vector2(48,848),Vector2(269,710),Vector2(496,842),Vector2(271,964)]],
 "pool": [[Vector2(28,735),Vector2(704,345),Vector2(1252,734),Vector2(576,1121)]],
 "sunbeds": [[Vector2(1082,824),Vector2(1299,710),Vector2(1503,844),Vector2(1286,958)]],
 "pier": [[Vector2(864,730),Vector2(987,790),Vector2(1507,358),Vector2(1377,298)]],
 "flowers": [[Vector2(1181,515),Vector2(1290,576),Vector2(1440,562),Vector2(1499,502),Vector2(1370,452),Vector2(1235,468)]],
 "palm": [[Vector2(134,544),Vector2(202,517),Vector2(275,545),Vector2(202,575)]],
 "small_palm": [[Vector2(538,546),Vector2(601,520),Vector2(668,546),Vector2(601,573)]],
 "lantern": [[Vector2(584,907),Vector2(611,890),Vector2(641,910),Vector2(611,933)]],
 "bin": [[Vector2(889,898),Vector2(963,857),Vector2(1039,899),Vector2(963,935)]],
 "rocks": [[Vector2(1157,891),Vector2(1325,834),Vector2(1488,891),Vector2(1325,940)]]
}
const MODELED := ["volleyball","bench","hedge","dolphin_statue"] + ResortServices.EXPANSION
const CANOPIES := ["palm","small_palm"]
static var fitted: Dictionary = {}
static func has_registration(kind: String, orientation: int = 0) -> bool:
 return (BASE.has(kind) and orientation >= 0 and orientation < BASE[kind].size()) or (kind in MODELED and orientation == 0)
static func source_floor(kind: String, orientation: int = 0) -> PackedVector2Array:
 return PackedVector2Array(BASE[kind][orientation]) if BASE.has(kind) else PackedVector2Array()
static func art_transform(kind: String, orientation: int, footprint: Vector2i, region: Rect2, texture_size: Vector2, width: float, image: Image = null) -> Transform2D:
 assert(has_registration(kind,orientation),"Missing full ground envelope: "+kind)
 var center := sort_offset(footprint)
 if kind in MODELED:
  # Models are rendered at exactly 64 x 32 pixels per ground tile. No fitting.
  var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/registration/structures.json"))[kind]
  return Transform2D(0.0,Vector2(metadata.origin[0],metadata.origin[1])*-1.0)
 var bounds := Rect2()
 var first := true
 var mirror := -1.0 if kind == "pool" else 1.0
 for point: Vector2 in BASE[kind][orientation]:
  var logical := IsometricGrid.unproject(Vector2(point.x*mirror,point.y))
  if first:
   bounds = Rect2(logical,Vector2.ZERO)
   first = false
  else:
   bounds = bounds.expand(logical)
 var factor := minf(footprint.x/bounds.size.x,footprint.y/bounds.size.y)*0.94
 # Organic canopy may overhang at height, but its entire ground bed is contained.
 if kind in ["palm","small_palm","lantern","bin","rocks"]:
  factor = minf(factor,width/texture_size.x)
 var source_center := IsometricGrid.project(bounds.get_center())
 if image != null and not kind in CANOPIES:
  var key := "%s/%d/%s"%[kind,orientation,footprint]
  if not fitted.has(key):
   var limit := factor
   # The complete opaque structure must fit the vertical extrusion of its
   # footprint, including every step, rim and roof. Height never causes skew.
   for y in image.get_height():
    for x in image.get_width():
     if image.get_pixel(x,y).a < 0.20: continue
     var source_pixel := Vector2(x+0.5,y+0.5)+region.position
     var delta := Vector2(source_pixel.x*mirror,source_pixel.y)-source_center
     var logical := IsometricGrid.unproject(delta)
     if logical.x > 0: limit = minf(limit,footprint.x*0.49/logical.x)
     if logical.y > 0: limit = minf(limit,footprint.y*0.49/logical.y)
     if absf(delta.x)>0: limit = minf(limit,(footprint.x+footprint.y)*15.68/absf(delta.x))
   fitted[key] = limit
  factor = fitted[key]
 var origin := center-source_center*factor + Vector2(region.position.x*mirror,region.position.y)*factor
 return Transform2D(Vector2(factor*mirror,0),Vector2(0,factor),origin)
static func sort_offset(footprint: Vector2i) -> Vector2:
 return IsometricGrid.project(Vector2(footprint-Vector2i.ONE)*0.5)
