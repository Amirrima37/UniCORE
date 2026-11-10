class_name Stopwords
extends RefCounted

## Коллекция стоп-слов и методы очистки токенов для семантического анализа в UniCORE

const RU: Array[String] = [
	"и", "в", "во", "на", "с", "со", "по", "для", "от", "из", "к", "ко", "у", "о", "об", "за",
	"не", "что", "это", "как", "так", "все", "но", "да", "уже", "или", "мне", "мой", "мы", "вы",
	"он", "она", "они", "быть", "был", "была", "было", "были", "есть", "до", "при", "бы", "ли", "же"
]

const EN: Array[String] = [
	"the", "a", "an", "is", "are", "was", "were", "in", "on", "at", "to", "for", "of", "with",
	"and", "or", "not", "this", "that", "it", "its", "from", "by", "as", "be", "have", "has",
	"had", "do", "does", "did", "but", "if", "so", "can", "will", "my", "your", "we", "they"
]

## Проверка слова в нижнем регистре на принадлежность к стоп-словам
static func is_stopword(word: String) -> bool:
	var w: String = word.strip_edges().to_lower()
	return w in RU or w in EN

## Фильтрация стоп-слов и коротких токенов (длина < 2)
static func clean_tokens(tokens: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for token in tokens:
		var cleaned: String = token.strip_edges().to_lower()
		if cleaned.length() >= 2 and not is_stopword(cleaned):
			result.append(cleaned)
	return result
