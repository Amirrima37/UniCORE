# UniCORE Roadmap & Status Tracker

## Текущий статус: Фаза 1, Фаза 2, Фаза 2.5a и Фаза 2.5b — «Интерактивное Ядро, Оболочка Detroit, Контекстная Память, Self-Repair и Библиотека Модулей» (100% готовности)

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
  - [x] [main_menu.gd](file:///c:/dev/UniCORE/ui/menu/main_menu.gd) / [main_menu.tscn](file:///c:/dev/UniCORE/ui/menu/main_menu.tscn) — модальное системное меню по `Esc`: вкладки «Пространства», «Настройки», «Библиотека», «Модули», «О системе / Управление», диалог выхода.
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

### Следующие задачи (Фаза 3 — «P2P Сеть, Кэш и Распределенный Рой»):
- [ ] **P2P Семантический кэш модулей:** Локальное кэширование и распределенная база проверенных модулей без необходимости вызова внешних LLM API.
- [ ] **P2P Swarm & Multiplayer:** Синхронизация состояний Пространств между узлами сети и совместное редактирование.
- [ ] **Поддержка VR (OpenXR):** Ноды ввода и адаптация Detroit UI для VR-шлемов.
