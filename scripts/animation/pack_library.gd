class_name PackLibrary
extends RefCounted
## Acceso a las librerias de animacion derivadas del pack de Mixamo (ver tools/animation_pack/build_pack_library.gd).
## Se generan con el conversor y SE VERSIONAN junto con el pack (uso personal dentro del juego); el juego funciona sin ellas
## (usa los clips de Tripo y la patada procedural). Cada Animation lleva set_meta("pack", {...}) medido al convertir.

const FIELD_PATH := "res://assets/animations/pack_clips.res"
const KEEPER_PATH := "res://assets/animations/pack_keeper.res"

static var _field: AnimationLibrary = null
static var _keeper: AnimationLibrary = null
static var _loaded: bool = false

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if ResourceLoader.exists(FIELD_PATH):
		_field = load(FIELD_PATH) as AnimationLibrary
	if ResourceLoader.exists(KEEPER_PATH):
		_keeper = load(KEEPER_PATH) as AnimationLibrary

## Libreria de clips de campo, o null si no se ha generado.
static func field() -> AnimationLibrary:
	_ensure()
	return _field

## Libreria de clips de arquero (sin entidad todavia), o null. Se carga solo si alguien la pide.
static func keeper() -> AnimationLibrary:
	_ensure()
	return _keeper

static func available() -> bool:
	return field() != null

static func has_clip(id: StringName) -> bool:
	var lib: AnimationLibrary = field()
	if lib != null and lib.has_animation(id):
		return true
	var k: AnimationLibrary = keeper()
	return k != null and k.has_animation(id)

## Clip de campo o del arquero por su id (los ids no se repiten entre librerias).
static func clip(id: StringName) -> Animation:
	var lib: AnimationLibrary = field()
	if lib != null and lib.has_animation(id):
		return lib.get_animation(id)
	var k: AnimationLibrary = keeper()
	return k.get_animation(id) if k != null and k.has_animation(id) else null

## true si el clip es de la libreria del arquero (se reproduce desde "keeper/<id>").
static func is_keeper_clip(id: StringName) -> bool:
	var lib: AnimationLibrary = field()
	if lib != null and lib.has_animation(id):
		return false
	var k: AnimationLibrary = keeper()
	return k != null and k.has_animation(id)

## Nombre con el que el AnimationPlayer del visual conoce el clip ("pack/<id>" o "keeper/<id>").
static func anim_path(id: StringName) -> StringName:
	return StringName(("keeper/" if is_keeper_clip(id) else "pack/") + String(id))

## Metadatos medidos del clip (diccionario vacio si no existe).
static func meta(id: StringName) -> Dictionary:
	var a: Animation = clip(id)
	return a.get_meta("pack", {}) if a != null else {}

## Fuerza una nueva lectura de disco (pruebas).
static func reload() -> void:
	_loaded = false
	_field = null
	_keeper = null
