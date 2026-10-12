extends Node3D
## Escena de prueba de hand tracking (paso a).
## Dibuja una esfera en cada articulacion y un hueso (cilindro) entre ellas.
## Muestra en un texto VR si llegan manos opticas o solo mandos.

const TRACKER_IZQ: StringName = &"/user/hand_tracker/left"
const TRACKER_DER: StringName = &"/user/hand_tracker/right"
const RADIO_ESFERA: float = 0.008
const RADIO_HUESO: float = 0.005

# Colores por dedo: palma/muneca, pulgar, indice, corazon, anular, menique
const COLORES: Array[Color] = [
	Color.WHITE, Color.RED, Color.GREEN, Color.DODGER_BLUE, Color.YELLOW, Color.MAGENTA
]

# Pares de articulaciones que se unen con un hueso (1 = muneca)
const HUESOS: Array[Vector2i] = [
	Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 5),
	Vector2i(1, 6), Vector2i(6, 7), Vector2i(7, 8), Vector2i(8, 9), Vector2i(9, 10),
	Vector2i(1, 11), Vector2i(11, 12), Vector2i(12, 13), Vector2i(13, 14), Vector2i(14, 15),
	Vector2i(1, 16), Vector2i(16, 17), Vector2i(17, 18), Vector2i(18, 19), Vector2i(19, 20),
	Vector2i(1, 21), Vector2i(21, 22), Vector2i(22, 23), Vector2i(23, 24), Vector2i(24, 25),
	Vector2i(7, 12), Vector2i(12, 17), Vector2i(17, 22),
]

@onready var origen: XROrigin3D = $XROrigin3D
@onready var etiqueta: Label3D = $XROrigin3D/XRCamera3D/StatusLabel
@onready var esferas_root: Node3D = $JointSpheres

var _esferas_izq: Array[MeshInstance3D] = []
var _esferas_der: Array[MeshInstance3D] = []
var _huesos_izq: Array[MeshInstance3D] = []
var _huesos_der: Array[MeshInstance3D] = []
var _tiempo_texto: float = 0.0


func _ready() -> void:
	_iniciar_xr()
	_esferas_izq = _crear_esferas("Izq")
	_esferas_der = _crear_esferas("Der")
	_huesos_izq = _crear_huesos("Izq")
	_huesos_der = _crear_huesos("Der")


# Arranca OpenXR (esta escena no usa el staging de la plantilla)
func _iniciar_xr() -> void:
	var xr: XRInterface = XRServer.find_interface("OpenXR")
	if xr == null:
		push_error("HandTest: no existe la interfaz OpenXR")
		return
	if not xr.is_initialized():
		xr.initialize()
	if xr.is_initialized():
		get_viewport().use_xr = true
		# En VR el refresco lo marca el visor, no la ventana
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	else:
		push_error("HandTest: OpenXR no se pudo inicializar (revisa Meta Link)")


# Devuelve el indice de color segun la articulacion
func _indice_color(joint: int) -> int:
	if joint <= XRHandTracker.HAND_JOINT_WRIST:
		return 0
	if joint <= XRHandTracker.HAND_JOINT_THUMB_TIP:
		return 1
	if joint <= XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP:
		return 2
	if joint <= XRHandTracker.HAND_JOINT_MIDDLE_FINGER_TIP:
		return 3
	if joint <= XRHandTracker.HAND_JOINT_RING_FINGER_TIP:
		return 4
	return 5


func _crear_esferas(lado: String) -> Array[MeshInstance3D]:
	var malla := SphereMesh.new()
	malla.radius = RADIO_ESFERA
	malla.height = RADIO_ESFERA * 2.0
	malla.radial_segments = 8
	malla.rings = 4

	var materiales: Array[StandardMaterial3D] = []
	for c in COLORES:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		materiales.append(m)

	var lista: Array[MeshInstance3D] = []
	for j in XRHandTracker.HAND_JOINT_MAX:
		var mi := MeshInstance3D.new()
		mi.name = "%s_%d" % [lado, j]
		mi.mesh = malla
		mi.material_override = materiales[_indice_color(j)]
		mi.visible = false
		esferas_root.add_child(mi)
		lista.append(mi)
	return lista


# Cilindros de altura 1 que luego se estiran hasta la longitud de cada hueso
func _crear_huesos(lado: String) -> Array[MeshInstance3D]:
	var malla := CylinderMesh.new()
	malla.top_radius = RADIO_HUESO
	malla.bottom_radius = RADIO_HUESO
	malla.height = 1.0
	malla.radial_segments = 6
	malla.rings = 1

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.9, 0.95)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var lista: Array[MeshInstance3D] = []
	for i in HUESOS.size():
		var mi := MeshInstance3D.new()
		mi.name = "Hueso_%s_%d" % [lado, i]
		mi.mesh = malla
		mi.material_override = mat
		mi.visible = false
		esferas_root.add_child(mi)
		lista.append(mi)
	return lista


func _process(delta: float) -> void:
	var t_izq := XRServer.get_tracker(TRACKER_IZQ) as XRHandTracker
	var t_der := XRServer.get_tracker(TRACKER_DER) as XRHandTracker
	_actualizar_esferas(t_izq, _esferas_izq)
	_actualizar_esferas(t_der, _esferas_der)
	_actualizar_huesos(t_izq, _huesos_izq)
	_actualizar_huesos(t_der, _huesos_der)

	_tiempo_texto += delta
	if _tiempo_texto >= 0.25:
		_tiempo_texto = 0.0
		_actualizar_texto(t_izq, t_der)


func _valida(tracker: XRHandTracker, joint: int) -> bool:
	var flags: int = tracker.get_hand_joint_flags(joint)
	return (flags & XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID) != 0


# Coloca cada esfera en su articulacion (espacio del XROrigin3D)
func _actualizar_esferas(tracker: XRHandTracker, esferas: Array[MeshInstance3D]) -> void:
	var hay_datos: bool = tracker != null and tracker.has_tracking_data
	for j in esferas.size():
		var esfera := esferas[j]
		if not hay_datos:
			esfera.visible = false
			continue
		var valida: bool = _valida(tracker, j)
		esfera.visible = valida
		if valida:
			esfera.global_transform = origen.global_transform * tracker.get_hand_joint_transform(j)


# Estira y orienta cada cilindro entre dos articulaciones
func _actualizar_huesos(tracker: XRHandTracker, huesos: Array[MeshInstance3D]) -> void:
	var hay_datos: bool = tracker != null and tracker.has_tracking_data
	for i in huesos.size():
		var hueso := huesos[i]
		if not hay_datos:
			hueso.visible = false
			continue
		var j0: int = HUESOS[i].x
		var j1: int = HUESOS[i].y
		if not (_valida(tracker, j0) and _valida(tracker, j1)):
			hueso.visible = false
			continue
		var a: Vector3 = origen.global_transform * tracker.get_hand_joint_transform(j0).origin
		var b: Vector3 = origen.global_transform * tracker.get_hand_joint_transform(j1).origin
		var dir: Vector3 = b - a
		var largo: float = dir.length()
		if largo < 0.002:
			hueso.visible = false
			continue
		var arriba: Vector3 = dir / largo
		var ref: Vector3 = Vector3.RIGHT if absf(arriba.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
		var x: Vector3 = arriba.cross(ref).normalized()
		var z: Vector3 = x.cross(arriba).normalized()
		hueso.global_transform = Transform3D(Basis(x, arriba * largo, z), (a + b) * 0.5)
		hueso.visible = true


func _nombre_fuente(tracker: XRHandTracker) -> String:
	if tracker == null:
		return "sin tracker"
	if not tracker.has_tracking_data:
		return "sin datos"
	match tracker.hand_tracking_source:
		XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED:
			return "MANO (optico)"
		XRHandTracker.HAND_TRACKING_SOURCE_CONTROLLER:
			return "MANDO"
		XRHandTracker.HAND_TRACKING_SOURCE_NOT_TRACKED:
			return "no detectada"
		_:
			return "MANO (fuente desconocida)"


func _es_optico(tracker: XRHandTracker) -> bool:
	return tracker != null \
		and tracker.has_tracking_data \
		and tracker.hand_tracking_source != XRHandTracker.HAND_TRACKING_SOURCE_CONTROLLER \
		and tracker.hand_tracking_source != XRHandTracker.HAND_TRACKING_SOURCE_NOT_TRACKED


func _hay_mando(nombre: StringName) -> bool:
	var t := XRServer.get_tracker(nombre) as XRPositionalTracker
	if t == null:
		return false
	var pose: XRPose = t.get_pose(&"default")
	return pose != null and pose.has_tracking_data


func _actualizar_texto(t_izq: XRHandTracker, t_der: XRHandTracker) -> void:
	var xr: XRInterface = XRServer.primary_interface
	var xr_ok: bool = xr != null and xr.is_initialized()
	var optico: bool = _es_optico(t_izq) or _es_optico(t_der)
	var mandos: bool = _hay_mando(&"left_hand") or _hay_mando(&"right_hand")

	var estado: String
	var color: Color
	if not xr_ok:
		estado = "OPENXR NO INICIADO"
		color = Color.RED
	elif optico:
		estado = "HAND TRACKING ACTIVO"
		color = Color.GREEN
	elif mandos or _nombre_fuente(t_izq) == "MANDO" or _nombre_fuente(t_der) == "MANDO":
		estado = "SOLO MANDOS (sin manos)"
		color = Color.ORANGE
	else:
		estado = "SIN DATOS DE MANOS NI MANDOS"
		color = Color.RED

	etiqueta.modulate = color
	etiqueta.text = "%s\nIzq: %s\nDer: %s\nMandos detectados: %s\nFPS: %d" % [
		estado,
		_nombre_fuente(t_izq),
		_nombre_fuente(t_der),
		"si" if mandos else "no",
		Engine.get_frames_per_second(),
	]
