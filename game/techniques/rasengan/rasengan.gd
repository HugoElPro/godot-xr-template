extends Node3D
## Esfera de chakra del Rasengan. Se construye por codigo para que sea ligera.

var _capa: MeshInstance3D
var _anillo1: MeshInstance3D
var _anillo2: MeshInstance3D


func _ready() -> void:
	scale = Vector3.ONE * 0.01
	_construir()


func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	return m


func _construir() -> void:
	# Nucleo blanco
	var nucleo := MeshInstance3D.new()
	var sn := SphereMesh.new()
	sn.radius = 0.035
	sn.height = 0.07
	sn.radial_segments = 16
	sn.rings = 8
	nucleo.mesh = sn
	nucleo.material_override = _material(Color(1, 1, 1, 0.95))
	add_child(nucleo)

	# Capa exterior azul transparente
	_capa = MeshInstance3D.new()
	var sc := SphereMesh.new()
	sc.radius = 0.065
	sc.height = 0.13
	sc.radial_segments = 16
	sc.rings = 8
	_capa.mesh = sc
	_capa.material_override = _material(Color(0.3, 0.6, 1.0, 0.35))
	add_child(_capa)

	# Dos anillos girando en ejes distintos
	_anillo1 = _crear_anillo(Color(0.6, 0.85, 1.0, 0.8))
	_anillo2 = _crear_anillo(Color(0.6, 0.85, 1.0, 0.6))
	_anillo2.rotation.z = PI / 2.0

	# Pocas particulas para cuidar los FPS
	var part := CPUParticles3D.new()
	part.amount = 20
	part.lifetime = 0.6
	part.local_coords = true
	part.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	part.emission_sphere_radius = 0.06
	part.direction = Vector3.UP
	part.spread = 180.0
	part.gravity = Vector3.ZERO
	part.initial_velocity_min = 0.02
	part.initial_velocity_max = 0.06
	var sp := SphereMesh.new()
	sp.radius = 0.004
	sp.height = 0.008
	sp.radial_segments = 6
	sp.rings = 3
	sp.material = _material(Color(0.7, 0.9, 1.0, 0.8))
	part.mesh = sp
	add_child(part)


func _crear_anillo(color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.055
	t.outer_radius = 0.065
	t.rings = 24
	t.ring_segments = 8
	mi.mesh = t
	mi.material_override = _material(color)
	add_child(mi)
	return mi


func _process(delta: float) -> void:
	# Giros suaves (nada de parpadeos rapidos para no marear)
	_anillo1.rotate_y(delta * 6.0)
	_anillo2.rotate_x(delta * 5.0)
	_capa.rotate_y(delta * 3.0)


func aparecer() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func desaparecer() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.25)
	tw.tween_callback(queue_free)
