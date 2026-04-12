# Техническое задание — AgentTeam
**Версия:** 1.0  
**Дата:** 10.04.2026  
**Продукт:** Внутренняя платформа управления AI-агентами  
**Заказчик:** CANNECT.AI  

---

## 1. Обзор продукта

AgentTeam — закрытая внутренняя платформа для управления командой AI-агентов (Оркестратор, Юрист, Контент-менеджер, SMM, Продажник). Команда общается в едином чате, агенты действуют автономно, все публичные действия проходят через Approval Gate с подтверждением от владельца.

**Платформы:**
- iOS-приложение (Flutter) — основной интерфейс команды
- Desktop Admin Panel (Flutter для macOS / веб) — расширенное управление, мониторинг, настройки агентов

**Бэкенд:** self-hosted, VPS/dedicated сервер (Ubuntu)

---

## 2. Роли пользователей

| Роль | Описание |
|---|---|
| Owner | Полный доступ, подтверждает Approval Gate, настраивает агентов |
| Admin | Доступ к чату и логам, не может менять системные промпты |
| Viewer | Только чтение чата и логов (опционально, для инвесторов) |

MVP: только роль Owner (один пользователь или команда из 2-3 человек).

---

## 3. Агенты системы

### 3.1 Оркестратор
**Назначение:** Центральный роутер. Читает каждое сообщение в треде, решает какого агента вызвать следующим, управляет очередью задач.

**Логика:**
- Анализирует входящее сообщение от пользователя или агента
- Определяет целевого агента по контексту и @тегам
- Если задача требует нескольких агентов — строит цепочку вызовов
- Отправляет задачи в Approval Queue если нужно подтверждение

**Инструменты:** нет внешних интеграций, только работа с тредом

---

### 3.2 Юрист
**Назначение:** Проверка текстов на юридические риски, генерация договоров, NDA, ответы на правовые вопросы.

**Инструменты:**
- RAG по загруженной базе документов (договоры, шаблоны, законодательство РК/РФ)
- Генерация PDF документов
- Поиск по веб (через OpenRouter с web_search tool)

**Approval:** всегда требует подтверждения перед отправкой документа клиенту

---

### 3.3 Контент-менеджер
**Назначение:** Создание контент-плана, написание скриптов, генерация изображений и видео.

**Инструменты:**
- OpenRouter LLM (написание текстов, скрипты)
- FAL.ai или Replicate API (генерация изображений — Flux, SDXL)
- RunwayML или Kling API (генерация видео)
- Google Drive API (сохранение готовых материалов)

**Approval:** перед финальной передачей материала SMM-агенту

---

### 3.4 SMM
**Назначение:** Публикация контента, мониторинг и ответы на комментарии, анализ трендов и конкурентов.

**Инструменты:**
- Instagram Graph API (посты, stories, reels, комментарии)
- TikTok Content Posting API (публикация видео)
- Threads API (публикация текстов)
- Playwright headless browser (мониторинг TikTok комментариев, анализ конкурентов)
- OpenRouter web_search (тренды)

**Approval:** перед каждой публикацией и перед ответом на комментарий

---

### 3.5 Продажник
**Назначение:** Обработка входящих лидов, ведение диалога, передача в CRM, закрытие сделок.

**Инструменты:**
- WhatsApp Business API через 360dialog (входящие/исходящие сообщения)
- Instagram DM через Graph API (только входящие)
- Notion API или собственная CRM-таблица (ведение лидов)
- OpenRouter LLM (генерация ответов)

**Approval:** перед отправкой КП или договора

---

## 4. Архитектура системы

```
┌─────────────────────────────────────────────────────┐
│                   Flutter iOS App                    │
│              Flutter Desktop Admin Panel             │
└──────────────────────┬──────────────────────────────┘
                       │ HTTPS + WebSocket
┌──────────────────────▼──────────────────────────────┐
│                  Backend (Node.js / Fastify)          │
│                                                       │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────┐ │
│  │ Chat API    │  │ Agent Runner │  │ Approval     │ │
│  │ REST+WS     │  │ LangGraph    │  │ Queue        │ │
│  └─────────────┘  └──────────────┘  └─────────────┘ │
│                                                       │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────┐ │
│  │ Webhook     │  │ Job Queue    │  │ File Storage │ │
│  │ Handler     │  │ BullMQ+Redis │  │ MinIO/S3     │ │
│  └─────────────┘  └──────────────┘  └─────────────┘ │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│                  PostgreSQL + Redis                   │
│         (треды, сообщения, задачи, агенты)           │
└─────────────────────────────────────────────────────┘
```

### Стек бэкенда
- **Runtime:** Node.js 20 LTS
- **Framework:** Fastify
- **Agent orchestration:** LangGraph.js
- **Queue:** BullMQ + Redis
- **Database:** PostgreSQL 16
- **Cache / Pub-Sub:** Redis 7
- **File storage:** MinIO (self-hosted S3-compatible)
- **WebSocket:** встроенный в Fastify (@fastify/websocket)
- **Auth:** JWT + refresh tokens

### Стек Flutter
- **State management:** Riverpod
- **Navigation:** go_router
- **HTTP:** Dio
- **WebSocket:** web_socket_channel
- **Local storage:** Hive (кэш сообщений)
- **Push notifications:** FCM (Firebase Cloud Messaging)
- **Media:** flutter_sound, video_player, image_picker

---

## 5. База данных — схема

```sql
-- Пользователи
users
  id uuid PK
  email text
  name text
  role text  -- owner | admin | viewer
  created_at timestamp

-- Треды (чаты)
threads
  id uuid PK
  title text
  created_at timestamp

-- Сообщения
messages
  id uuid PK
  thread_id uuid FK → threads
  sender_type text  -- user | agent
  sender_id text    -- user uuid или agent slug (orchestrator|lawyer|content|smm|sales)
  content text
  metadata jsonb    -- tool_calls, file_urls, etc
  created_at timestamp

-- Задачи в Approval Queue
approval_tasks
  id uuid PK
  agent_slug text
  action_type text  -- post_instagram | send_whatsapp | publish_tiktok | send_document | ...
  payload jsonb
  status text       -- pending | approved | rejected | modified
  requested_at timestamp
  resolved_at timestamp
  resolved_by uuid FK → users
  thread_id uuid FK → threads
  message_id uuid FK → messages

-- Конфигурация агентов
agent_configs
  id uuid PK
  slug text UNIQUE  -- orchestrator | lawyer | content | smm | sales
  system_prompt text
  model text        -- openrouter model string
  temperature float
  tools jsonb       -- список доступных инструментов
  is_active bool
  updated_at timestamp

-- Логи инструментов
tool_logs
  id uuid PK
  agent_slug text
  tool_name text
  input jsonb
  output jsonb
  duration_ms int
  status text       -- success | error
  created_at timestamp

-- Интеграции (ключи и токены)
integrations
  id uuid PK
  service text      -- whatsapp | instagram | tiktok | threads | openrouter | fal | notion
  credentials jsonb -- зашифровано
  is_active bool
  updated_at timestamp
```

---

## 6. API эндпоинты бэкенда

### Auth
```
POST /auth/login
POST /auth/refresh
POST /auth/logout
```

### Threads & Messages
```
GET  /threads                    — список тредов
POST /threads                    — создать тред
GET  /threads/:id/messages       — история сообщений (пагинация)
POST /threads/:id/messages       — отправить сообщение (триггерит оркестратор)
WS   /threads/:id/subscribe      — real-time поток новых сообщений
```

### Approval Queue
```
GET  /approvals?status=pending   — список задач на подтверждение
POST /approvals/:id/approve      — одобрить
POST /approvals/:id/reject       — отклонить
POST /approvals/:id/modify       — изменить payload и одобрить
```

### Agents
```
GET  /agents                     — список агентов и статусы
GET  /agents/:slug/config        — конфиг агента
PUT  /agents/:slug/config        — обновить промпт/модель/инструменты
GET  /agents/:slug/logs          — логи инструментов агента
```

### Integrations
```
GET  /integrations               — список интеграций и статусы
PUT  /integrations/:service      — сохранить credentials
POST /integrations/:service/test — проверить подключение
```

### Webhooks (входящие от внешних сервисов)
```
POST /webhooks/whatsapp          — входящие сообщения WhatsApp
POST /webhooks/instagram         — входящие DM и комментарии
```

### Files
```
POST /files/upload               — загрузить файл (для RAG юриста, медиа)
GET  /files/:id                  — получить файл
```

---

## 7. Flutter iOS — экраны

### 7.1 Auth
- Экран входа (email + password)
- Биометрия (Face ID) при повторном входе

### 7.2 Main Tab Bar
Три вкладки: **Чат** / **Задачи** / **Настройки**

---

### 7.3 Чат (главный экран)

**Список тредов** (левый drawer или отдельный экран):
- Название треда
- Последнее сообщение + время
- Кнопка создать новый тред

**Экран треда:**
- Сообщения с аватарами агентов (цвет по агенту)
- Тип отправителя: иконка + имя агента или "Вы"
- Поддержка медиа в сообщениях (изображения, видео, PDF)
- Индикатор "агент думает..." (animated dots)
- Поле ввода + кнопка отправки
- @теги при вводе — выпадающий список агентов
- Кнопка прикрепить файл (для юриста — документы)

**Bubble стили:**
- Пользователь: правый пузырь, primary цвет
- Оркестратор: серый, слева, подпись "Orchestrator"
- Юрист: синий, слева, подпись "Юрист"
- Контент: бирюзовый, слева, подпись "Контент"
- SMM: коралловый, слева, подпись "SMM"
- Продажник: янтарный, слева, подпись "Продажник"

---

### 7.4 Задачи (Approval Queue)

**Список задач:**
- Фильтры: Pending / Approved / Rejected / All
- Каждая задача — карточка с:
  - Агент (иконка + цвет)
  - Тип действия (напр. "Публикация в Instagram")
  - Превью payload (текст поста, медиа thumbnail)
  - Время запроса
  - Кнопки: ✅ Одобрить / ❌ Отклонить / ✏️ Изменить

**Экран детали задачи:**
- Полный payload (текст, медиа, получатель)
- История действий по задаче
- Поле для модификации (если нажал "Изменить")
- Контекст — ссылка на тред где задача была создана

---

### 7.5 Настройки

**Агенты:**
- Список агентов с toggle вкл/выкл
- Tap → экран редактирования:
  - System prompt (multiline text field)
  - Модель (dropdown с моделями OpenRouter)
  - Temperature (slider 0.0–1.0)
  - Список инструментов (toggle каждого)

**Интеграции:**
- Карточка каждого сервиса (WhatsApp, Instagram, TikTok, Threads, OpenRouter, FAL, Notion)
- Статус: Connected / Not connected
- Tap → форма ввода credentials + кнопка Test Connection

**Профиль:**
- Имя, email
- Push-уведомления (toggle: новые сообщения, новые задачи на approval)
- Биометрия toggle
- Выход

---

## 8. Desktop Admin Panel — экраны

Desktop = расширенная версия, ориентирована на мониторинг и настройку.

**Sidebar навигация:**
- Threads (чат)
- Approval Queue
- Agent Monitor
- Tool Logs
- Integrations
- Settings

**Agent Monitor (только desktop):**
- Статус каждого агента в реальном времени (idle / thinking / waiting approval)
- Последнее действие
- Количество вызовов за день / неделю
- Количество pending approvals

**Tool Logs (только desktop):**
- Таблица всех вызовов инструментов
- Фильтры по агенту, инструменту, статусу, дате
- Детали каждого вызова (input/output JSON)
- Экспорт в CSV

---

## 9. Push-уведомления

| Событие | Уведомление |
|---|---|
| Новое сообщение в треде | "SMM: подготовил пост для Instagram" |
| Новая задача на approval | "Требует подтверждения: публикация TikTok" |
| Задача просрочена (>1 час) | "Задача ждёт подтверждения больше часа" |
| Ошибка агента | "Продажник: ошибка подключения к WhatsApp" |
| Входящий лид (WhatsApp/Instagram) | "Новый лид от +7 777..." |

---

## 10. Безопасность

- JWT access token (15 мин) + refresh token (30 дней) в secure storage
- Все credentials интеграций хранятся зашифрованными (AES-256) в БД
- HTTPS everywhere (Let's Encrypt)
- Rate limiting на все API эндпоинты
- Все действия агентов логируются с timestamp и actor
- Приложение не работает без авторизации (no offline mode для чата)
- Биометрия как второй фактор на iOS

---

## 11. Внешние интеграции — детали подключения

### OpenRouter
```
Base URL: https://openrouter.ai/api/v1
Auth: Bearer API Key
Используемые модели:
  - Оркестратор: anthropic/claude-sonnet-4-5 (умный роутинг)
  - Юрист: anthropic/claude-opus-4 (точность)
  - Контент: anthropic/claude-sonnet-4-5
  - SMM: anthropic/claude-sonnet-4-5
  - Продажник: anthropic/claude-haiku-4-5 (скорость ответа)
```

### WhatsApp (360dialog)
```
Webhook: POST /webhooks/whatsapp
Auth: API Key в заголовке
Отправка: POST https://waba.360dialog.io/v1/messages
Формат: WhatsApp Business API (Meta-совместимый)
```

### Instagram Graph API
```
Base URL: https://graph.facebook.com/v19.0
Auth: Long-lived Page Access Token
Webhooks: Meta Developer Dashboard → подписка на messages, comments
```

### TikTok Content Posting API
```
Base URL: https://open.tiktokapis.com/v2
Auth: OAuth 2.0 (пользователь авторизует один раз)
Scope: video.upload, video.publish
```

### Threads API
```
Base URL: https://graph.threads.net/v1.0
Auth: Threads User Access Token
```

### FAL.ai (генерация медиа)
```
Base URL: https://fal.run
Auth: FAL_KEY
Модели: fal-ai/flux/dev (изображения), fal-ai/kling-video (видео)
```

### Notion API
```
Base URL: https://api.notion.com/v1
Auth: Integration Token
Использование: CRM-таблица лидов
```

---

## 12. Фазы разработки

### Фаза 1 — Core (4-5 недель)
- Бэкенд: auth, треды, сообщения, WebSocket
- Flutter iOS: чат экран, auth, push
- Оркестратор + 1 агент (Контент-менеджер как самый безопасный для теста)
- Approval Queue базовый

### Фаза 2 — Agents (3-4 недели)
- Подключение всех 4 агентов
- Интеграции: OpenRouter, FAL.ai, Notion
- Approval Queue полный (approve/reject/modify)
- Desktop Admin Panel: чат + approval

### Фаза 3 — Integrations (3-4 недели)
- WhatsApp (360dialog) + webhooks
- Instagram Graph API
- TikTok Content API
- Threads API
- Юрист: RAG по документам

### Фаза 4 — Polish (2 недели)
- Desktop: Agent Monitor, Tool Logs
- Аналитика и экспорт
- Производительность, кэширование
- Тестирование на реальных сценариях

**Итого MVP: ~12-15 недель (1 Flutter + 1 Backend разработчик)**

---

## 13. Структура Flutter проекта

```
lib/
├── core/
│   ├── api/          # Dio клиент, interceptors
│   ├── auth/         # JWT storage, refresh логика
│   ├── websocket/    # WS клиент, reconnect
│   └── theme/        # цвета агентов, typography
├── features/
│   ├── auth/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── chat/
│   │   ├── data/     # messages repo, WS listener
│   │   ├── domain/   # Message, Thread models
│   │   └── presentation/
│   │       ├── thread_list_screen.dart
│   │       ├── chat_screen.dart
│   │       └── widgets/
│   │           ├── message_bubble.dart
│   │           ├── agent_typing_indicator.dart
│   │           └── media_message.dart
│   ├── approvals/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │       ├── approval_list_screen.dart
│   │       └── approval_detail_screen.dart
│   └── settings/
│       ├── agents/
│       └── integrations/
└── main.dart
```

---

## 14. Структура бэкенда

```
src/
├── plugins/          # Fastify plugins (db, redis, auth, ws)
├── routes/
│   ├── auth.ts
│   ├── threads.ts
│   ├── messages.ts
│   ├── approvals.ts
│   ├── agents.ts
│   ├── integrations.ts
│   └── webhooks.ts
├── agents/
│   ├── orchestrator.ts
│   ├── lawyer.ts
│   ├── content.ts
│   ├── smm.ts
│   └── sales.ts
├── tools/            # Инструменты агентов
│   ├── instagram.ts
│   ├── whatsapp.ts
│   ├── tiktok.ts
│   ├── fal.ts
│   └── notion.ts
├── queue/            # BullMQ jobs
│   ├── agent-runner.ts
│   └── approval.ts
└── db/
    ├── schema.ts
    └── migrations/
```

---

## 15. Инфраструктура сервера

**Минимальные требования:**
- VPS: 4 CPU / 8GB RAM / 80GB SSD
- Ubuntu 22.04 LTS
- Docker + Docker Compose

**Docker Compose сервисы:**
```yaml
services:
  api:        # Node.js Fastify
  postgres:   # PostgreSQL 16
  redis:      # Redis 7
  minio:      # MinIO (файловое хранилище)
  nginx:      # Reverse proxy + SSL
  playwright: # Headless browser для SMM агента
```

**Домен и SSL:** Let's Encrypt через Certbot (автообновление)

---

*Документ подготовлен для внутреннего использования CANNECT.AI*  
*Версия 1.0 — требует согласования перед стартом разработки*
