extends Node3D
## A boss's throw: a ring on the ground where it will land, and the missile
## arcing down onto it, timed to land with the simulation. A spear (red
## ring), a glob of venom (green) or a boulder (amber). Purely visual; the driver frees
## it when the throw lands.

const SPEAR_LENGTH := 1.8
const ARC_HEIGHT := 5.0

var _disc: MeshInstance3D
var _age := 0.0


const RING_COLORS := {"spear": Color(0.9, 0.12, 0.08, 0.5), "venom": Color(0.35, 0.85, 0.15, 0.5),
	"boulder": Color(0.95, 0.6, 0.1, 0.5)}
## Lobbed missiles: [radius, colour, glows].
const LOBS := {"venom": [0.22, Color(0.4, 0.9, 0.2), true], "boulder": [0.5, Color(0.55, 0.52, 0.48), false]}


static func spawn(parent: Node, from: Vector3, at: Vector3, radius: float, seconds: float, kind := "spear") -> Node3D:
	var marker := new()
	parent.add_child(marker)
	marker.global_position = at + Vector3(0, 0.06, 0)
	marker._build(radius, RING_COLORS.get(kind, RING_COLORS["spear"]))
	if LOBS.has(kind):
		marker._lob(from + Vector3(0, 1.0, 0), seconds, LOBS[kind])
	else:
		marker._throw(from + Vector3(0, 1.6, 0), seconds)
	return marker


func _build(radius: float, color: Color) -> void:
	_disc = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.03
	disc.radial_segments = 24
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material = material
	_disc.mesh = disc
	add_child(_disc)


func _throw(from: Vector3, seconds: float) -> void:
	var spear := MeshInstance3D.new()
	var rod := BoxMesh.new()
	rod.size = Vector3(0.05, 0.05, SPEAR_LENGTH)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.36, 0.22)
	rod.material = material
	spear.mesh = rod
	add_child(spear)
	var to := global_position
	var tween := spear.create_tween()
	tween.tween_method(func(t: float):
		var at := from.lerp(to, t) + Vector3(0, sin(t * PI) * ARC_HEIGHT, 0)
		var ahead := from.lerp(to, minf(t + 0.05, 1.0)) + Vector3(0, sin(minf(t + 0.05, 1.0) * PI) * ARC_HEIGHT - (0.3 if t >= 0.95 else 0.0), 0)
		spear.global_position = at
		if at.distance_to(ahead) > 0.001:
			spear.look_at(ahead, Vector3.UP), 0.0, 1.0, maxf(seconds, 0.1))


## A glob of venom or a boulder, lobbed in a high arc.
func _lob(from: Vector3, seconds: float, look: Array) -> void:
	var glob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = look[0]
	sphere.height = look[0] * 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = look[1]
	material.emission_enabled = look[2]
	material.emission = look[1].darkened(0.4)
	sphere.material = material
	glob.mesh = sphere
	add_child(glob)
	var to := global_position
	var tween := glob.create_tween()
	tween.tween_method(func(t: float):
		glob.global_position = from.lerp(to, t) + Vector3(0, sin(t * PI) * ARC_HEIGHT, 0), 0.0, 1.0, maxf(seconds, 0.1))


func _process(delta: float) -> void:
	_age += delta
	var pulse := 1.0 + sin(_age * 14.0) * 0.06
	_disc.scale = Vector3(pulse, 1.0, pulse)
