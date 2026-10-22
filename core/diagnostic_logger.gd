class_name DiagnosticLogger
extends Node

## Централизованный логгер диагностики UniCORE (DiagnosticLogger)
## Обеспечивает кольцевой буфер на 200 записей, запись сессии в user://logs/session.log,
## категоризацию ("AGENT", "NET", "SECURITY", "COMPILE", "SYSTEM"), фильтрацию
## и экспорт/копирование в буфер обмена.

signal entry_added(entry: Dictionary)

const MAX_ENTRIES: int = 200
const LOG_DIR: String = "user://logs"
const LOG_FILE_PATH: String = "user://logs/session.log"

const META_INSTANCE_KEY := "_diagnostic_logger_instance"

var _entries: Array[Dictionary] = []
var _next_id: int = 1
var _file_logging_enabled: bool = true

func _init() -> void:
	Engine.set_meta(META_INSTANCE_KEY, self)
	_ensure_log_dir()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if Engine.has_meta(META_INSTANCE_KEY) and Engine.get_meta(META_INSTANCE_KEY) == self:
			Engine.set_meta(META_INSTANCE_KEY, null)

func _ready() -> void:
	if not Engine.has_meta(META_INSTANCE_KEY) or Engine.get_meta(META_INSTANCE_KEY) == null:
		Engine.set_meta(META_INSTANCE_KEY, self)
	_ensure_log_dir()

## Возвращает текущий активный экземпляр логгера, если он есть в дереве
static func get_instance() -> DiagnosticLogger:
	if Engine.has_meta(META_INSTANCE_KEY):
		var inst = Engine.get_meta(META_INSTANCE_KEY)
		if inst is DiagnosticLogger and is_instance_valid(inst):
			return inst
	return null

## Статическое логирование INFO (вызывается из SpaceViewport и UI)
static func log_info(message: String, title: String = "SYSTEM", details: String = "", raw_data: Variant = null) -> Dictionary:
	var inst := get_instance()
	if inst:
		return inst.log_entry(_infer_category(title), "INFO", title, message, details, raw_data)
	return _write_fallback_entry(_infer_category(title), "INFO", title, message, details, raw_data)

## Статическое логирование WARN
static func log_warn(message: String, title: String = "SYSTEM", details: String = "", raw_data: Variant = null) -> Dictionary:
	var inst := get_instance()
	if inst:
		return inst.log_entry(_infer_category(title), "WARN", title, message, details, raw_data)
	return _write_fallback_entry(_infer_category(title), "WARN", title, message, details, raw_data)

## Статическое логирование ERROR (вызывается из SpaceViewport и UI)
static func log_error(message: String, title: String = "SYSTEM", details: String = "", raw_data: Variant = null) -> Dictionary:
	var inst := get_instance()
	if inst:
		return inst.log_entry(_infer_category(title), "ERROR", title, message, details, raw_data)
	return _write_fallback_entry(_infer_category(title), "ERROR", title, message, details, raw_data)

## Статическое логирование SUCCESS
static func log_success(message: String, title: String = "SYSTEM", details: String = "", raw_data: Variant = null) -> Dictionary:
	var inst := get_instance()
	if inst:
		return inst.log_entry(_infer_category(title), "SUCCESS", title, message, details, raw_data)
	return _write_fallback_entry(_infer_category(title), "SUCCESS", title, message, details, raw_data)

## Определение категории по контексту или названию подсистемы
static func _infer_category(title: String) -> String:
	var t_upper := title.to_upper()
	if t_upper in ["AGENT", "AGENTBRAIN"]:
		return "AGENT"
	elif t_upper in ["NET", "NETWORK", "API"]:
		return "NET"
	elif t_upper in ["SECURITY", "VALIDATOR", "AST"]:
		return "SECURITY"
	elif t_upper in ["COMPILE", "COMPILER", "GDSCRIPT"]:
		return "COMPILE"
	return "SYSTEM"

## Запись события от Агента
func log_agent(level: String, title: String, message: String, details: String = "", raw_data: Variant = null) -> Dictionary:
	return log_entry("AGENT", level, title, message, details, raw_data)

## Запись системного события Ядра
func log_system(level: String, title: String, message: String, details: String = "", raw_data: Variant = null) -> Dictionary:
	return log_entry("SYSTEM", level, title, message, details, raw_data)

## Универсальный метод логирования с записью в кольцевой буфер и на диск
func log_entry(category: String, level: String, title: String, message: String, details: String = "", raw_data: Variant = null) -> Dictionary:
	var entry: Dictionary = {
		"id": _next_id,
		"timestamp": Time.get_unix_time_from_system(),
		"time_str": Time.get_datetime_string_from_system(),
		"category": category.to_upper(),
		"level": level.to_upper(),
		"title": title,
		"message": message,
		"details": details,
		"raw_data": raw_data
	}
	_next_id += 1

	_entries.append(entry)
	while _entries.size() > MAX_ENTRIES:
		_entries.pop_front()

	if _file_logging_enabled:
		_write_entry_to_disk(entry)

	entry_added.emit(entry)
	return entry

## Логирование диагностического словаря (например, из AgentDiagnostic)
func log_diagnostic(diagnostic: Dictionary) -> Dictionary:
	var cat: String = diagnostic.get("category", "AGENT")
	var lvl: String = diagnostic.get("level", "INFO")
	var title: String = diagnostic.get("title", "")
	var msg: String = diagnostic.get("message", diagnostic.get("user_message", ""))
	var det: String = str(diagnostic.get("details", ""))
	var raw: Variant = diagnostic.get("raw_data", null)
	return log_entry(cat, lvl, title, msg, det, raw)

## Получение последних записей с опциональной фильтрацией по категории
func get_recent_entries(count: int = 50, category_filter: String = "") -> Array[Dictionary]:
	var filter_upper := category_filter.strip_edges().to_upper()
	var filtered: Array[Dictionary] = []

	for entry in _entries:
		if filter_upper.is_empty() or entry.get("category", "") == filter_upper:
			filtered.append(entry)

	if count > 0 and filtered.size() > count:
		return filtered.slice(filtered.size() - count)
	return filtered

## Поиск записи по идентификатору
func get_entry_by_id(entry_id: int) -> Dictionary:
	for entry in _entries:
		if entry.get("id") == entry_id:
			return entry
	return {}

## Очистка буфера (и опционально файла на диске)
func clear(clear_disk: bool = false) -> void:
	_entries.clear()
	_next_id = 1
	if clear_disk and FileAccess.file_exists(LOG_FILE_PATH):
		DirAccess.remove_absolute(LOG_FILE_PATH)

## Экспорт логов сессии в текстовую строку
func export_session_log(from_disk: bool = false) -> String:
	if from_disk:
		if FileAccess.file_exists(LOG_FILE_PATH):
			var file := FileAccess.open(LOG_FILE_PATH, FileAccess.READ)
			if file:
				var content := file.get_as_text()
				file.close()
				return content
		return ""

	var lines := PackedStringArray()
	for entry in _entries:
		lines.append(_format_entry_line(entry))
	return "\n".join(lines)

## Копирование записи в буфер обмена системы через DisplayServer.clipboard_set
## Принимает либо Dictionary записи, либо числовой/строковый id записи
func copy_entry_to_clipboard(entry_or_id: Variant) -> String:
	var entry: Dictionary = {}
	if entry_or_id is Dictionary:
		entry = entry_or_id
	elif entry_or_id is int or entry_or_id is float:
		entry = get_entry_by_id(int(entry_or_id))
	elif entry_or_id is String and (entry_or_id as String).is_valid_int():
		entry = get_entry_by_id((entry_or_id as String).to_int())

	if entry.is_empty():
		return ""

	var text := _format_entry_full(entry)
	DisplayServer.clipboard_set(text)
	return text

## Форматирование записи для одной строки лога
static func _format_entry_line(entry: Dictionary) -> String:
	var time_str: String = str(entry.get("time_str", ""))
	var lvl: String = str(entry.get("level", "INFO"))
	var cat: String = str(entry.get("category", "SYSTEM"))
	var title: String = str(entry.get("title", ""))
	var msg: String = str(entry.get("message", ""))
	var det: String = str(entry.get("details", ""))

	var line := "[%s] [%s] [%s] %s: %s" % [time_str, lvl, cat, title, msg]
	if not det.is_empty():
		line += " | Details: %s" % det
	return line

## Полное форматирование записи для буфера обмена
static func _format_entry_full(entry: Dictionary) -> String:
	var time_str: String = str(entry.get("time_str", ""))
	var lvl: String = str(entry.get("level", "INFO"))
	var cat: String = str(entry.get("category", "SYSTEM"))
	var title: String = str(entry.get("title", ""))
	var msg: String = str(entry.get("message", ""))
	var det: String = str(entry.get("details", ""))
	var raw_data = entry.get("raw_data", null)

	var lines := PackedStringArray()
	lines.append("[%s] [%s] [%s] %s" % [time_str, lvl, cat, title])
	lines.append("Message: %s" % msg)
	if not det.is_empty():
		lines.append("Details: %s" % det)
	if raw_data != null and not str(raw_data).is_empty():
		lines.append("Raw Data: %s" % str(raw_data))
	return "\n".join(lines)

## Запись записи на диск в user://logs/session.log
func _write_entry_to_disk(entry: Dictionary) -> void:
	_ensure_log_dir()
	var line := _format_entry_line(entry)

	var file: FileAccess
	if FileAccess.file_exists(LOG_FILE_PATH):
		file = FileAccess.open(LOG_FILE_PATH, FileAccess.READ_WRITE)
		if file:
			file.seek_end()
	else:
		file = FileAccess.open(LOG_FILE_PATH, FileAccess.WRITE)

	if file:
		file.store_line(line)
		file.close()

## Статическая запись на диск при отсутствии живого инстанса
static func _write_fallback_entry(category: String, level: String, title: String, message: String, details: String = "", raw_data: Variant = null) -> Dictionary:
	_ensure_log_dir()
	var entry: Dictionary = {
		"id": -1,
		"timestamp": Time.get_unix_time_from_system(),
		"time_str": Time.get_datetime_string_from_system(),
		"category": category.to_upper(),
		"level": level.to_upper(),
		"title": title,
		"message": message,
		"details": details,
		"raw_data": raw_data
	}

	var line := _format_entry_line(entry)
	var file: FileAccess
	if FileAccess.file_exists(LOG_FILE_PATH):
		file = FileAccess.open(LOG_FILE_PATH, FileAccess.READ_WRITE)
		if file:
			file.seek_end()
	else:
		file = FileAccess.open(LOG_FILE_PATH, FileAccess.WRITE)

	if file:
		file.store_line(line)
		file.close()

	return entry

## Проверка и создание папки user://logs
static func _ensure_log_dir() -> void:
	if not DirAccess.dir_exists_absolute(LOG_DIR):
		DirAccess.make_dir_recursive_absolute(LOG_DIR)

## Статический метод получения форматированного текста логов для UI (AnalysisDrawer)
static func get_formatted_logs_text() -> String:
	var inst := get_instance()
	if inst and not inst._entries.is_empty():
		return inst.export_session_log(false)

	if FileAccess.file_exists(LOG_FILE_PATH):
		var file := FileAccess.open(LOG_FILE_PATH, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			file.close()
			if not content.strip_edges().is_empty():
				return content
	return "// Журнал системных событий пуст"
