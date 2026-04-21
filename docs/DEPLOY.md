# AgentTeam — Deployment & Setup Notes

Рабочий конспект из сессии 2026-04-21. Держит контекст для разворачивания на
другой машине (мак как домашний сервер).

---

## 1. Быстрый dev-подъём после `git clone`

```bash
cp .env.example .env            # затем заполнить секреты (см. §3)

# Инфра в Docker (postgres + redis + minio, dev-overlay)
docker compose -f docker-compose.yml -f docker-compose.dev.yml \
  up -d postgres redis minio

# Backend + worker (две разные терминалки)
cd backend
npm install
npm run db:migrate
npm run db:seed                 # seed-ит 3-х founders + конфиги агентов
npm run dev                     # API на :3000
npm run worker:dev              # BullMQ worker

# Flutter web (отдельная терминалка)
cd flutter_app
flutter pub get
flutter run -d chrome --web-port 8090 \
  --dart-define=API_BASE_URL=http://localhost:3000
```

Если env-переменные из `.env` не подтягиваются в `npm run dev` (файл лежит в
корне, а не в `backend/`) — прокидывать их inline перед командой. `.env`
использует docker-имена (`postgres`, `redis`, `minio`); для локального запуска
вне контейнера нужны хост-имена (`localhost:5434`, `localhost:6380`,
`localhost:9000`).

---

## 2. 3 founders (Owner role)

- Batyr — batyr@cannect.ai
- Farkhat — farkhat@cannect.ai
- Nurlan — nurlan@cannect.ai

Регистрация первого пользователя проходит без токена (см. `/auth/register`
logic: `isFirstUser`). Последующие регистрации требуют Owner-JWT.

---

## 3. Ключевые env-переменные

```dotenv
JWT_SECRET=<openssl rand -hex 32>
JWT_ACCESS_TTL=180d              # продлили с 15m на полгода
JWT_REFRESH_TTL=180d             # продлили с 30d

CREDENTIALS_ENCRYPTION_KEY=<openssl rand -hex 32>   # AES-256-GCM ключ для БД-кредов
OPENROUTER_API_KEY=sk-or-...

CORS_ORIGINS=http://localhost:8090,http://localhost:3000   # плюс прод-домен
```

`CREDENTIALS_ENCRYPTION_KEY` **нельзя менять** после того, как в БД появились
зашифрованные креды интеграций — иначе расшифровка упадёт и интеграции слетят.
Бэкапить вместе с БД.

---

## 4. WhatsApp — Green API (не 360Dialog)

Миграция с 360Dialog завершена (коммит `3a71f7c`). Используется Green API.

### Шаги подключения

1. **Регистрация**: `https://green-api.com` (или `green-api.com.kz`), создать
   инстанс (бесплатный Developer-тариф подходит для теста).
2. **Креды инстанса**:
   - `idInstance` (например, `1101234567`)
   - `apiTokenInstance` (hex-строка)
3. **Авторизация инстанса**: отсканировать QR из кабинета Green API в
   WhatsApp → Linked devices. Состояние должно стать `authorized`.
4. **В приложении**: `Settings → Integrations → WhatsApp → Add account`,
   вставить `idInstance` + `apiTokenInstance`. Кнопка Test должна вернуть
   `stateInstance: authorized`. Мульти-аккаунт работает (несколько номеров).
5. **Webhook URL** в кабинете Green API:
   `https://<ваш-домен>/webhooks/whatsapp`
   Включить `incomingMessageReceived`.

### Как бэкенд различает аккаунты

HMAC-подписи у Green API нет. В payload приходит `instanceData.idInstance`,
по которому backend находит нужные креды в БД
(`backend/src/routes/webhooks.ts` → `getAllWhatsAppAccounts`).

---

## 5. Деплой мака как домашнего сервера

В репозитории уже есть `docker-compose.yml` (прод) и `nginx/nginx.conf`.
Текущий `nginx.conf` проксирует только API на `:80` (без TLS, без статики
Flutter).

### Что донастроить перед выходом в сеть

- **Flutter web сборка** для отдачи через nginx:
  ```bash
  cd flutter_app
  flutter build web --dart-define=API_BASE_URL=https://<домен>
  ```
  В nginx добавить `root /usr/share/nginx/html;` + маунт
  `./flutter_app/build/web:/usr/share/nginx/html:ro`. API перенести на
  `location /api/` чтобы не пересекалось со статикой.
- **Mac как сервер**:
  - System Settings → Lock Screen → "Turn display off" = Never
  - `caffeinate -d` в фоне (чтобы не уходил в сон)
  - DHCP reservation на роутере → фиксированный локальный IP
  - Firewall разрешить 80/443 (и 22 если нужен SSH)

### Вариант А — Cloudflare Tunnel (проще, рекомендуется)

Не нужен проброс портов, статический IP, покупка SSL. Работает за серым IP и
NAT.

```bash
brew install cloudflared
cloudflared tunnel login
cloudflared tunnel create mecca
cloudflared tunnel route dns mecca app.example.com
```

`~/.cloudflared/config.yml`:
```yaml
tunnel: <UUID из create>
credentials-file: /Users/batyrbekkuandyk/.cloudflared/<UUID>.json
ingress:
  - hostname: app.example.com
    service: http://localhost:80
  - service: http_status:404
```

```bash
sudo cloudflared service install   # запуск как launchd-сервис
```

TLS делает Cloudflare. Webhook URL для Green API:
`https://app.example.com/webhooks/whatsapp`.

**Требования**: домен (можно купить в CF за ~$10) на Cloudflare DNS.

### Вариант Б — прямой проброс портов + Let's Encrypt

1. Домен, A-запись → публичный IP (DuckDNS/No-IP если IP динамический).
2. На роутере: `80 → mac:80`, `443 → mac:443`.
3. Добавить certbot в `docker-compose.yml`, webroot-challenge через nginx.
4. Получить серт:
   ```bash
   docker compose run --rm certbot certonly --webroot \
     -w /var/www/certbot -d app.example.com
   ```
5. Cron на `certbot renew`.

Минусы: провайдер может резать 80/443 (частое у домашних тарифов);
серый/CGNAT IP → не заработает.

---

## 6. Недавние изменения в коде (контекст)

Последовательность коммитов:

- `3a71f7c` — Green API вместо 360Dialog (новый клиент, webhook identifies by
  idInstance, Flutter поля `idInstance` / `apiTokenInstance`)
- `8169252` — JWT TTL 180d, 401 → редирект на /login (через
  `appContainer.invalidate(authStateProvider)`), router на `refreshListenable`
  (чтобы GoRouter не пересоздавался и не было GlobalKey-конфликтов),
  main chat и login переведены на design tokens из `AppTheme`, акцентный цвет
  сменён с фиолетового `#7B61FF` на красный `#FF000B`.

Важно: `AppTheme.accentPrimary` = `#FF000B` теперь визуально близок к
`AppTheme.error` = `#DC2626`. Если понадобится разделить — менять один из них.

---

## 7. Команды, чтобы всё остановить

```bash
# backend + worker + flutter web
pkill -f "tsx watch.*backend/src/app"
pkill -f "tsx watch.*agent-runner"
lsof -ti :8090 | xargs -r kill -9

# инфра
docker compose down
```
