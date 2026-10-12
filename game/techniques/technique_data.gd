class_name TechniqueData
extends Resource
## Datos de una tecnica. Anadir una nueva = anadir un .tres con este script.

@export var nombre: String = ""
## Nombres de los sellos en orden (vacio si no lleva sellos)
@export var secuencia: PackedStringArray = PackedStringArray()
## Escena que se instancia al lanzar la tecnica
@export var escena: PackedScene
