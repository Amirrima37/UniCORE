# UniCORE Roadmap & Status Tracker

## Текущий статус: Фаза 1, Фаза 2, Фаза 2.5 (a,b,c) и Фаза 3a — «Интерактивное Ядро, Оболочка Detroit, Контекстная Память, Self-Repair, Библиотека Модулей, Сетевой Слой и P2P Семантический Кэш Модулей» (100% готовности)

### Выполнено в Фазе 1 («Интерактивное Ядро и Агент»):
- [x] **Архитектурный манифест:** зафиксирован в [ARCHITECTURE.md](file:///c:/dev/UniCORE/ARCHITECTURE.md).
- [x] **Стерильное Ядро (Godot 4):**
  - [x] [event_bus.gd](file:///c:/dev/UniCORE/core/event_bus.gd) — шина сообщений и событий.
  - [x] [base_module.gd](file:///c:/dev/UniCORE/core/base_module.gd) — базовый контракт жизненного цикла модуля (`initialize`, `cleanup`, `get_module_id`).
  - [x] [module_manager.gd](file:///c:/dev/UniCORE/core/module_manager.gd) — динамическая компиляция и инъекция модулей в рантайме.
  - [x] [space_viewport.gd](file:///c:/dev/UniCORE/core/space_viewport.gd) / [space_viewport.tscn](file:///c:/dev/UniCORE/core/space_viewport.tscn) — главная сцена чистого Пространства.
- [x] **Предустановленные Модули (`modules/builtin/`):**
  - [x] [ground_plane.gd](file:///c:/dev/UniCORE/modules/builtin/ground_plane.gd) — нулевая плоскость мира.
  - [x] [avatar_locomotion.gd](file:///c:/dev/UniCORE/modules/builtin/avatar_locomotion.gd) — камера 1-го лица, обзор мышью, WASD и свободный полет (Space/Ctrl/Shift), поддержка инверсии оси Y и динамических настроек чувствительности.
- [x] **Подсистема Агента (`agent/`):**
  - [x] [gemini_provider.gd](file:///c:/dev/UniCORE/agent/providers/gemini_provider.gd) — HTTP-клиент к Google Gemini REST API.
  - [x] [openai_compatible_provider.gd](file:///c:/dev/UniCORE/agent/providers/openai_compatible_provider.gd) — поддержка OpenRouter, OpenAI, DeepSeek.
  - [x] [code_validator.gd](file:///c:/dev/UniCORE/agent/code_validator.gd) — статический анализатор безопасности и песочница для GDScript (43/43 тестов в [test_validator_suite.gd](file:///c:/dev/UniCORE/test_validator_suite.gd)).
  - [x] [agent_brain.gd](file:///c:/dev/UniCORE/agent/agent_brain.gd) — оркестратор запросов, связывающий UI, API и Ядро.
- [x] **Визуальный LED Orb Агента:**
  - [x] [detroit_orb.gd](file:///c:/dev/UniCORE/ui/led_indicator/detroit_orb.gd) / [detroit_orb.tscn](file:///c:/dev/UniCORE/ui/led_indicator/detroit_orb.tscn) — процедурный круговой светодиодный индикатор состояний в стиле "Detroit: Become Human" (Idle Синий, Processing Янтарный, Success Изумрудный, Error Красный).

---

### Выполнено в Фазе 2 («Оболочка Приложения, Настройки и Пространства»):
- [x] **Стилистика "Detroit: Become Human":**
  - [x] [cyber_theme.gd](file:///c:/dev/UniCORE/ui/theme/cyber_theme.gd) — полупрозрачные панели из матового стекла (frosted glass), неоновая окантовка, LED-акценты, кастомные StyleBoxFlat и глобальный генератор тем.
  - [x] [icon.svg](file:///c:/dev/UniCORE/icon.svg) — высокотехнологичная векторная иконка приложения в стиле Detroit: Become Human.
- [x] **Глобальная система Настроек (SettingsManager):**
  - [x] [settings_manager.gd](file:///c:/dev/UniCORE/core/settings_manager.gd) — сохранение в `user://settings.json`, пресеты разрешений (1280x720, 1600x900, 1920x1080, 2560x1440), VSync, лимиты FPS, чувствительность мыши, инверсия Y, скорость полета, мастер-громкость звука, конфигурация LLM.
  - [x] Полноэкранный режим с горячей клавишей `F11` в рантайме.
- [x] **Сериализация и Менеджер Пространств (SpaceManager):**
  - [x] [space_manager.gd](file:///c:/dev/UniCORE/core/space_manager.gd) — сохранение и загрузка снимков мира в `user://spaces/*.json`.
  - [x] Создание новых Пространств с выбором шаблона (Default Studio, Cyber Void, Clean Slate, Tool Playground).
  - [x] Быстрое сохранение, Сохранить как, удаление пространств, переключение на лету.
  - [x] Сохранение положения камеры, активных модулей и параметров.
- [x] **Интерфейс Оболочки Приложения (App Shell UI):**
  - [x] [top_bar.gd](file:///c:/dev/UniCORE/ui/hud/top_bar.gd) / [top_bar.tscn](file:///c:/dev/UniCORE/ui/hud/top_bar.tscn) — верхний кибер-HUD: Detroit LED-орб, бейдж текущего пространства, тикер статуса Агента, счетчик FPS, кнопки быстрого доступа (Меню, Пространства, Настройки, Команды, Экран).
  - [x] [main_menu.gd](file:///c:/dev/UniCORE/ui/menu/main_menu.gd) / [main_menu.tscn](file:///c:/dev/UniCORE/ui/menu/main_menu.tscn) — модальное системное меню по `Esc`: вкладки «Пространства», «Настройки», «Библиотека», «Модули», «Сеть», «О системе / Управление», диалог выхода.
  - [x] [prompt_bar.gd](file:///c:/dev/UniCORE/ui/prompt_bar/prompt_bar.gd) — обновленная строка команд с Detroit-стилем, StatusToast с `AUTOWRAP_WORD_SMART` и синхронизацией фокуса мыши.
  - [x] [analysis_drawer.gd](file:///c:/dev/UniCORE/ui/analysis_drawer/analysis_drawer.gd) — панель диагностики CyberLife и просмотр исходного кода по `F10`.
  - [x] [module_toolbar.gd](file:///c:/dev/UniCORE/ui/module_toolbar/module_toolbar.gd) — нижняя панель активных модулей с LED-переключателями.
- [x] **Автоматизированное Тестирование (91/91 проверок) и Реестр Модулей:**
  - [x] [test_app_shell_suite.gd](file:///c:/dev/UniCORE/test_app_shell_suite.gd) — полное тестирование темы, LED-орба, менеджера настроек, менеджера пространств, инстанциации UI и сцены ядра (91 тест пройден, 0 ошибок).

---

### Выполнено в Фазе 2.5a («Мульти-ходовый Агент с Контекстной Памятью и Self-Repair»):
- [x] **Контекстная Память Диалога (ConversationMemory):**
  - [x] [conversation_memory.gd](file:///c:/dev/UniCORE/agent/conversation_memory.gd) — хранение истории диалога, ответов ассистента, контекста ошибок компиляции, авто-суммаризация, персистентность в `user://conversation_history.json` и динамическое обогащение `SYSTEM_PROMPT` контекстом активных модулей Ядра.
- [x] **Автономный Цикл Самоисправления (Self-Repair Loop):**
  - [x] [agent_brain.gd](file:///c:/dev/UniCORE/agent/agent_brain.gd) — перехват ошибок синтаксиса GDScript (`CodeValidator`) и компиляции/инъекции (`ModuleManager`), отправка исправляющего запроса с исходным ошибочным кодом и описанием ошибки (до `MAX_REPAIR_ATTEMPTS = 3`).
  - [x] Диагностическое логирование попыток восстановления (`DiagnosticLogger.log_agent("WARN", ...)`).
- [x] **Режим Редактирования Модулей (Module Edit Mode & Hot Reload):**
  - [x] Распознавание команд редактирования на русском и английском языках через регулярные выражения.
  - [x] Поиск целевого активного модуля по ID или отображаемому имени.
  - [x] Извлечение текущего исходного кода (кэш, скрипт, диск) и передача его LLM с инструкцией пользователя.
  - [x] Бесшовная горячая замена (Hot Swap) модуля в `ModuleManager` на лету (`unload_module` -> `load_module_from_source`).
- [x] **Комплексное Автоматизированное Тестирование (78/78 проверок):**
  - [x] [test_self_repair_suite.gd](file:///c:/dev/UniCORE/tests/test_self_repair_suite.gd) — полное модульное и интеграционное тестирование ConversationMemory, цикла Self-Repair при синтаксических ошибках, завершения по превышению MAX_REPAIR_ATTEMPTS, RegEx распознавания, точного извлечения ID и горячей замены модулей (78 проверок пройдено, 0 ошибок).

---

### Выполнено в Фазе 2.5b («Файловый Менеджер и Галерея Модулей»):
- [x] **Бэкенд Библиотеки Модулей (ModuleLibrary):**
  - [x] [module_library.gd](file:///c:/dev/UniCORE/core/module_library.gd) — автоматическое сканирование `res://modules/` и `res://modules/builtin/`, извлечение метаданных, каталогизация шаблонов из `ModuleRegistryClient`.
  - [x] Защита встроенных модулей (запрет удаления и переименования).
  - [x] Операции с файлами: удаление, переименование с обновлением `get_module_id()`, дублирование, экспорт.
  - [x] Безопасный импорт внешних `.gd` файлов со статической верификацией через `CodeValidator` (блокировка `OS.execute` и системных вызовов).
- [x] **Визуальная Галерея Модулей (ModuleGallery):**
  - [x] [module_gallery.gd](file:///c:/dev/UniCORE/ui/module_gallery/module_gallery.gd) / [module_gallery.tscn](file:///c:/dev/UniCORE/ui/module_gallery/module_gallery.tscn) — сетка карточек модулей (`GridContainer`), Detroit Liquid Glass стиль, LED-индикаторы категорий.
  - [x] Поиск по названию/тегам, фильтрация по категориям, сортировка, контекстные диалоги.
  - [x] Вкладка «Библиотека» в [main_menu.gd](file:///c:/dev/UniCORE/ui/menu/main_menu.gd) и быстрый доступ по клавише `F9`.
- [x] **Интеграция в Ядро и Тестирование (67/67 проверок):**
  - [x] Связывание в [space_viewport.gd](file:///c:/dev/UniCORE/core/space_viewport.gd) с `AnalysisDrawer` для просмотра исходного кода (`view_code_requested`).
  - [x] [test_module_library_suite.gd](file:///c:/dev/UniCORE/tests/test_module_library_suite.gd) — 67 тестов пройдено со 100% успехом (0 ошибок).

---

### Выполнено в Фазе 2.5c («Сетевой Слой, LAN Discovery и P2P Обмен Модулями»):
- [x] **Абстрактный Сетевой Транспорт (NetworkTransport):**
  - [x] [network_transport.gd](file:///c:/dev/UniCORE/core/net/network_transport.gd) — кросс-платформенный транспорт на базе ENetMultiplayerPeer с поддержкой каналов (`module_share`, `space_sync`, `chat`, `discovery`, `heartbeat`), RTT-латенси, авто-дисконнекта по таймауту и безопасной сериализацией Dictionary/Vector3/примитивов.
- [x] **Автоматическое Обнаружение в Локальной Сети (LANDiscovery):**
  - [x] [lan_discovery.gd](file:///c:/dev/UniCORE/core/net/lan_discovery.gd) — широковещательный UDP-клиент (порт 7778), динамическое оповещение о доступных нодах, метаданные (имя узла, порт, количество модулей), обработка таймаутов и обнаружение потери нод (`peer_lost`).
- [x] **Протокол P2P Обмена Модулями (ModuleSharing):**
  - [x] [module_sharing.gd](file:///c:/dev/UniCORE/core/net/module_sharing.gd) — надежный протокол предложения, запроса и передачи модулей (`offer -> accept/reject -> request -> data -> verify`).
  - [x] Защита целостности: проверка криптографического хэша SHA-256.
  - [x] Защита безопасности: жесткий лимит размера пакета (64 KB) и валидация через статический анализатор `CodeValidator` перед инъекцией.
  - [x] Контроль доступа: белые и черные списки сетевых пиров (Whitelist/Blacklist).
- [x] **Синхронизация Пространств (SpaceSync):**
  - [x] [space_sync.gd](file:///c:/dev/UniCORE/core/net/space_sync.gd) — передача и применение снимков Пространств (`SpaceManager`), широковещательная репликация изменений состояний модулей (`module_state_change`).
- [x] **Интеграция с Настройками и Сетевой UI (Network UI & HUD):**
  - [x] [settings_manager.gd](file:///c:/dev/UniCORE/core/settings_manager.gd) — секция настроек `"network"` (`auto_discovery`, `share_modules`, `host_port: 7777`, `discovery_port: 7778`, `player_name`, `max_module_size_kb: 64`).
  - [x] [top_bar.gd](file:///c:/dev/UniCORE/ui/hud/top_bar.gd) / [top_bar.tscn](file:///c:/dev/UniCORE/ui/hud/top_bar.tscn) — сетевой LED-индикатор с цветовой кодировкой состояний (серый/дисконнект, кибер-голубой/хостинг, изумрудный/подключен, янтарный/синхронизация) и вызовом вкладки сети.
  - [x] [main_menu.gd](file:///c:/dev/UniCORE/ui/menu/main_menu.gd) / [main_menu.tscn](file:///c:/dev/UniCORE/ui/menu/main_menu.tscn) — вкладка «Сеть» (индекс 4): управление сессией (Host / Join / Disconnect), список обнаруженных LAN-нод с кнопками подключения, список активных пиров, панель предложений модулей с кнопками Принять/Отклонить.
  - [x] [space_viewport.gd](file:///c:/dev/UniCORE/core/space_viewport.gd) — автоматическая сборка и проводка сетевых подсистем в главном окне.
- [x] **Комплексное Автоматизированное Тестирование (99/99 проверок):**
  - [x] [test_network_layer_suite.gd](file:///c:/dev/UniCORE/tests/test_network_layer_suite.gd) — сквозное модульное и интеграционное тестирование транспорта, UDP discovery, SHA-256 хэширования, песочницы CodeValidator, защиты от превышения 64KB, синхронизации пространств, настроек SettingsManager и всех UI-элементов TopBar и MainMenu NetworkTab (99/99 проверок пройдено, 0 ошибок).

---

### Выполнено в Фазе 3a («Децентрализованный Семантический Кэш Модулей»):
- [x] **Локальный Движок Семантического Кэша (SemanticCache & Stopwords):**
  - [x] [stopwords.gd](file:///c:/dev/UniCORE/core/stopwords.gd) — поддержка русского (43 слова) и английского (38 слов) словарей стоп-слов, очистка токенов (`clean_tokens`), отсечение служебных символов и коротких слов.
  - [x] [semantic_cache.gd](file:///c:/dev/UniCORE/core/semantic_cache.gd) — локальный семантический индекс модулей без внешних ML-зависимостей:
    - [x] Алгоритм fuzzy n-gram сходства Серенсена — Дайса с устойчивостью к опечаткам и падежным окончаниям.
    - [x] Взвешенное ранжирование (40% совпадение ключевых слов + 30% совпадение тегов + 20% n-gram similarity описания/имени + 10% динамическая репутация).
    - [x] Автоматическое извлечение метаданных из комментариев кода (`## Name:`, `## Description:`, `## Tags:`).
    - [x] Вычисление криптографического хэша SHA-256 через `HashingContext.HASH_SHA256`.
    - [x] Персистентность индекса в `user://semantic_cache.json` с автосохранением и автозагрузкой.
    - [x] Репутационная система: автоматический инкремент счетчика использования (`usage_count`) и репутации (`+0.02`).
  - [x] [test_semantic_cache_unit.gd](file:///c:/dev/UniCORE/tests/test_semantic_cache_unit.gd) — 123/123 проверок пройдено со 100% успехом (exit code 0).
- [x] **P2P Распределение Кэша (CacheSync) и Каскадный Агент (AgentBrain Cascade):**
  - [x] [cache_sync.gd](file:///c:/dev/UniCORE/core/net/cache_sync.gd) — сетевой протокол поиска и обмена кэшем поверх канала `"cache_sync"` (`cache_query`, `cache_results`, `cache_announce`), дедупликация по SHA-256 хэшу, таймауты запросов.
  - [x] [network_transport.gd](file:///c:/dev/UniCORE/core/net/network_transport.gd) — регистрация канала `"cache_sync"` в `SUPPORTED_CHANNELS`.
  - [x] [agent_brain.gd](file:///c:/dev/UniCORE/agent/agent_brain.gd) — реализация 4-шагового каскада поиска:
    1. Шаблоны реестра (`ModuleRegistryClient`) с порогом `0.75`.
    2. Локальный семантический кэш (`SemanticCache.search`) — исполнение за 1–5 мс без обращения к сети.
    3. P2P Сетевой поиск (`CacheSync.query_network`) у соседних узлов UniCORE.
    4. Fallback на вызов LLM API с автоматической индексацией сгенерированного модуля в `SemanticCache`.
  - [x] Сигнал `module_resolved(module_id, source_type, duration)` и обновление `SYSTEM_PROMPT` с требованием метаданных в комментариях.
  - [x] [test_cache_sync_unit.gd](file:///c:/dev/UniCORE/tests/test_cache_sync_unit.gd) — 75/75 проверок пройдено со 100% успехом (exit code 0).
- [x] **Пользовательский Интерфейс и Индикация Источников:**
  - [x] [prompt_bar.gd](file:///c:/dev/UniCORE/ui/prompt_bar/prompt_bar.gd) — цветовая LED-кодировка источника в StatusToast:
    - `cache`: Неоновый Cyan (`#00E5FF`) «[КЭШ] Модуль найден в локальном кэше (2ms)»
    - `p2p`: Изумрудный Green (`#00E673`) «[P2P] Модуль получен из P2P сети (45ms)»
    - `registry`: Электрический Blue (`#1A99FF`) «[РЕЕСТР] Загружен базовый шаблон (1ms)»
    - `llm`: Янтарный Amber (`#FFB300`) «[LLM] Модуль сгенерирован ИИ (1420ms)»
  - [x] [main_menu.gd](file:///c:/dev/UniCORE/ui/menu/main_menu.gd) — секция семантического кэша во вкладке «Сеть»:
    - Отображение числа кэшированных модулей, уникальных тегов и последнего источника разрешения.
    - Интерактивный список топ-10 популярных модулей с тегами и счетчиками использования.
    - Кнопка очистки кэша с модальным подтверждением.
  - [x] [space_viewport.gd](file:///c:/dev/UniCORE/core/space_viewport.gd) — монтирование `SemanticCache` и `CacheSync`, проброс в `agent_brain`, `main_menu` и `prompt_bar`.
  - [x] [test_semantic_cache_suite.gd](file:///c:/dev/UniCORE/tests/test_semantic_cache_suite.gd) — 60/60 проверок пройдено со 100% успехом (exit code 0).
- [x] **Сквозная Регрессионная Проверка Всего Проекта:**
  - [x] 14 из 14 тестовых сьютов (`> 1,200 assertions`) завершены со статусом 100% PASS, 0 ошибок (exit code 0).

---

### Запланировано: Бэклог UX, Управления и Визуализации (UX & Control Polish):
*(Разделение зон: см. [ARCHITECTURE.md (Раздел 7)](file:///c:/dev/UniCORE/ARCHITECTURE.md#7-разграничение-зон-ответственности-corebackend-vs-uidesign-system))*
- [x] **1. Начальное меню (Boot & Welcome Screen)** `[Реализовано: Чат Дизайна]`:
  - [x] [boot_screen.gd](file:///c:/dev/UniCORE/ui/welcome_screen/boot_screen.gd) / [boot_screen.tscn](file:///c:/dev/UniCORE/ui/welcome_screen/boot_screen.tscn) — кинематографичный экран инициализации систем Genesis Schematic с прогресс-баром и телеметрией загрузки.
  - [x] [welcome_screen.gd](file:///c:/dev/UniCORE/ui/welcome_screen/welcome_screen.gd) / [welcome_screen.tscn](file:///c:/dev/UniCORE/ui/welcome_screen/welcome_screen.tscn) — полноценный стартовый титульный экран:
    - [x] Навигационный швейцарский стек: «Продолжить», «Пространства», «Модули», «Сеть», «Настройки», «Выход».
    - [x] Живой процедурный фон [ambient_graph_canvas.gd](file:///c:/dev/UniCORE/ui/menu/ambient_graph_canvas.gd) и шейдер сетки пустоты [grid_canvas.gdshader](file:///c:/dev/UniCORE/ui/shaders/grid_canvas.gdshader).
    - [x] Быстрый запуск приложения без длительной блокирующей загрузки мира.
  - [x] [test_welcome_and_boot_screen_suite.gd](file:///c:/dev/UniCORE/tests/test_welcome_and_boot_screen_suite.gd) — 26/26 проверок пройдено со 100% успехом (exit code 0).
- [x] **2. Интерактивный оверлей Сферы Агента (Fluid Detroit Orb Overlay)** `[Реализовано: Чат Дизайна]`:
  - [x] [fluid_orb_overlay.gd](file:///c:/dev/UniCORE/ui/agent_orb/fluid_orb_overlay.gd) / [fluid_orb_overlay.tscn](file:///c:/dev/UniCORE/ui/agent_orb/fluid_orb_overlay.tscn) — интерактивный оверлей и сингулярное светодиодное ядро Агента:
    - [x] Процедурные многослойные светодиодные кольца на базе шейдера [fluid_orb.gdshader](file:///c:/dev/UniCORE/ui/shaders/fluid_orb.gdshader) с реакцией на состояния (Idle, Listening, Thinking, Synthesizing, Success, Error).
    - [x] Реакция на мыслительную нагрузку (`agent_thought_intensity`) и амплитуду речи (`agent_speech_amplitude`).
    - [x] Переключение между DOCKED (мини) и EXPANDED (280x280) режимами по клику.
  - [x] [test_fluid_orb_suite.gd](file:///c:/dev/UniCORE/tests/test_fluid_orb_suite.gd) — 32/32 проверки пройдено со 100% успехом (exit code 0).
- [x] **3. Графический менеджер бинда клавиш (Input Mapper)**:
  - [x] [input_mapper.gd](file:///c:/dev/UniCORE/core/input_mapper.gd) — ядро управления и регистрации действий модулей:
    - [x] Динамическое обнаружение действий активных модулей через виртуальный метод `get_action_bindings()` в [base_module.gd](file:///c:/dev/UniCORE/core/base_module.gd).
    - [x] Автоматический парсинг директив `## Action: ...` и `Input.is_action_pressed()` из исходников модулей библиотеки.
    - [x] Детекция конфликтов клавиш и форматирование человекопонятных названий кнопок.
    - [x] Полная персистентность в [settings_manager.gd](file:///c:/dev/UniCORE/core/settings_manager.gd) (`user://settings.json`) и применение к Godot `InputMap`.
  - [x] Секция «Назначение клавиш управления (Input Mapper)» во вкладке «Настройки» в [main_menu.gd](file:///c:/dev/UniCORE/ui/menu/main_menu.gd):
    - [x] Группировка: «Активные модули (текущее пространство)», «Модули из библиотеки», «Системные горячие клавиши UniCORE».
    - [x] Интерактивное модальное окно перехвата клавиш (`KeyCaptureModal`) с предупреждением о конфликтах и отменой по `Esc`.
    - [x] Кнопки индивидуального сброса к дефолту `[ ↺ ]` и кнопка полного сброса всех биндов.
  - [x] Интеграция в [space_viewport.gd](file:///c:/dev/UniCORE/core/space_viewport.gd) с поддержкой кастомных биндов для системных действий (`toggle_fullscreen`, `toggle_module_gallery`, `toggle_analysis_drawer`, `toggle_menu`, `toggle_prompt_bar`).
  - [x] [test_input_mapper_suite.gd](file:///c:/dev/UniCORE/tests/test_input_mapper_suite.gd) — 57/57 тестов пройдено со 100% успехом (exit code 0).

---

### Следующие задачи (Фаза 3b — «P2P Swarm & Распределенные Вычисления»):
- [ ] **P2P Swarm & Multiplayer:** Синхронизация состояний Пространств между узлами сети и совместное редактирование в реальном времени.
- [ ] **Распределенный Рой Вычислений:** Балансировка задач синтеза и симуляции по мощности узлов сети.
- [ ] **Поддержка VR (OpenXR):** Ноды ввода и адаптация Detroit UI для VR-шлемов.
