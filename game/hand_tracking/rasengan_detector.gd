class_name RasenganDetector
extends Node
## Detecta el gesto del Rasengan:
## mano base con la palma hacia arriba y dedos curvados, y la otra mano
## haciendo circulos encima. Sin sellos.

signal rasengan_iniciado(base_izq: bool)
signal rasengan_terminado()

const TRACKER_IZQ: StringName = &"/user/hand_tracker/left"
const TRACKER_DER: StringName = &"/user/hand_tracker/right"

## 1.0 = normal. Sube (1.3, 1.5) para ser mas permisivo, baja para ser mas estricto.
@export_range(0.5, 2.0, 0.05) var tolerancia: float = 1.0
## Fraccion de vuelta completa que hay que dar con la otra mano (0.8 = casi una vuelta)
@export_range(0.3, 2.0, 0.05) var vueltas_necesarias: float = 0.8
## Distancia horizontal maxima (m) entre la palma base y la otra mano
@export var dist_horizontal_max: float = 0.18
## Altura (m) de la otra mano sobre la palma base
@export var altura_min: float = 0.03
@export var altura_max: float = 0.30
## Segundos que se aguanta si pierdes el gesto antes de apagar el Rasengan
@export var tiempo_gracia: float = 0.5

var origen: XROrigin3D
var activo: bool = false
var base_pos: Vector3 = Vector3.ZERO
var base_normal: Vector3 = Vector3.UP
var debug_text: String = "Detector sin iniciar"

var _giro: float = 0.0
var _prev_ang: float = 0.0
var _tiene_prev: bool = false
var _centro_h: Vector2 = Vector2.ZERO
var _tiene_centro: bool = false
var _cand_izq: int = -1
var _base_izq: bool = false
var _perdida: float = 0.0


func _process(delta: float) -> void:
	if origen == null:
		return
	var fi: HandFeatures = _crear(true)
	var fd: HandFeatures = _crear(false)
	if activo:
		_seguir(fi if _base_izq else fd, delta)
	else:
		_buscar(fi, fd, delta)


func _crear(izq: bool) -> HandFeatures:
	var nombre: StringName = TRACKER_IZQ if izq else TRACKER_DER
	return HandFeatures.new(XRServer.get_tracker(nombre) as XRHandTracker, izq, origen.global_transform)


# Minimo de "palma arriba" (1 = totalmente hacia arriba)
func _umbral_palma() -> float:
	return clampf(0.6 / tolerancia, 0.1, 0.95)


# Cuantos dedos (de 4) estan curvados "a medias"
func _curvados(f: HandFeatures) -> int:
	var lo: float = 0.2 / tolerancia
	var hi: float = minf(0.8 * tolerancia, 1.0)
	var n: int = 0
	for d in 4:
		var c: float = f.curvatura(d)
		if c >= lo and c <= hi:
			n += 1
	return n


func _base_valida(f: HandFeatures) -> bool:
	return f.valida() and f.normal_palma().y >= _umbral_palma() and _curvados(f) >= 3


func _mover_cerca(b: HandFeatures, m: HandFeatures) -> bool:
	var rel: Vector3 = m.centro_palma() - b.centro_palma()
	var horizontal: float = Vector2(rel.x, rel.z).length()
	return horizontal <= dist_horizontal_max * tolerancia \
		and rel.y >= altura_min and rel.y <= altura_max * tolerancia


func _buscar(fi: HandFeatures, fd: HandFeatures, delta: float) -> void:
	var texto: String = ""
	var sel_b: HandFeatures = null
	var sel_m: HandFeatures = null
	# Probamos izquierda como base y derecha encima, y al reves
	for izq: bool in [true, false]:
		var b: HandFeatures = fi if izq else fd
		var m: HandFeatures = fd if izq else fi
		if not b.valida():
			continue
		var py: float = b.normal_palma().y
		var cv: int = _curvados(b)
		var cerca: bool = m.valida() and _mover_cerca(b, m)
		texto += "%s base: palma arriba %.2f (min %.2f) | curvados %d/4 | otra mano encima: %s\n" % [
			"Izq" if izq else "Der", py, _umbral_palma(), cv, "si" if cerca else "no"
		]
		if sel_b == null and _base_valida(b) and cerca:
			sel_b = b
			sel_m = m

	if sel_b != null:
		var c: int = 1 if sel_b.es_izq else 0
		if c != _cand_izq:
			_reset_giro()
			_cand_izq = c
		_acumular(sel_b, sel_m, delta)
	else:
		_cand_izq = -1
		_tiene_prev = false
		_tiene_centro = false
		_giro = move_toward(_giro, 0.0, delta * 1.5)

	var objetivo: float = TAU * vueltas_necesarias
	var pct: int = int(clampf(absf(_giro) / objetivo, 0.0, 1.0) * 100.0)
	if texto == "":
		texto = "No veo ninguna mano valida\n"
	debug_text = texto + "Giro: %d%%" % pct

	if sel_b != null and absf(_giro) >= objetivo:
		_activar(sel_b.es_izq)


# Suma el angulo que gira la otra mano alrededor de su propio centro de movimiento
func _acumular(b: HandFeatures, m: HandFeatures, delta: float) -> void:
	var rel: Vector3 = m.centro_palma() - b.centro_palma()
	var h: Vector2 = Vector2(rel.x, rel.z)
	if not _tiene_centro:
		_centro_h = h
		_tiene_centro = true
		return
	_centro_h = _centro_h.lerp(h, 1.0 - exp(-delta * 1.5))
	var v: Vector2 = h - _centro_h
	if v.length() < 0.01:
		_tiene_prev = false
		_giro = move_toward(_giro, 0.0, delta * 0.6)
		return
	var ang: float = v.angle()
	if _tiene_prev:
		_giro += clampf(angle_difference(_prev_ang, ang), -1.5, 1.5)
	_prev_ang = ang
	_tiene_prev = true
	_giro = move_toward(_giro, 0.0, delta * 0.4)


func _activar(base_izq: bool) -> void:
	activo = true
	_base_izq = base_izq
	_perdida = 0.0
	_reset_giro()
	rasengan_iniciado.emit(base_izq)


func _seguir(f: HandFeatures, delta: float) -> void:
	if f.valida() and f.normal_palma().y >= _umbral_palma() * 0.4:
		_perdida = 0.0
		base_pos = f.centro_palma()
		base_normal = f.normal_palma()
		debug_text = "RASENGAN ACTIVO\n(gira la palma hacia abajo para apagarlo)"
	else:
		_perdida += delta
		if _perdida >= tiempo_gracia:
			_terminar()


func _terminar() -> void:
	activo = false
	_reset_giro()
	rasengan_terminado.emit()


func _reset_giro() -> void:
	_giro = 0.0
	_tiene_prev = false
	_tiene_centro = false
	_cand_izq = -1
