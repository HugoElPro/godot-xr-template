extends Node3D
## Escena de prueba del Rasengan (usa HandTest + el detector de gestos).

const DATOS: TechniqueData = preload("res://game/techniques/rasengan/rasengan_data.tres")

@onready var detector: RasenganDetector = $RasenganDetector

var _rasengan: Node3D = null
var _etiqueta: Label3D


func _ready() -> void:
	detector.origen = $HandTest/XROrigin3D as XROrigin3D
	detector.rasengan_iniciado.connect(_on_iniciado)
	detector.rasengan_terminado.connect(_on_terminado)

	# Texto de depuracion del detector, arriba del campo de vision
	_etiqueta = Label3D.new()
	_etiqueta.pixel_size = 0.001
	_etiqueta.font_size = 32
	_etiqueta.outline_size = 8
	_etiqueta.no_depth_test = true
	_etiqueta.position = Vector3(0, 0.3, -1.0)
	$HandTest/XROrigin3D/XRCamera3D.add_child(_etiqueta)


func _process(_delta: float) -> void:
	_etiqueta.text = detector.debug_text
	if _rasengan != null and is_instance_valid(_rasengan) and detector.activo:
		# La esfera flota sobre la palma, siguiendo la normal de la palma
		_rasengan.global_position = detector.base_pos + detector.base_normal * 0.09


func _on_iniciado(_base_izq: bool) -> void:
	_rasengan = DATOS.escena.instantiate() as Node3D
	add_child(_rasengan)
	_rasengan.global_position = detector.base_pos + detector.base_normal * 0.09
	_rasengan.call("aparecer")


func _on_terminado() -> void:
	if _rasengan != null and is_instance_valid(_rasengan):
		_rasengan.call("desaparecer")
	_rasengan = null
