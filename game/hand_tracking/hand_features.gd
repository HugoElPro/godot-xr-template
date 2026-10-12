class_name HandFeatures
extends RefCounted
## Datos utiles de UNA mano a partir de las articulaciones de OpenXR.
## Todo se calcula en espacio mundo (usando la transformacion del XROrigin3D).

var tracker: XRHandTracker
var es_izq: bool
var xf: Transform3D


func _init(t: XRHandTracker, izq: bool, origen_xf: Transform3D) -> void:
	tracker = t
	es_izq = izq
	xf = origen_xf


# Hay datos y la palma y la muneca son fiables
func valida() -> bool:
	if tracker == null or not tracker.has_tracking_data:
		return false
	return _ok(XRHandTracker.HAND_JOINT_PALM) and _ok(XRHandTracker.HAND_JOINT_WRIST)


func _ok(j: int) -> bool:
	var flags: int = tracker.get_hand_joint_flags(j)
	return (flags & XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID) != 0


func pos(j: int) -> Vector3:
	return xf * tracker.get_hand_joint_transform(j).origin


func centro_palma() -> Vector3:
	return pos(XRHandTracker.HAND_JOINT_PALM)


# Curvatura del dedo: 0 = recto, 1 = puno cerrado.
# dedo: 0 indice, 1 corazon, 2 anular, 3 menique.
# Las articulaciones de cada dedo van de 5 en 5 desde el indice (6, 11, 16, 21).
func curvatura(dedo: int) -> float:
	var base: int = XRHandTracker.HAND_JOINT_INDEX_FINGER_METACARPAL + dedo * 5
	var p0: Vector3 = pos(base)
	var p1: Vector3 = pos(base + 1)
	var p2: Vector3 = pos(base + 2)
	var p3: Vector3 = pos(base + 3)
	var p4: Vector3 = pos(base + 4)
	var a1: float = (p1 - p0).angle_to(p2 - p1)
	var a2: float = (p2 - p1).angle_to(p3 - p2)
	var a3: float = (p3 - p2).angle_to(p4 - p3)
	return clampf((a1 + a2 + a3) / 4.0, 0.0, 1.0)


# Vector que sale de la palma (hacia donde "mira" la palma)
func normal_palma() -> Vector3:
	var indice: Vector3 = pos(XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_PROXIMAL)
	var menique: Vector3 = pos(XRHandTracker.HAND_JOINT_LITTLE_FINGER_PHALANX_PROXIMAL)
	var medio: Vector3 = pos(XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_PROXIMAL)
	var muneca: Vector3 = pos(XRHandTracker.HAND_JOINT_WRIST)
	var n: Vector3 = (indice - menique).cross(medio - muneca)
	# En la mano izquierda el producto vectorial sale al reves
	if es_izq:
		n = -n
	return n.normalized()
