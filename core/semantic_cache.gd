class_name SemanticCache
extends Node

## Локальный семантический кэш проверенных модулей и алгоритмы поиска для UniCORE

signal cache_updated(module_id: String, action: String)

const DEFAULT_CACHE_PATH: String = "user://semantic_cache.json"

var current_cache_path: String = DEFAULT_CACHE_PATH
var _cache: Dictionary = {}
var _token_regex: RegEx = null

func _ready() -> void:
	load_from_disk(current_cache_path)

func _get_regex() -> RegEx:
	if _token_regex == null:
		_token_regex = RegEx.new()
		_token_regex.compile("[^\\p{L}\\p{N}_]+")
	return _token_regex

## Расчет SHA-256 хеша через HashingContext (HASH_SHA256)
static func compute_sha256(source: String) -> String:
	var ctx := HashingContext.new()
	var err := ctx.start(HashingContext.HASH_SHA256)
	if err != OK:
		return ""
	var raw_bytes := source.to_utf8_buffer()
	if raw_bytes.size() > 0:
		err = ctx.update(raw_bytes)
		if err != OK:
			return ""
	var digest: PackedByteArray = ctx.finish()
	return digest.hex_encode().to_lower()

## Парсинг метаданных из комментариев в коде
static func parse_metadata_from_code(code: String) -> Dictionary:
	var meta: Dictionary = {
		"name": "",
		"description": "",
		"tags": []
	}
	var tags_list: Array[String] = []
	var lines := code.split("\n")
	
	for line_raw in lines:
		var line: String = line_raw.strip_edges()
		if line.is_empty():
			continue
		
		if line.begins_with("#"):
			var content: String = line.trim_prefix("##").trim_prefix("#").strip_edges()
			var lower_content: String = content.to_lower()
			
			if lower_content.begins_with("name:"):
				meta["name"] = content.substr(5).strip_edges()
			elif lower_content.begins_with("description:"):
				meta["description"] = content.substr(12).strip_edges()
			elif lower_content.begins_with("tags:"):
				var raw_tags: String = content.substr(5).strip_edges()
				raw_tags = raw_tags.trim_prefix("[").trim_suffix("]").strip_edges()
				var split_char: String = "," if raw_tags.contains(",") else " "
				var parts: PackedStringArray = raw_tags.split(split_char, false)
				for part in parts:
					var clean_tag: String = part.strip_edges().trim_prefix("\"").trim_suffix("\"").trim_prefix("'").trim_suffix("'").to_lower()
					if not clean_tag.is_empty() and not clean_tag in tags_list:
						tags_list.append(clean_tag)
	
	meta["tags"] = tags_list
	return meta

## Извлечение очищенных ключевых слов из текста
func _extract_keywords(text: String) -> Array[String]:
	var result: Array[String] = []
	if text.strip_edges().is_empty():
		return result
	
	var lower_text: String = text.to_lower()
	var regex: RegEx = _get_regex()
	var cleaned_text: String = regex.sub(lower_text, " ", true)
	
	var raw_tokens_packed: PackedStringArray = cleaned_text.split(" ", false)
	var raw_tokens: Array[String] = []
	for t in raw_tokens_packed:
		raw_tokens.append(t)
	
	var filtered: Array[String] = Stopwords.clean_tokens(raw_tokens)
	
	var seen: Dictionary = {}
	for token in filtered:
		if not seen.has(token):
			seen[token] = true
			result.append(token)
			
	return result

## Вычисление n-граммной похожести строк (Dice coefficient) с fallback
func _ngram_similarity(a: String, b: String, n: int = 3) -> float:
	var s1: String = a.strip_edges().to_lower()
	var s2: String = b.strip_edges().to_lower()
	if s1.is_empty() and s2.is_empty():
		return 1.0
	if s1.is_empty() or s2.is_empty():
		return 0.0
	if s1 == s2:
		return 1.0
	
	var len1: int = s1.length()
	var len2: int = s2.length()
	
	if len1 < n or len2 < n:
		if s1.contains(s2) or s2.contains(s1):
			return float(mini(len1, len2)) / float(maxi(len1, len2))
		var chars_a: Dictionary = {}
		for i in range(len1):
			var ch: String = s1.substr(i, 1)
			chars_a[ch] = chars_a.get(ch, 0) + 1
		var chars_b: Dictionary = {}
		for i in range(len2):
			var ch: String = s2.substr(i, 1)
			chars_b[ch] = chars_b.get(ch, 0) + 1
		var common: int = 0
		for ch in chars_a:
			if chars_b.has(ch):
				common += mini(int(chars_a[ch]), int(chars_b[ch]))
		return (2.0 * float(common)) / float(len1 + len2)
	
	var total_a: int = len1 - n + 1
	var grams_a: Dictionary = {}
	for i in range(total_a):
		var gram: String = s1.substr(i, n)
		grams_a[gram] = grams_a.get(gram, 0) + 1
		
	var total_b: int = len2 - n + 1
	var grams_b: Dictionary = {}
	for i in range(total_b):
		var gram: String = s2.substr(i, n)
		grams_b[gram] = grams_b.get(gram, 0) + 1
		
	var intersection: int = 0
	for gram in grams_a:
		if grams_b.has(gram):
			intersection += mini(int(grams_a[gram]), int(grams_b[gram]))
			
	var overlap: float = (2.0 * float(intersection)) / float(total_a + total_b)
	if s1.contains(s2) or s2.contains(s1):
		var sub_ratio: float = float(mini(len1, len2)) / float(maxi(len1, len2))
		overlap = maxf(overlap, sub_ratio)
	return clampf(overlap, 0.0, 1.0)

## Расчет совокупной релевантности записи запросу
func _calculate_relevance(query_tokens: Array[String], query_raw: String, entry: Dictionary) -> float:
	var q_clean: String = query_raw.strip_edges().to_lower()
	
	# 1. 0.4 * keyword match ratio
	var entry_kws: Array = entry.get("keywords", [])
	var keyword_ratio: float = 0.0
	if not query_tokens.is_empty():
		var kw_matches: float = 0.0
		for qt in query_tokens:
			if qt in entry_kws:
				kw_matches += 1.0
			else:
				for kw in entry_kws:
					var kws := str(kw)
					if kws.contains(qt) or qt.contains(kws):
						kw_matches += 0.5
						break
		keyword_ratio = minf(1.0, kw_matches / float(query_tokens.size()))
	elif not q_clean.is_empty() and q_clean in entry_kws:
		keyword_ratio = 1.0
	
	# 2. 0.3 * tag match ratio
	var entry_tags: Array = entry.get("tags", [])
	var tag_ratio: float = 0.0
	if not entry_tags.is_empty():
		if q_clean in entry_tags:
			tag_ratio = 1.0
		elif not query_tokens.is_empty():
			var tag_matches: float = 0.0
			for qt in query_tokens:
				var found := false
				for t in entry_tags:
					var ts := str(t).to_lower()
					if ts == qt:
						tag_matches += 1.0
						found = true
						break
					elif ts.contains(qt) or qt.contains(ts):
						tag_matches += 0.5
						found = true
						break
			tag_ratio = minf(1.0, tag_matches / float(query_tokens.size()))
	
	# 3. 0.2 * n-gram / substring similarity описания и названия с query
	var name_sim: float = _ngram_similarity(q_clean, str(entry.get("name", "")).to_lower(), 3)
	var desc_sim: float = _ngram_similarity(q_clean, str(entry.get("description", "")).to_lower(), 3)
	var name_lower: String = str(entry.get("name", "")).to_lower()
	var desc_lower: String = str(entry.get("description", "")).to_lower()
	if not q_clean.is_empty() and name_lower.contains(q_clean):
		name_sim = maxf(name_sim, 0.8)
	if not q_clean.is_empty() and desc_lower.contains(q_clean):
		desc_sim = maxf(desc_sim, 0.7)
	var text_sim: float = clampf(maxf(name_sim, desc_sim), 0.0, 1.0)
	
	# 4. 0.1 * reputation (0.0 .. 1.0)
	var rep: float = clampf(float(entry.get("reputation", 0.0)), 0.0, 1.0)
	
	var score: float = (0.4 * keyword_ratio) + (0.3 * tag_ratio) + (0.2 * text_sim) + (0.1 * rep)
	return clampf(score, 0.0, 1.0)

## Добавление или обновление модуля в кэше
func add_module(module_data: Dictionary) -> bool:
	if module_data.is_empty():
		return false
	
	var mod_id: String = str(module_data.get("id", "")).strip_edges()
	var source_code: String = str(module_data.get("source_code", ""))
	
	var code_meta: Dictionary = parse_metadata_from_code(source_code)
	
	if mod_id.is_empty():
		if not str(code_meta.get("name", "")).is_empty():
			mod_id = str(code_meta["name"]).to_lower().replace(" ", "_")
		else:
			return false
	
	var mod_name: String = str(module_data.get("name", "")).strip_edges()
	if mod_name.is_empty():
		mod_name = str(code_meta.get("name", "")).strip_edges()
	if mod_name.is_empty():
		mod_name = mod_id
	
	var description: String = str(module_data.get("description", "")).strip_edges()
	if description.is_empty():
		description = str(code_meta.get("description", "")).strip_edges()
	
	var tags_list: Array[String] = []
	var raw_tags = module_data.get("tags", [])
	if typeof(raw_tags) == TYPE_ARRAY:
		for t in raw_tags:
			var tag_str: String = str(t).strip_edges().to_lower()
			if not tag_str.is_empty() and not tag_str in tags_list:
				tags_list.append(tag_str)
	elif typeof(raw_tags) == TYPE_STRING:
		var split_char: String = "," if str(raw_tags).contains(",") else " "
		for t in str(raw_tags).split(split_char, false):
			var tag_str: String = t.strip_edges().to_lower()
			if not tag_str.is_empty() and not tag_str in tags_list:
				tags_list.append(tag_str)
	
	for t in code_meta.get("tags", []):
		var tag_str: String = str(t).strip_edges().to_lower()
		if not tag_str.is_empty() and not tag_str in tags_list:
			tags_list.append(tag_str)
	
	var source_hash: String = str(module_data.get("source_hash", "")).strip_edges().to_lower()
	if source_hash.is_empty() and not source_code.is_empty():
		source_hash = compute_sha256(source_code)
	
	var author_node: String = str(module_data.get("author_node", ""))
	
	var usage_count: int = 0
	var reputation: float = 0.5
	var created_at: float = Time.get_unix_time_from_system()
	
	if _cache.has(mod_id):
		var existing: Dictionary = _cache[mod_id]
		usage_count = int(module_data.get("usage_count", existing.get("usage_count", 0)))
		reputation = float(module_data.get("reputation", existing.get("reputation", 0.5)))
		created_at = float(module_data.get("created_at", existing.get("created_at", created_at)))
	else:
		usage_count = int(module_data.get("usage_count", 0))
		reputation = float(module_data.get("reputation", 0.5))
		created_at = float(module_data.get("created_at", created_at))
	
	reputation = clampf(reputation, 0.0, 1.0)
	var verified: bool = bool(module_data.get("verified", false))
	
	var keywords_set: Dictionary = {}
	for kw in _extract_keywords(mod_name):
		keywords_set[kw] = true
	for kw in _extract_keywords(description):
		keywords_set[kw] = true
	for tag in tags_list:
		for kw in _extract_keywords(tag):
			keywords_set[kw] = true
	
	var comments_text: String = ""
	for line in source_code.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("#"):
			comments_text += trimmed.trim_prefix("#").strip_edges() + " "
	if not comments_text.is_empty():
		for kw in _extract_keywords(comments_text):
			keywords_set[kw] = true
			
	var extra_kw = module_data.get("keywords", [])
	if typeof(extra_kw) == TYPE_ARRAY:
		for ek in extra_kw:
			for kw in _extract_keywords(str(ek)):
				keywords_set[kw] = true
	
	var final_keywords: Array[String] = []
	for k in keywords_set:
		final_keywords.append(str(k))
	
	var entry: Dictionary = {
		"id": mod_id,
		"name": mod_name,
		"description": description,
		"tags": tags_list,
		"source_hash": source_hash,
		"source_code": source_code,
		"author_node": author_node,
		"usage_count": usage_count,
		"reputation": reputation,
		"verified": verified,
		"created_at": created_at,
		"keywords": final_keywords
	}
	
	_cache[mod_id] = entry
	save_to_disk(current_cache_path)
	cache_updated.emit(mod_id, "added")
	return true

## Удаление модуля из кэша
func remove_module(module_id: String) -> bool:
	if not _cache.has(module_id):
		return false
	_cache.erase(module_id)
	save_to_disk(current_cache_path)
	cache_updated.emit(module_id, "removed")
	return true

## Ранжированный семантический поиск модулей
func search(query: String, max_results: int = 5, min_score: float = 0.2) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var query_raw: String = query.strip_edges()
	if query_raw.is_empty():
		return results
	
	var query_tokens: Array[String] = _extract_keywords(query_raw)
	
	for mod_id in _cache:
		var entry: Dictionary = _cache[mod_id]
		var score: float = _calculate_relevance(query_tokens, query_raw, entry)
		if score >= min_score:
			results.append({
				"module_data": entry.duplicate(true),
				"score": score,
				"id": entry["id"],
				"name": entry["name"],
				"description": entry["description"],
				"source_code": entry["source_code"],
				"source_hash": entry["source_hash"]
			})
	
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"])
	)
	
	if results.size() > max_results:
		results.resize(max_results)
	
	return results

## Получение модуля по ID
func get_by_id(module_id: String) -> Dictionary:
	if _cache.has(module_id):
		return _cache[module_id].duplicate(true)
	return {}

## Получение модуля по source_hash
func get_by_hash(hash: String) -> Dictionary:
	var clean_hash: String = hash.strip_edges().to_lower()
	if clean_hash.is_empty():
		return {}
	for mod_id in _cache:
		var entry: Dictionary = _cache[mod_id]
		if str(entry.get("source_hash", "")).to_lower() == clean_hash:
			return entry.duplicate(true)
	return {}

## Получение всех проверенных модулей
func get_all_verified() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mod_id in _cache:
		var entry: Dictionary = _cache[mod_id]
		if bool(entry.get("verified", false)):
			result.append(entry.duplicate(true))
	return result

## Получение всех модулей кэша
func get_all_modules() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mod_id in _cache:
		result.append(_cache[mod_id].duplicate(true))
	return result

## Общее количество модулей
func get_total_modules_count() -> int:
	return _cache.size()

## Список уникальных тегов во всех модулях
func get_unique_tags() -> Array[String]:
	var tags_map: Dictionary = {}
	for mod_id in _cache:
		var entry: Dictionary = _cache[mod_id]
		var tags: Array = entry.get("tags", [])
		for t in tags:
			var tag_str: String = str(t).strip_edges().to_lower()
			if not tag_str.is_empty():
				tags_map[tag_str] = true
	var result: Array[String] = []
	for t in tags_map:
		result.append(str(t))
	result.sort()
	return result

## Список популярных модулей (по usage_count и reputation)
func get_popular_modules(limit: int = 10) -> Array[Dictionary]:
	var all_mods: Array[Dictionary] = get_all_modules()
	all_mods.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var u_a: int = int(a.get("usage_count", 0))
		var u_b: int = int(b.get("usage_count", 0))
		if u_a != u_b:
			return u_a > u_b
		return float(a.get("reputation", 0.0)) > float(b.get("reputation", 0.0))
	)
	if all_mods.size() > limit:
		all_mods.resize(limit)
	return all_mods

## Увеличение счетчика использования модуля (+0.02 к reputation)
func increment_usage(module_id: String) -> void:
	if not _cache.has(module_id):
		return
	var entry: Dictionary = _cache[module_id]
	entry["usage_count"] = int(entry.get("usage_count", 0)) + 1
	var current_rep: float = float(entry.get("reputation", 0.5))
	entry["reputation"] = clampf(current_rep + 0.02, 0.0, 1.0)
	save_to_disk(current_cache_path)
	cache_updated.emit(module_id, "usage_incremented")

## Изменение репутации модуля
func update_reputation(module_id: String, delta: float) -> void:
	if not _cache.has(module_id):
		return
	var entry: Dictionary = _cache[module_id]
	var current_rep: float = float(entry.get("reputation", 0.5))
	entry["reputation"] = clampf(current_rep + delta, 0.0, 1.0)
	save_to_disk(current_cache_path)
	cache_updated.emit(module_id, "reputation_updated")

## Полная очистка кэша
func clear_cache() -> void:
	_cache.clear()
	save_to_disk(current_cache_path)
	cache_updated.emit("", "cleared")

## Сохранение кэша на диск
func save_to_disk(path: String = DEFAULT_CACHE_PATH) -> bool:
	var target_path: String = path
	if target_path == DEFAULT_CACHE_PATH and current_cache_path != DEFAULT_CACHE_PATH:
		target_path = current_cache_path
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if not file:
		var err := FileAccess.get_open_error()
		push_warning("SemanticCache: Failed to open file for write at '%s', error: %d" % [target_path, err])
		return false
	
	var serialized: Dictionary = {
		"version": 1,
		"modules": _cache
	}
	var json_str: String = JSON.stringify(serialized, "\t")
	file.store_string(json_str)
	file.close()
	return true

## Загрузка кэша с диска
func load_from_disk(path: String = DEFAULT_CACHE_PATH) -> bool:
	var target_path: String = path
	if target_path == DEFAULT_CACHE_PATH and current_cache_path != DEFAULT_CACHE_PATH:
		target_path = current_cache_path
	if not FileAccess.file_exists(target_path):
		return false
	var file := FileAccess.open(target_path, FileAccess.READ)
	if not file:
		return false
	var content: String = file.get_as_text()
	file.close()
	if content.strip_edges().is_empty():
		return false
	
	var json := JSON.new()
	var err := json.parse(content)
	if err != OK:
		push_warning("SemanticCache: Failed to parse JSON from '%s': %s" % [target_path, json.get_error_message()])
		return false
	
	var data: Variant = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return false
	
	var root: Dictionary = data
	if not root.has("modules") or typeof(root["modules"]) != TYPE_DICTIONARY:
		return false
	
	_cache.clear()
	var modules_dict: Dictionary = root["modules"]
	for mod_id in modules_dict:
		var raw_entry: Dictionary = modules_dict[mod_id]
		var entry_tags: Array[String] = []
		for t in raw_entry.get("tags", []):
			entry_tags.append(str(t))
		var entry_kws: Array[String] = []
		for kw in raw_entry.get("keywords", []):
			entry_kws.append(str(kw))
		
		_cache[str(mod_id)] = {
			"id": str(raw_entry.get("id", mod_id)),
			"name": str(raw_entry.get("name", "")),
			"description": str(raw_entry.get("description", "")),
			"tags": entry_tags,
			"source_hash": str(raw_entry.get("source_hash", "")),
			"source_code": str(raw_entry.get("source_code", "")),
			"author_node": str(raw_entry.get("author_node", "")),
			"usage_count": int(raw_entry.get("usage_count", 0)),
			"reputation": float(raw_entry.get("reputation", 0.5)),
			"verified": bool(raw_entry.get("verified", false)),
			"created_at": float(raw_entry.get("created_at", 0.0)),
			"keywords": entry_kws
		}
	return true
