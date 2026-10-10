extends Node3D
## Escena de prueba de hand tracking (paso a).
## Dibuja una esfera en cada articulacion de ambas manos y muestra
## en un texto VR si llegan manos opticas o solo mandos.

const TRACKER_IZQ: StringName = &"/user/hand_tracker/left"
const TRACKER_DER: StringName = &"/user/hand_tracker/right"
const RADIO_ESFERA: float = 0.008

# Colores por dedo: palma/muneca, pulgar, indice, corazon, anular, menique
const COLORES: Array[Color] = [
	Color.WHITE, Color.RED, Color.GREEN, Color.DODGER_BLUE, Color.YELLOW, Color.MAGENTA
]

@onready var origen: XROrigin3D = $XROrigin3D
@onready var etiqueta: Label3D = $XROrigin3D/XRCamera3D/StatusLabel
@onready var esferas_root: Node3D = $JointSpheres

var _esferas_izq: Array[MeshInstance3D] = []
var _esferas_der: Array[MeshInstance3D] = []
var _tiempo_texto: float = 0.0


func _ready() -> void:
	_iniciar_xr()
	_esferas_izq = _crear_esferas("Izq")
	_esferas_der = _crear_esferas("Der")


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


func _process(delta: float) -> void:
	var t_izq := XRServer.get_tracker(TRACKER_IZQ) as XRHandTracker
	var t_der := XRServer.get_tracker(TRACKER_DER) as XRHandTracker
	_actualizar_esferas(t_izq, _esferas_izq)
	_actualizar_esferas(t_der, _esferas_der)

	_tiempo_texto += delta
	if _tiempo_texto >= 0.25:
		_tiempo_texto = 0.0
		_actualizar_texto(t_izq, t_der)


# Coloca cada esfera en su articulacion (espacio del XROrigin3D)
func _actualizar_esferas(tracker: XRHandTracker, esferas: Array[MeshInstance3D]) -> void:
	var hay_datos: bool = tracker != null and tracker.has_tracking_data
	for j in esferas.size():
		var esfera := esferas[j]
		if not hay_datos:
			esfera.visible = false
			continue
		var flags: int = tracker.get_hand_joint_flags(j)
		var valida: bool = (flags & XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID) != 0
		esfera.visible = valida
		if valida:
			esfera.global_transform = origen.global_transform * tracker.get_hand_joint_transform(j)


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
