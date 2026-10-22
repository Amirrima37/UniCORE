class_name AgentDiagnostic
extends RefCounted

## Парсер и генератор диагностических сообщений UniCORE (AgentDiagnostic)
## Выполняет интеллектуальный анализ ошибок компиляции, безопасности (AST)
## и сетевых ошибок API, формируя структурированные диагностические события.

## Парсинг произвольного текста ошибки в структурированный словарь диагностики
static func from_error(error_text: String) -> Dictionary:
	var raw_text := error_text
	var lower := error_text.to_lower()

	# 1. Проверка ошибок региона API (например Google Gemini)
	var is_region_error := false
	if lower.contains("location is not supported") or lower.contains("user location is not supported"):
		is_region_error = true
	elif lower.contains("region is not supported") or lower.contains("location not supported"):
		is_region_error = true
	elif lower.contains("регион не поддерживается") or lower.contains("недоступен из вашего региона"):
		is_region_error = true

	if is_region_error:
		var msg := "Google Gemini недоступен из вашего региона. Переключитесь на OpenRouter в Настройках."
		return {
			"category": "NET",
			"level": "ERROR",
			"title": "Ошибка региона API",
			"user_message": msg,
			"message": msg,
			"details": raw_text,
			"suggested_action": "open_settings_api",
			"line_number": -1,
			"raw_data": raw_text
		}

	# 2. Выделяем тело ошибки без префикса "Security/Syntax validation failed:"
	# чтобы исключить ложные срабатывания слова "Security" на синтаксических ошибках валидатора
	var error_body := lower
	var prefix_idx := lower.find("validation failed:")
	if prefix_idx != -1:
		error_body = lower.substr(prefix_idx + "validation failed:".length()).strip_edges()

	# 3. Проверка нарушений безопасности (AST / CodeValidator / Sandbox)
	var is_security := false
	if error_body.contains("security violation") or lower.contains("security violation"):
		is_security = true
	elif error_body.contains("политик") and error_body.contains("безопасн"):
		is_security = true
	elif error_body.contains("нарушение безопасности") or error_body.contains("нарушения безопасности"):
		is_security = true
	elif error_body.contains("заблокировано политикой") or error_body.contains("заблокировано политикой безопасности"):
		is_security = true
	elif error_body.contains("безопасн") and (error_body.contains("ast") or error_body.contains("код") or error_body.contains("ошибка")):
		is_security = true
	elif lower.contains("ast") and (lower.contains("security") or lower.contains("безопасн")):
		is_security = true
	elif error_body.contains("forbidden call to") or error_body.contains("outside safe sandbox") or error_body.contains("path traversal"):
		is_security = true
	elif error_body.contains("modifying 'res://'") or error_body.contains("modifying res://"):
		is_security = true
	elif error_body.contains("modifying and saving projectsettings") or error_body.contains("saving projectsettings"):
		is_security = true
	elif error_body.contains("direct system file tampering detected") or error_body.contains("reflection bypass"):
		is_security = true
	elif error_body.contains("file modifications outside 'user://' are forbidden"):
		is_security = true

	if is_security:
		var sec_msg := "Код содержит недопустимые вызовы (FileAccess/OS)"
		return {
			"category": "SECURITY",
			"level": "ERROR",
			"title": "Заблокировано политикой безопасности",
			"user_message": sec_msg,
			"message": sec_msg,
			"details": raw_text,
			"suggested_action": "",
			"line_number": -1,
			"raw_data": raw_text
		}

	# 4. Проверка ошибок компиляции и синтаксиса GDScript
	var is_compile := false
	if lower.contains("syntax") or lower.contains("compilation") or lower.contains("compile") or lower.contains("parse error"):
		is_compile = true
	elif lower.contains("синтаксис") or lower.contains("компиляц"):
		is_compile = true
	elif lower.contains("gdscript syntax/compilation error") or lower.contains("gdscript::reload"):
		is_compile = true
	elif lower.contains("expected ") and lower.contains("after"):
		is_compile = true

	if is_compile:
		var line_num := _extract_line_number(raw_text)
		var compile_msg := "Сгенерированный код не прошел компиляцию"
		return {
			"category": "COMPILE",
			"level": "ERROR",
			"title": "Ошибка синтаксиса GDScript",
			"user_message": compile_msg,
			"message": compile_msg,
			"details": raw_text,
			"suggested_action": "",
			"line_number": line_num,
			"raw_data": raw_text
		}

	# 5. Общие сетевые сбои
	if lower.contains("connection refused") or lower.contains("timed out") or lower.contains("failed to connect") or lower.contains("network") or lower.contains("сетев"):
		var net_msg := "Ошибка сетевого соединения с LLM-провайдером"
		return {
			"category": "NET",
			"level": "ERROR",
			"title": "Ошибка сети",
			"user_message": net_msg,
			"message": net_msg,
			"details": raw_text,
			"suggested_action": "",
			"line_number": -1,
			"raw_data": raw_text
		}

	# 6. Fallback для общих ошибок Агента
	var default_msg := raw_text if not raw_text.strip_edges().is_empty() else "Произошла неизвестная ошибка при обработке запроса"
	return {
		"category": "AGENT",
		"level": "ERROR",
		"title": "Ошибка выполнения",
		"user_message": default_msg,
		"message": default_msg,
		"details": raw_text,
		"suggested_action": "",
		"line_number": -1,
		"raw_data": raw_text
	}

## Создание события успешного монтажа модуля
static func from_success(mod_id: String) -> Dictionary:
	var msg := "Модуль '%s' успешно интегрирован в Пространство." % mod_id
	return {
		"category": "AGENT",
		"level": "SUCCESS",
		"title": "Модуль смонтирован",
		"user_message": msg,
		"message": msg,
		"details": "Модуль '%s' успешно загружен и смонтирован" % mod_id,
		"suggested_action": "",
		"line_number": -1,
		"raw_data": { "module_id": mod_id }
	}

## Создание события начала обработки запроса
static func from_request(prompt: String) -> Dictionary:
	var msg := "Обработка запроса: %s" % prompt
	return {
		"category": "AGENT",
		"level": "INFO",
		"title": "Запрос к Агенту",
		"user_message": msg,
		"message": msg,
		"details": prompt,
		"suggested_action": "",
		"line_number": -1,
		"raw_data": { "prompt": prompt }
	}

## Извлечение номера строки из сообщения об ошибке
static func _extract_line_number(text: String) -> int:
	var regex := RegEx.new()
	# Шаблоны:
	# 1. .gd:(\d+) или .gd\((\d+)\)
	# 2. line[\s:]*(\d+) (с учетом префикса at line)
	# 3. строк[аеиоу]?[\s:]*(\d+) (без ASCII \b, чтобы корректно работало с кириллицей)
	var pattern := "(?i)(?:\\.gd:(\\d+)|\\.gd\\((\\d+)\\)|(?:^|[^a-z0-9_])(?:at\\s+)?line[\\s:]*(\\d+)|(?:^|[^a-z0-9_а-яё])строк[аеиоу]?[\\s:]*(\\d+))"
	var err := regex.compile(pattern)
	if err == OK:
		var match_res := regex.search(text)
		if match_res:
			for group_idx in range(1, match_res.get_group_count() + 1):
				var num_str := match_res.get_string(group_idx)
				if not num_str.is_empty() and num_str.is_valid_int():
					return num_str.to_int()
	return -1
