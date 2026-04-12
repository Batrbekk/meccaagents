# AgentTeam Implementation Plan v2.0

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Внутренняя платформа управления командой из 5 AI-агентов с iOS-приложением, Desktop Admin Panel и self-hosted бэкендом на Windows.

**Architecture:** Fastify API + Agent Worker (BullMQ) + Playwright Microservice — всё в Docker на Windows 11 + WSL2. Единственный AI-провайдер — OpenRouter (текст + картинки + видео). Flutter iOS + Desktop на общей кодовой базе.

**Tech Stack:** Node.js 20 / Fastify / Drizzle ORM / BullMQ / PostgreSQL 16 + pgvector / Redis 7 / MinIO / Flutter / Riverpod / Dio

**Hardware:** Windows 11, i5-12400F (6C/12T), 16GB RAM, GTX 1660 Super (не используется стеком)

---

## Ключевые изменения vs оригинальное ТЗ

### 1. Единый AI-провайдер — OpenRouter
~~FAL.ai~~, ~~RunwayML~~, ~~Kling API~~, ~~Replicate~~ — убраны. OpenRouter покрывает всё:
- **Текст:** Claude Sonnet 4.5, Claude Opus 4, Claude Haiku 4.5
- **Изображения:** FLUX.2 Pro, Gemini Flash Image, GPT-5 Image, Seedream 4.5
- **Видео:** Sora 2 Pro ($0.30-0.50/сек), Veo 3.1 ($0.20-0.60/сек), Seedance 1.5 Pro
- **Web Search:** встроенный tool `openrouter:web_search`

Единый API клиент, единый ключ, единый формат ответа.

### 2. Windows + Docker Desktop + WSL2
Сервер на Windows 11, всё в Docker-контейнерах через WSL2. Критичные настройки:
- `.wslconfig` ограничивает WSL2 до 10GB RAM
- Только named volumes (bind mounts из Windows в 5-10x медленнее)
- `shm_size: 1gb` для Playwright
- Log rotation на всех контейнерах
- `stop_grace_period: 30s` для graceful shutdown
- `CHOKIDAR_USEPOLLING=true` для hot reload в dev

### 3. Playwright как микросервис
Отдельный Docker-контейнер с REST API + noVNC. Решает:
- TikTok-публикация через сохранённую сессию (вместо закрытого API)
- Мониторинг комментариев и конкурентов
- Backup-скрейпинг если Graph API ограничен

### 4. Безопасность — добавлены критичные компоненты
- Refresh token rotation (token family invalidation)
- Webhook HMAC-SHA256 verification + replay protection
- Шифрование credentials через Windows DPAPI / env variable (не в коде)
- Docker network segmentation (frontend/backend)
- Agent output sanitization перед публикацией
- File upload: UUID names, magic bytes validation, 10MB limit
- noVNC — только localhost + password

### 5. Таймлайн пересмотрен
- Оригинал: 12-15 недель — **нереалистично**
- Новый: **19-22 недели** с буфером

---

## Стоимость API (оценка в день)

| Модальность | Объём | ~Стоимость |
|---|---|---|
| Текст (Claude Sonnet) | 100 вызовов x ~2000 токенов | ~$2-4 |
| Изображения (FLUX.2 / Gemini) | 10 шт | ~$0.30-1.00 |
| Видео (Veo 3.1, 8 сек) | 2 шт | ~$6.40 |
| **Итого** | | **~$8-11/день** |

---

## Phase 0 — Foundation (1 неделя)

### Task 0.1: Docker Compose для Windows

**Files:**
- Create: `docker-compose.yml`
- Create: `docker-compose.dev.yml`
- Create: `.env.example`
- Create: `.gitignore`
- Create: `nginx/nginx.conf`

- [ ] **Step 1:** Создать `.wslconfig` для ограничения WSL2:
```ini
# %UserProfile%\.wslconfig
[wsl2]
memory=10GB
swap=4GB
processors=8
localhostForwarding=true
```

- [ ] **Step 2:** Создать `docker-compose.yml`:
```yaml
services:
  api:
    build: ./backend
    mem_limit: 512m
    ports: ["3000:3000"]
    environment:
      - CHOKIDAR_USEPOLLING=true
    stop_grace_period: 30s
    depends_on: [postgres, redis]
    networks: [frontend, backend]
    logging:
      driver: json-file
      options: { max-size: "10m", max-file: "3" }

  agent-worker:
    build: ./backend
    command: ["node", "dist/workers/agent-runner.js"]
    mem_limit: 768m
    stop_grace_period: 30s
    depends_on: [postgres, redis]
    networks: [backend]
    logging:
      driver: json-file
      options: { max-size: "10m", max-file: "3" }

  postgres:
    image: pgvector/pgvector:pg16
    mem_limit: 512m
    shm_size: '256m'
    command: >
      postgres
        -c shared_buffers=256MB
        -c effective_cache_size=512MB
        -c work_mem=8MB
        -c maintenance_work_mem=64MB
    volumes:
      - pg_data:/var/lib/postgresql/data
    networks: [backend]

  redis:
    image: redis:7-alpine
    mem_limit: 256m
    command: ["redis-server", "--maxmemory", "200mb", "--maxmemory-policy", "allkeys-lru"]
    volumes:
      - redis_data:/data
    networks: [backend]

  minio:
    image: minio/minio
    mem_limit: 256m
    command: server /data --console-address ":9001"
    volumes:
      - minio_data:/data
    ports: ["9001:9001"]
    networks: [backend]

  playwright-service:
    build: ./services/playwright
    mem_limit: 1536m
    shm_size: '1gb'
    ports:
      - "6080:6080"    # noVNC (только localhost)
    volumes:
      - playwright_sessions:/app/sessions
    networks: [backend]

  nginx:
    image: nginx:alpine
    mem_limit: 64m
    ports: ["80:80", "443:443"]
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on: [api]
    networks: [frontend]

networks:
  frontend:
  backend:

volumes:
  pg_data:
  redis_data:
  minio_data:
  playwright_sessions:
```

- [ ] **Step 3:** Создать `.env.example`:
```env
# Database
POSTGRES_USER=agentteam
POSTGRES_PASSWORD=changeme
POSTGRES_DB=agentteam
DATABASE_URL=postgresql://agentteam:changeme@postgres:5432/agentteam

# Redis
REDIS_URL=redis://redis:6379

# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=changeme
MINIO_ENDPOINT=minio
MINIO_PORT=9000

# Auth
JWT_SECRET=changeme-64-chars-random
JWT_ACCESS_TTL=15m
JWT_REFRESH_TTL=30d
CREDENTIALS_ENCRYPTION_KEY=changeme-32-bytes-hex

# OpenRouter (ЕДИНСТВЕННЫЙ AI-провайдер)
OPENROUTER_API_KEY=sk-or-...
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1

# Playwright Service
PLAYWRIGHT_SERVICE_URL=http://playwright-service:3100
NOVNC_PASSWORD=changeme

# Push
FCM_SERVER_KEY=...
```

- [ ] **Step 4:** Создать nginx config с reverse proxy и CORS
- [ ] **Step 5:** `docker compose up` — проверить все сервисы стартуют
- [ ] **Step 6:** Commit

### Task 0.2: Fastify Boilerplate

**Files:**
- Create: `backend/package.json`
- Create: `backend/tsconfig.json`
- Create: `backend/Dockerfile`
- Create: `backend/src/app.ts`
- Create: `backend/src/plugins/db.ts`
- Create: `backend/src/plugins/redis.ts`
- Create: `backend/src/plugins/auth.ts`
- Create: `backend/src/plugins/websocket.ts`
- Create: `backend/src/plugins/minio.ts`
- Create: `backend/src/lib/logger.ts`
- Create: `backend/src/lib/errors.ts`
- Create: `backend/src/lib/crypto.ts`

- [ ] **Step 1:** Init Node.js 20 project: TypeScript, Fastify, pino (structured JSON logging)
- [ ] **Step 2:** Fastify plugins: PostgreSQL (pg + drizzle-orm), Redis (ioredis), MinIO (minio client), WebSocket (@fastify/websocket)
- [ ] **Step 3:** Crypto utility: AES-256-GCM encrypt/decrypt для credentials в БД. Ключ из env `CREDENTIALS_ENCRYPTION_KEY`
- [ ] **Step 4:** Centralized error handler со structured error responses
- [ ] **Step 5:** `GET /health` (liveness), `GET /ready` (readiness — проверяет DB + Redis connection)
- [ ] **Step 6:** Graceful shutdown handler: ловит SIGTERM, закрывает DB pool, drains WS connections
- [ ] **Step 7:** Проверить что app стартует в Docker и подключается ко всем сервисам
- [ ] **Step 8:** Commit

### Task 0.3: Database Schema + Migrations

**Files:**
- Create: `backend/src/db/schema.ts`
- Create: `backend/src/db/seed.ts`
- Create: `backend/drizzle.config.ts`

- [ ] **Step 1:** Включить расширения PostgreSQL:
```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "vector";
```

- [ ] **Step 2:** Определить schema в Drizzle ORM:

```typescript
// users
users: {
  id: uuid PK default uuid_generate_v4(),
  email: text UNIQUE NOT NULL,
  name: text NOT NULL,
  password_hash: text NOT NULL,
  role: text NOT NULL default 'owner',  // owner | admin | viewer
  is_active: boolean default true,
  last_login_at: timestamp,
  created_at: timestamp default now()
}

// sessions (refresh token management с rotation)
sessions: {
  id: uuid PK,
  user_id: uuid FK → users ON DELETE CASCADE,
  refresh_token_hash: text NOT NULL,  // argon2 hash
  token_family: uuid NOT NULL,        // для обнаружения повторного использования
  device_info: text,
  expires_at: timestamp NOT NULL,
  created_at: timestamp default now()
}

// threads
threads: {
  id: uuid PK,
  title: text NOT NULL,
  created_by: uuid FK → users,
  is_archived: boolean default false,
  created_at: timestamp default now()
}

// messages
messages: {
  id: uuid PK,
  thread_id: uuid FK → threads ON DELETE CASCADE,
  sender_type: text NOT NULL,           // user | agent
  sender_id: text NOT NULL,             // user uuid или agent slug
  content: text,
  metadata: jsonb default '{}',         // tool_calls, file_urls, image_base64, etc
  status: text default 'sent',          // sending | sent | error
  parent_message_id: uuid FK → messages, // nullable, для reply-to
  created_at: timestamp default now()
}

// approval_tasks
approval_tasks: {
  id: uuid PK,
  agent_slug: text NOT NULL,
  action_type: text NOT NULL,
  payload: jsonb NOT NULL,
  status: text default 'pending',       // pending | approved | rejected | modified
  expires_at: timestamp,                // pending > 1 hour → push notification
  notes: text,                          // причина reject / комментарий к modify
  requested_at: timestamp default now(),
  resolved_at: timestamp,
  resolved_by: uuid FK → users,
  thread_id: uuid FK → threads,
  message_id: uuid FK → messages
}

// agent_configs
agent_configs: {
  id: uuid PK,
  slug: text UNIQUE NOT NULL,
  display_name: text NOT NULL,
  system_prompt: text NOT NULL,
  model: text NOT NULL,
  temperature: real default 0.7,
  tools: jsonb default '[]',
  is_active: boolean default true,
  updated_at: timestamp default now()
}

// tool_logs
tool_logs: {
  id: uuid PK,
  agent_slug: text NOT NULL,
  tool_name: text NOT NULL,
  input: jsonb,
  output: jsonb,
  duration_ms: integer,
  status: text NOT NULL,                // success | error
  error_message: text,
  created_at: timestamp default now()
}

// integrations
integrations: {
  id: uuid PK,
  service: text UNIQUE NOT NULL,
  credentials: text NOT NULL,           // AES-256-GCM encrypted JSON
  is_active: boolean default false,
  updated_at: timestamp default now()
}

// files
files: {
  id: uuid PK,
  original_name: text NOT NULL,
  stored_name: text NOT NULL,           // UUID-based, prevents path traversal
  mime_type: text NOT NULL,
  size_bytes: bigint NOT NULL,
  storage_path: text NOT NULL,          // MinIO path
  uploaded_by: uuid FK → users,
  thread_id: uuid FK → threads,         // nullable
  created_at: timestamp default now()
}

// audit_log
audit_log: {
  id: uuid PK,
  actor_type: text NOT NULL,            // user | agent | system
  actor_id: text NOT NULL,
  action: text NOT NULL,
  resource_type: text NOT NULL,
  resource_id: text,
  details: jsonb,
  ip_address: text,
  created_at: timestamp default now()
}

// document_chunks (RAG для юриста)
document_chunks: {
  id: uuid PK,
  file_id: uuid FK → files ON DELETE CASCADE,
  content: text NOT NULL,
  embedding: vector(1536) NOT NULL,
  chunk_index: integer NOT NULL,
  metadata: jsonb,                      // page_number, section, etc
  created_at: timestamp default now()
}
```

- [ ] **Step 3:** Создать индексы:
```sql
CREATE INDEX idx_messages_thread_created ON messages(thread_id, created_at DESC);
CREATE INDEX idx_messages_sender ON messages(sender_type, sender_id);
CREATE INDEX idx_approval_status_requested ON approval_tasks(status, requested_at DESC);
CREATE INDEX idx_approval_thread ON approval_tasks(thread_id);
CREATE INDEX idx_tool_logs_agent_created ON tool_logs(agent_slug, created_at DESC);
CREATE INDEX idx_tool_logs_status ON tool_logs(status);
CREATE INDEX idx_sessions_user ON sessions(user_id);
CREATE INDEX idx_sessions_family ON sessions(token_family);
CREATE INDEX idx_audit_log_created ON audit_log(created_at DESC);
CREATE INDEX idx_audit_log_actor ON audit_log(actor_type, actor_id);
CREATE INDEX idx_document_chunks_file ON document_chunks(file_id);
CREATE INDEX idx_document_chunks_embedding ON document_chunks USING ivfflat (embedding vector_cosine_ops);
CREATE INDEX idx_files_thread ON files(thread_id);
CREATE INDEX idx_threads_created_by ON threads(created_by);
```

- [ ] **Step 4:** Seed data — 5 agent_configs:
```
orchestrator: Claude Sonnet 4.5, temp 0.3
lawyer: Claude Opus 4, temp 0.2
content: Claude Sonnet 4.5, temp 0.8
smm: Claude Sonnet 4.5, temp 0.7
sales: Claude Haiku 4.5, temp 0.5
```

- [ ] **Step 5:** Запустить migration, проверить что все таблицы созданы
- [ ] **Step 6:** Commit

### Task 0.4: Flutter Project Setup

**Files:**
- Create: `flutter_app/` (Flutter project)
- Create: `flutter_app/lib/core/api/dio_client.dart`
- Create: `flutter_app/lib/core/api/interceptors.dart`
- Create: `flutter_app/lib/core/theme/app_theme.dart`
- Create: `flutter_app/lib/core/theme/agent_colors.dart`
- Create: `flutter_app/lib/core/auth/secure_storage.dart`
- Create: `flutter_app/lib/core/websocket/ws_client.dart`
- Create: `flutter_app/lib/core/router/app_router.dart`

- [ ] **Step 1:** `flutter create --platforms=ios,macos,web` + зависимости: riverpod, go_router, dio, web_socket_channel, hive, freezed, flutter_secure_storage, local_auth, firebase_messaging, image_picker, file_picker
- [ ] **Step 2:** Dio client с JWT interceptor: auto-attach access token, auto-refresh на 401 (с очередью запросов во время refresh)
- [ ] **Step 3:** App theme + agent colors: orchestrator=#9E9E9E, lawyer=#2196F3, content=#009688, smm=#FF7043, sales=#FFC107
- [ ] **Step 4:** Secure storage wrapper (flutter_secure_storage)
- [ ] **Step 5:** WebSocket client: auto-reconnect с exponential backoff (1s, 2s, 4s, 8s, max 30s)
- [ ] **Step 6:** go_router setup с auth redirect guard
- [ ] **Step 7:** Проверить build на iOS simulator
- [ ] **Step 8:** Commit

### Task 0.5: Playwright Microservice Skeleton

**Files:**
- Create: `services/playwright/Dockerfile`
- Create: `services/playwright/package.json`
- Create: `services/playwright/src/server.ts`
- Create: `services/playwright/src/session-manager.ts`

- [ ] **Step 1:** Dockerfile на базе `mcr.microsoft.com/playwright:v1.52.0-noble` + noVNC + xvfb + fluxbox:
```dockerfile
FROM mcr.microsoft.com/playwright:v1.52.0-noble
RUN apt-get update && apt-get install -y xvfb fluxbox x11vnc novnc websockify
# ... setup noVNC on port 6080
COPY . /app
WORKDIR /app
RUN npm install
EXPOSE 3100 6080
CMD ["node", "src/server.js"]
```

- [ ] **Step 2:** Express/Fastify REST API на порту 3100:
```
GET  /api/health              — health check
GET  /api/sessions            — список сохранённых сессий
GET  /api/sessions/:platform/status  — проверка валидности сессии
POST /api/sessions/:platform/save    — сохранить текущую сессию
POST /api/tiktok/post         — опубликовать видео
GET  /api/tiktok/comments/:videoId  — получить комментарии
POST /api/tiktok/scrape-profile     — скрейпинг профиля конкурента
POST /api/screenshot          — сделать скриншот URL
```

- [ ] **Step 3:** Session manager: загрузка/сохранение cookies из `/app/sessions/{platform}.json` (Docker volume)
- [ ] **Step 4:** noVNC с паролем из env `NOVNC_PASSWORD`, привязка только к localhost на хосте
- [ ] **Step 5:** Установить `playwright-extra` + stealth plugin для anti-bot protection
- [ ] **Step 6:** Проверить что контейнер стартует, noVNC доступен на localhost:6080
- [ ] **Step 7:** Commit

### Task 0.6: CI Pipeline

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1:** Backend: ESLint + tsc + vitest
- [ ] **Step 2:** Flutter: analyze + test
- [ ] **Step 3:** Commit

---

## Phase 1 — Auth + Chat Core (3 недели)

### Task 1.1: Backend Auth с Refresh Token Rotation

**Files:**
- Create: `backend/src/routes/auth.ts`
- Create: `backend/src/lib/jwt.ts`
- Create: `backend/src/lib/password.ts`
- Create: `backend/tests/auth.test.ts`

- [ ] **Step 1:** Тесты: register, login (success/wrong password/inactive user), refresh (valid/expired/reused), logout
- [ ] **Step 2:** Password hashing: argon2
- [ ] **Step 3:** JWT: access token (15 min, в Authorization header) + refresh token (30 days, httpOnly secure cookie с SameSite=Strict)
- [ ] **Step 4:** Refresh token rotation:
  - Каждый refresh выдаёт новую пару access + refresh
  - Старый refresh инвалидируется
  - Если кто-то пытается использовать старый refresh → инвалидировать ВСЮ token family (кража токена)
- [ ] **Step 5:** Роуты: `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`
- [ ] **Step 6:** Auth preHandler plugin: валидация JWT, инъекция user в request
- [ ] **Step 7:** Audit log: логировать login, failed login, token refresh, logout
- [ ] **Step 8:** Тесты проходят
- [ ] **Step 9:** Commit

### Task 1.2: Threads CRUD

**Files:**
- Create: `backend/src/routes/threads.ts`
- Create: `backend/tests/threads.test.ts`

- [ ] **Step 1:** Тесты: create, list (sorted by last message), archive, delete
- [ ] **Step 2:** Реализация: `GET /threads`, `POST /threads`, `POST /threads/:id/archive`, `DELETE /threads/:id`
- [ ] **Step 3:** Тесты проходят
- [ ] **Step 4:** Commit

### Task 1.3: Messages API

**Files:**
- Create: `backend/src/routes/messages.ts`
- Create: `backend/tests/messages.test.ts`

- [ ] **Step 1:** Тесты: create, list (cursor pagination), with file attachment, error status
- [ ] **Step 2:** `POST /threads/:id/messages` — создание + publish в Redis Pub/Sub
- [ ] **Step 3:** `GET /threads/:id/messages?cursor=&limit=50` — cursor-based pagination (created_at + id)
- [ ] **Step 4:** Тесты проходят
- [ ] **Step 5:** Commit

### Task 1.4: WebSocket Real-time

**Files:**
- Create: `backend/src/routes/ws.ts`
- Create: `backend/src/lib/pubsub.ts`

- [ ] **Step 1:** Redis Pub/Sub wrapper: publish / subscribe по channel `thread:{id}`
- [ ] **Step 2:** WS endpoint: `/threads/:id/subscribe`
  - Аутентификация: JWT в первом сообщении (не в query param — виден в логах)
  - Rate limit: max 100 msg/min per connection
  - Max message size: 64KB
- [ ] **Step 3:** New message → Redis publish → broadcast to WS subscribers
- [ ] **Step 4:** Heartbeat ping/pong каждые 30 секунд
- [ ] **Step 5:** Тест с wscat
- [ ] **Step 6:** Commit

### Task 1.5: File Upload/Download

**Files:**
- Create: `backend/src/routes/files.ts`
- Create: `backend/src/lib/file-validator.ts`

- [ ] **Step 1:** `POST /files/upload` — multipart upload:
  - Имя файла: UUID (предотвращает path traversal)
  - Валидация MIME по magic bytes (не по расширению)
  - Max size: 10MB
  - Allowed: image/*, application/pdf, .doc, .docx
  - Сохранение в MinIO + запись в files table
- [ ] **Step 2:** `GET /files/:id` — presigned URL (5 min TTL) redirect
- [ ] **Step 3:** Тест upload + download
- [ ] **Step 4:** Commit

### Task 1.6: Security Middleware

- [ ] **Step 1:** `fastify-rate-limit`: 100 req/min API, 10 req/min auth, 5 req/min file upload
- [ ] **Step 2:** `@fastify/cors`: allow origins из env (Flutter app domains)
- [ ] **Step 3:** `@fastify/helmet`: security headers
- [ ] **Step 4:** Input validation: `@sinclair/typebox` для всех route schemas
- [ ] **Step 5:** Commit

### Task 1.7: Flutter Auth Screens

**Files:**
- Create: `flutter_app/lib/features/auth/data/auth_repository.dart`
- Create: `flutter_app/lib/features/auth/domain/user.dart`
- Create: `flutter_app/lib/features/auth/presentation/login_screen.dart`
- Create: `flutter_app/lib/features/auth/providers/auth_provider.dart`

- [ ] **Step 1:** User model (freezed)
- [ ] **Step 2:** AuthRepository: login, refresh, logout. Tokens в flutter_secure_storage
- [ ] **Step 3:** Login screen: email + password, error handling
- [ ] **Step 4:** Biometric unlock (local_auth) для повторного входа
- [ ] **Step 5:** Auth state Riverpod provider с auto-redirect на login при expired token
- [ ] **Step 6:** Тест на iOS simulator
- [ ] **Step 7:** Commit

### Task 1.8: Flutter Chat Screen

**Files:**
- Create: `flutter_app/lib/features/chat/data/message_repository.dart`
- Create: `flutter_app/lib/features/chat/data/ws_listener.dart`
- Create: `flutter_app/lib/features/chat/domain/message.dart`
- Create: `flutter_app/lib/features/chat/domain/thread.dart`
- Create: `flutter_app/lib/features/chat/presentation/thread_list_screen.dart`
- Create: `flutter_app/lib/features/chat/presentation/chat_screen.dart`
- Create: `flutter_app/lib/features/chat/presentation/widgets/message_bubble.dart`
- Create: `flutter_app/lib/features/chat/presentation/widgets/media_message.dart`

- [ ] **Step 1:** Message + Thread models (freezed)
- [ ] **Step 2:** MessageRepository: fetch (cursor pagination), send, retry on failure
- [ ] **Step 3:** WS listener: connect, auto-reconnect, parse incoming messages
- [ ] **Step 4:** Thread list: список, создание, последнее сообщение + время
- [ ] **Step 5:** Chat screen: reverse scroll list, input, send button
- [ ] **Step 6:** Message bubble: user (right, primary) vs agent (left, agent color + avatar)
- [ ] **Step 7:** Media message: image preview, PDF icon, video thumbnail
- [ ] **Step 8:** File attachment (image_picker + file_picker)
- [ ] **Step 9:** Hive cache для offline reading
- [ ] **Step 10:** Skeleton screens вместо loading spinners
- [ ] **Step 11:** Full flow test: login → create thread → send → receive real-time
- [ ] **Step 12:** Commit

### Task 1.9: Push Notifications

**Files:**
- Create: `flutter_app/lib/core/notifications/push_service.dart`
- Create: `backend/src/lib/push.ts`

- [ ] **Step 1:** FCM setup в Flutter
- [ ] **Step 2:** Backend: сохранение FCM token при login, push на new message / new approval
- [ ] **Step 3:** Deep linking: push → конкретный тред или approval task
- [ ] **Step 4:** Тест на реальном iOS устройстве
- [ ] **Step 5:** Commit

**Milestone Phase 1:** Два человека общаются в real-time чате. Файлы прикрепляются. Push работает. Auth безопасен.

---

## Phase 2 — Orchestrator + First Agent (3 недели)

### Task 2.1: Unified OpenRouter Client

**Files:**
- Create: `backend/src/lib/openrouter.ts`
- Create: `backend/tests/openrouter.test.ts`

- [ ] **Step 1:** Единый TypeScript клиент для ВСЕХ модальностей OpenRouter:

```typescript
interface OpenRouterClient {
  // Текст (chat completions)
  chat(params: ChatParams): Promise<ChatResponse>;
  chatStream(params: ChatParams): AsyncIterable<ChatChunk>;

  // Изображения (тот же /chat/completions с modalities: ["image"])
  generateImage(params: ImageParams): Promise<ImageResponse>;

  // Видео (POST /videos + async polling)
  generateVideo(params: VideoParams): Promise<VideoJob>;
  pollVideo(pollingUrl: string): Promise<VideoResult>;

  // Утилиты
  getBalance(): Promise<{ remaining: number }>;
}
```

- [ ] **Step 2:** Retry logic с exponential backoff (429 rate limit, 5xx errors)
- [ ] **Step 3:** Fallback: параметр `provider.order` для переключения между провайдерами
- [ ] **Step 4:** Web search tool integration: `tools: [{ type: "openrouter:web_search" }]`
- [ ] **Step 5:** Тесты (mock API)
- [ ] **Step 6:** Commit

### Task 2.2: Agent Runner Worker

**Files:**
- Create: `backend/src/workers/agent-runner.ts`
- Create: `backend/src/agents/base-agent.ts`

- [ ] **Step 1:** Base agent class:
  - Конфиг из БД (system_prompt, model, temperature, tools)
  - Execute: формирует messages array, вызывает OpenRouter, обрабатывает tool calls
  - Output sanitization: проверка ответа агента перед сохранением (нет injection, адекватный контент)
  - Tool call logging: каждый вызов инструмента → tool_logs table
- [ ] **Step 2:** BullMQ worker:
  - Подписка на очередь `agent:run`
  - Берёт job → загружает agent config → выполняет → сохраняет message → публикует в WS
  - Concurrency: 3 (не больше 3 агентов параллельно при 16GB RAM)
- [ ] **Step 3:** Streaming: token stream → Redis Stream → WS → Flutter
- [ ] **Step 4:** Error handling: если агент упал → message со status "error" → push уведомление
- [ ] **Step 5:** End-to-end test
- [ ] **Step 6:** Commit

### Task 2.3: Orchestrator Agent

**Files:**
- Create: `backend/src/agents/orchestrator.ts`

- [ ] **Step 1:** Routing logic:
  - Парсит @теги в сообщении → прямой routing
  - Без тегов → анализирует контент → определяет целевого агента
  - Keywords/intent mapping: "договор/NDA/контракт" → lawyer, "пост/контент/reels" → content, "публикация/комментарии" → smm, "лид/клиент/WhatsApp" → sales
- [ ] **Step 2:** Chain building: задача требует несколько агентов → ordered BullMQ jobs
- [ ] **Step 3:** Context: передаёт последние 20 сообщений треда как context
- [ ] **Step 4:** Approval detection: если agent tool требует approval → создаёт approval_task
- [ ] **Step 5:** Тесты routing
- [ ] **Step 6:** Commit

### Task 2.4: Content Manager Agent

**Files:**
- Create: `backend/src/agents/content.ts`
- Create: `backend/src/tools/media-generator.ts`

- [ ] **Step 1:** System prompt: контент-планирование, написание скриптов, креатив
- [ ] **Step 2:** Tools:
  - `generate_content_plan` — создаёт план на неделю/месяц
  - `write_script` — пишет скрипт для видео/поста
  - `generate_image` — вызывает OpenRouter (FLUX.2 Pro / Gemini Flash Image), сохраняет в MinIO
  - `generate_video` — вызывает OpenRouter (Sora 2 / Veo 3.1), async polling, сохраняет в MinIO
- [ ] **Step 3:** Approval: контент-план и готовые материалы → approval task с preview
- [ ] **Step 4:** Тест: "создай контент-план на неделю" → генерация → approval
- [ ] **Step 5:** Commit

### Task 2.5: Approval Queue Backend

**Files:**
- Create: `backend/src/routes/approvals.ts`
- Create: `backend/src/workers/approval-executor.ts`
- Create: `backend/tests/approvals.test.ts`

- [ ] **Step 1:** `GET /approvals?status=pending` — список с фильтрами
- [ ] **Step 2:** `POST /approvals/:id/approve` → ставит status approved → запускает BullMQ job для выполнения действия
- [ ] **Step 3:** `POST /approvals/:id/reject` → status rejected, сохраняет notes
- [ ] **Step 4:** `POST /approvals/:id/modify` → обновляет payload, ставит status modified, затем выполняет
- [ ] **Step 5:** Expiry monitor: BullMQ repeatable job каждые 15 мин → проверяет pending > 1 час → push
- [ ] **Step 6:** Audit log на каждое действие
- [ ] **Step 7:** Webhook replay protection: сохранять ID обработанных webhook events в Redis с TTL 5 мин
- [ ] **Step 8:** Тесты
- [ ] **Step 9:** Commit

### Task 2.6: Agent Config API

**Files:**
- Create: `backend/src/routes/agents.ts`

- [ ] **Step 1:** `GET /agents` — список с real-time статусом (из Redis: idle/thinking/waiting_approval)
- [ ] **Step 2:** `GET /agents/:slug/config`
- [ ] **Step 3:** `PUT /agents/:slug/config` — update prompt/model/temperature/tools (audit log)
- [ ] **Step 4:** `GET /agents/:slug/logs?limit=50&cursor=`
- [ ] **Step 5:** Commit

### Task 2.7: Flutter — Agent UX

**Files:**
- Create: `flutter_app/lib/features/chat/presentation/widgets/agent_typing_indicator.dart`
- Create: `flutter_app/lib/features/chat/presentation/widgets/mention_autocomplete.dart`
- Create: `flutter_app/lib/features/chat/presentation/widgets/streaming_text.dart`

- [ ] **Step 1:** Agent typing indicator (animated dots с цветом агента)
- [ ] **Step 2:** Streaming text widget: токены появляются progressively
- [ ] **Step 3:** @mention autocomplete: ввод @ → dropdown с 5 агентами
- [ ] **Step 4:** Commit

### Task 2.8: Flutter — Approval Queue

**Files:**
- Create: `flutter_app/lib/features/approvals/data/approval_repository.dart`
- Create: `flutter_app/lib/features/approvals/domain/approval_task.dart`
- Create: `flutter_app/lib/features/approvals/presentation/approval_list_screen.dart`
- Create: `flutter_app/lib/features/approvals/presentation/approval_detail_screen.dart`

- [ ] **Step 1:** ApprovalTask model (freezed)
- [ ] **Step 2:** Approval list: filter tabs (Pending/Approved/Rejected/All), task cards с agent color
- [ ] **Step 3:** Approval detail: full payload preview (text, images, video thumbnail), approve/reject/modify
- [ ] **Step 4:** Modify flow: edit text → approve
- [ ] **Step 5:** Real-time: WS broadcast when new approval task created
- [ ] **Step 6:** Commit

**Milestone Phase 2:** Пользователь пишет → Оркестратор роутит → Content Manager генерирует контент (текст + картинки) → Approval → Owner одобряет. Streaming ответы. Push на новые задачи.

---

## Phase 3 — Remaining Agents (4 недели)

### Task 3.1: Lawyer Agent + RAG

**Files:**
- Create: `backend/src/agents/lawyer.ts`
- Create: `backend/src/tools/pdf-generator.ts`
- Create: `backend/src/lib/embeddings.ts`
- Create: `backend/src/lib/rag.ts`

- [ ] **Step 1:** Lawyer agent: system prompt (юрист, законодательство РК/РФ, точность критична)
- [ ] **Step 2:** RAG pipeline:
  - Upload PDF/DOCX → extract text (pdf-parse / mammoth) → chunk (500 tokens, 50 overlap)
  - Embed chunks через OpenRouter (text-embedding-3-small или аналог)
  - Store в document_chunks (pgvector)
- [ ] **Step 3:** RAG search tool: query → embed → cosine similarity → top-5 chunks
- [ ] **Step 4:** Tools:
  - `search_documents` — RAG поиск по базе
  - `check_legal_risks` — анализ текста на юридические риски
  - `generate_contract` — генерация договора по шаблону
  - `web_search` — OpenRouter web search для актуального законодательства
- [ ] **Step 5:** PDF generation (pdfkit): генерация готовых документов
- [ ] **Step 6:** Approval: ВСЕГДА перед отправкой документа
- [ ] **Step 7:** Тест: загрузить договор → спросить вопрос → агент отвечает из документа
- [ ] **Step 8:** Commit

### Task 3.2: Sales Agent

**Files:**
- Create: `backend/src/agents/sales.ts`
- Create: `backend/src/tools/notion.ts`

- [ ] **Step 1:** Sales agent: system prompt (продажи, ведение лидов, быстрые ответы)
- [ ] **Step 2:** Notion API client: CRUD по database (create page, update properties, query)
- [ ] **Step 3:** Tools:
  - `create_lead` — создать лид в Notion CRM
  - `update_lead_status` — обновить статус (новый/в работе/закрыт)
  - `generate_response` — сгенерировать ответ клиенту
  - `send_proposal` — подготовить КП (approval required)
- [ ] **Step 4:** Тест
- [ ] **Step 5:** Commit

### Task 3.3: SMM Agent

**Files:**
- Create: `backend/src/agents/smm.ts`

- [ ] **Step 1:** SMM agent: system prompt (SMM, тренды, креатив, аналитика)
- [ ] **Step 2:** Tools:
  - `analyze_trends` — OpenRouter web_search по трендам
  - `write_post` — генерация текста поста с хэштегами
  - `create_visual` — генерация изображения через OpenRouter (Gemini Flash Image)
  - `create_reel` — генерация видео через OpenRouter (Veo 3.1)
  - `schedule_post` — подготовка поста к публикации (approval required)
- [ ] **Step 3:** Agent output sanitization: проверка контента перед отправкой в approval
  - Нет оскорбительного контента
  - Нет prompt injection в тексте поста
  - Хэштеги валидны
- [ ] **Step 4:** Тест
- [ ] **Step 5:** Commit

### Task 3.4: Flutter Settings Screens

**Files:**
- Create: `flutter_app/lib/features/settings/agents/agent_list_screen.dart`
- Create: `flutter_app/lib/features/settings/agents/agent_edit_screen.dart`
- Create: `flutter_app/lib/features/settings/profile/profile_screen.dart`

- [ ] **Step 1:** Agent list: карточки с toggle on/off, agent color, last active
- [ ] **Step 2:** Agent edit: system prompt (multiline), model dropdown (из OpenRouter models), temperature slider, tool toggles
- [ ] **Step 3:** Profile: name, email, push toggles (сообщения / approvals), biometrics toggle, logout
- [ ] **Step 4:** Tab bar: Chat / Tasks / Settings
- [ ] **Step 5:** Commit

**Milestone Phase 3:** Все 5 агентов работают. Юрист отвечает по документам. Sales ведёт лиды в Notion. SMM генерирует контент с картинками и видео. Единый OpenRouter для всего.

---

## Phase 4 — External Integrations (5 недель)

### Task 4.1: Webhook Security Layer

**Files:**
- Create: `backend/src/lib/webhook-verify.ts`
- Create: `backend/src/routes/webhooks.ts`

- [ ] **Step 1:** HMAC-SHA256 verification для Meta webhooks (X-Hub-Signature-256)
- [ ] **Step 2:** API key verification для 360dialog
- [ ] **Step 3:** Replay protection: timestamp check (окно ≤5 мин) + event ID в Redis с TTL
- [ ] **Step 4:** Rate limiting: 50 webhook events/min
- [ ] **Step 5:** Commit

### Task 4.2: WhatsApp Integration (360dialog)

**Files:**
- Create: `backend/src/tools/whatsapp.ts`

- [ ] **Step 1:** Webhook handler: `POST /webhooks/whatsapp` → parse message → create thread message → trigger Sales agent
- [ ] **Step 2:** Outgoing: `send_whatsapp_message` tool (POST to 360dialog API)
- [ ] **Step 3:** Media support: отправка/получение изображений и документов
- [ ] **Step 4:** Approval: перед отправкой КП или договора
- [ ] **Step 5:** Push notification: "Новый лид от +7 777..."
- [ ] **Step 6:** Тест с 360dialog sandbox
- [ ] **Step 7:** Commit

### Task 4.3: Instagram Graph API

**Files:**
- Create: `backend/src/tools/instagram.ts`

- [ ] **Step 1:** Instagram API client: publish image/carousel/reel, read DMs, read/reply comments
- [ ] **Step 2:** Webhook: `POST /webhooks/instagram`:
  - Incoming DM → Sales agent
  - New comment → SMM agent
- [ ] **Step 3:** SMM tools: `post_to_instagram`, `reply_to_comment` (approval required)
- [ ] **Step 4:** Long-lived token refresh mechanism (tokens expire every 60 days)
- [ ] **Step 5:** Тест с Meta sandbox
- [ ] **Step 6:** **Подать заявку на Meta App Review** (2-4 недели ожидания)
- [ ] **Step 7:** Commit

### Task 4.4: Threads API

**Files:**
- Create: `backend/src/tools/threads.ts`

- [ ] **Step 1:** Threads API client: create text post, create media post
- [ ] **Step 2:** SMM tool: `post_to_threads` (approval required)
- [ ] **Step 3:** Тест
- [ ] **Step 4:** Commit

### Task 4.5: TikTok via Playwright

**Files:**
- Modify: `services/playwright/src/tiktok.ts`
- Create: `backend/src/tools/tiktok.ts`

- [ ] **Step 1:** Playwright TikTok automation:
  - Login session management (save/load cookies)
  - Auto-detect session expiry → push notification "Re-login needed"
  - Anti-bot: playwright-extra stealth, random delays 2-7s, human-like mouse movement
- [ ] **Step 2:** REST API endpoints в Playwright service:
  - `POST /api/tiktok/post` — upload video + caption + hashtags
  - `GET /api/tiktok/comments/:videoId` — scrape comments
  - `POST /api/tiktok/scrape-profile` — competitor analysis
- [ ] **Step 3:** Backend tool `post_to_tiktok`: вызывает Playwright service REST API
- [ ] **Step 4:** Safe limits: max 3-5 постов/день, max 15-30 действий/час
- [ ] **Step 5:** Fallback: если сессия expired и Owner не re-login → manual mode (agent готовит контент, Owner публикует сам)
- [ ] **Step 6:** Commit

### Task 4.6: Playwright — Мониторинг и скрейпинг

**Files:**
- Modify: `services/playwright/src/monitoring.ts`
- Create: `backend/src/workers/monitoring.ts`

- [ ] **Step 1:** Скрейпинг комментариев TikTok (BullMQ repeatable job, каждые 30 мин)
- [ ] **Step 2:** Competitor analysis: профиль stats, последние посты, engagement rate
- [ ] **Step 3:** Proxy rotation support (env variable PROXY_LIST)
- [ ] **Step 4:** Error handling: если layout изменился → log error + alert, не crash
- [ ] **Step 5:** Resource management: закрывать browser context после каждой задачи (освобождение RAM)
- [ ] **Step 6:** Commit

### Task 4.7: Flutter Integrations Screen

**Files:**
- Create: `flutter_app/lib/features/settings/integrations/integrations_screen.dart`
- Create: `flutter_app/lib/features/settings/integrations/integration_setup_screen.dart`
- Create: `flutter_app/lib/features/settings/integrations/tiktok_login_screen.dart`

- [ ] **Step 1:** Integration cards: WhatsApp, Instagram, TikTok, Threads, OpenRouter, Notion
- [ ] **Step 2:** Status badge: Connected / Not Connected / Session Expired
- [ ] **Step 3:** Credential setup: form + "Test Connection"
- [ ] **Step 4:** TikTok special: кнопка "Login via Browser" → открывает noVNC URL (localhost:6080) → Owner логинится → session saved → status "Connected"
- [ ] **Step 5:** Commit

**Milestone Phase 4:** Агенты публикуют в Instagram, отвечают в WhatsApp, постят в Threads и TikTok. Всё через Approval Gate. Webhook'и защищены.

---

## Phase 5 — Desktop Admin + Polish (3 недели)

### Task 5.1: Desktop Admin Shell

**Files:**
- Create: `flutter_app/lib/features/desktop/desktop_shell.dart`
- Create: `flutter_app/lib/features/desktop/sidebar.dart`

- [ ] **Step 1:** Responsive layout: sidebar (Threads, Approvals, Agent Monitor, Tool Logs, Integrations, Settings)
- [ ] **Step 2:** Desktop: three-column layout (sidebar + thread list + chat)
- [ ] **Step 3:** Reuse mobile screens с desktop adaptations
- [ ] **Step 4:** Commit

### Task 5.2: Agent Monitor (Desktop only)

**Files:**
- Create: `flutter_app/lib/features/desktop/agent_monitor_screen.dart`
- Create: `backend/src/routes/analytics.ts`

- [ ] **Step 1:** Backend: `GET /agents/monitor` — real-time status всех агентов + stats
- [ ] **Step 2:** Dashboard: agent cards с live status, calls/day chart, pending approvals badge
- [ ] **Step 3:** Commit

### Task 5.3: Tool Logs Viewer (Desktop only)

**Files:**
- Create: `flutter_app/lib/features/desktop/tool_logs_screen.dart`

- [ ] **Step 1:** Table: timestamp, agent, tool, status, duration
- [ ] **Step 2:** Filters: agent, tool, status, date range
- [ ] **Step 3:** Detail drawer: JSON input/output
- [ ] **Step 4:** CSV export
- [ ] **Step 5:** Commit

### Task 5.4: Audit Log API + UI

**Files:**
- Create: `backend/src/routes/audit.ts`

- [ ] **Step 1:** `GET /audit-log?actor=&action=&from=&to=&cursor=`
- [ ] **Step 2:** Desktop screen: table с фильтрами
- [ ] **Step 3:** Commit

### Task 5.5: Production Hardening

- [ ] **Step 1:** Sentry: error tracking (backend + Flutter)
- [ ] **Step 2:** PostgreSQL backups: `pg_dump` через `docker exec`, cron каждые 24 часа, 7 дней retention, хранение на отдельном диске
- [ ] **Step 3:** MinIO backup: `mc mirror` на external storage
- [ ] **Step 4:** Docker log rotation: проверить что max-size/max-file стоят на всех сервисах
- [ ] **Step 5:** Load test: 10 concurrent WS connections + 5 agents parallel
- [ ] **Step 6:** Security checklist:
  - [ ] Input validation на всех routes
  - [ ] SQL injection: проверить что Drizzle ORM параметризует все запросы
  - [ ] XSS: sanitize agent output перед отдачей клиенту
  - [ ] Webhook signatures: все проверяются
  - [ ] Secrets: нет hardcoded credentials в коде
  - [ ] Docker networks: API не имеет прямого доступа к Playwright
  - [ ] noVNC: только localhost + password
  - [ ] File upload: UUID names, magic bytes check, size limit
- [ ] **Step 7:** SSL: Let's Encrypt через certbot + auto-renewal (если внешний доступ)
- [ ] **Step 8:** Windows Firewall: только 80/443 open
- [ ] **Step 9:** Commit

**Milestone Phase 5:** Production-ready. Мониторинг, бекапы, error tracking, security audit пройден.

---

## Timeline Summary

| Phase | Duration | Cumulative | Backend | Flutter |
|-------|----------|-----------|---------|---------|
| 0 — Foundation | 1 нед | 1 нед | Docker, Fastify, DB, Playwright skeleton | Flutter setup |
| 1 — Auth + Chat | 3 нед | 4 нед | Auth, API, WS, files, security | Auth UI, chat, push |
| 2 — Orchestrator | 3 нед | 7 нед | OpenRouter client, agents, approval | Approval UI, streaming |
| 3 — All Agents | 4 нед | 11 нед | Lawyer+RAG, Sales, SMM | Settings screens |
| 4 — Integrations | 5 нед | 16 нед | WhatsApp, Instagram, Threads, TikTok, Playwright | Integrations UI |
| 5 — Polish | 3 нед | 19 нед | Monitoring, audit, security | Desktop admin |

**Total: ~19-20 недель (1 Backend + 1 Flutter разработчик параллельно)**
**С буфером (Meta review, баги, edge cases): 22-24 недели**

---

## Risk Register

| Риск | Impact | Likelihood | Митигация |
|------|--------|------------|-----------|
| Prompt injection через user input | Critical | Высокая | Двойная защита: системный промпт с границами + output filter перед действием |
| Публикация галлюцинаций в соцсети | Critical | Средняя | Mandatory Approval Gate, content safety classifier |
| WSL2 OOM при параллельных агентах | High | Средняя | .wslconfig limit, mem_limit на контейнеры, agent concurrency=3 |
| TikTok session expired без re-login | Medium | Высокая | Auto-detect + push notification, fallback to manual mode |
| Meta App Review rejection/delay | Medium | Средняя | Подать заявку в начале Phase 3, dev с sandbox |
| Playwright anti-bot blocking | Medium | Средняя | Stealth plugin, proxy rotation, human-like delays, safe rate limits |
| Docker Desktop performance на Windows | Medium | Средняя | Named volumes only, код в WSL-fs, polling для file watchers |
| PostgreSQL data corruption (WSL shutdown) | High | Низкая | fsync=on (default), named volumes, daily pg_dump backups |
| OpenRouter rate limits / downtime | Medium | Низкая | Exponential backoff, provider.order fallback, модели-дублёры |
| Кража refresh token | Critical | Низкая | httpOnly cookie, token family rotation, отзыв цепочки при reuse |
| Поддельные webhooks | Critical | Низкая | HMAC-SHA256 verify, timestamp check, event ID dedup in Redis |
| Docker disk space exhaustion | Medium | Средняя | Log rotation, periodic `docker system prune`, мониторинг |

---

## RAM Budget (Docker на Windows, 16GB total)

| Компонент | RAM |
|-----------|-----|
| Windows 11 | 3.5 GB |
| WSL2 + Docker Desktop | 1.5 GB |
| PostgreSQL | 0.5 GB (shared_buffers=256MB) |
| Redis | 0.2 GB (maxmemory=200MB) |
| MinIO | 0.2 GB |
| Node.js API | 0.5 GB |
| Node.js Agent Worker (3 concurrent) | 0.75 GB |
| Playwright + Chromium | 1-1.5 GB |
| nginx | 0.05 GB |
| **Итого** | **~8.5-9 GB** |
| **Свободно** | **~7 GB** (запас для пиков) |
