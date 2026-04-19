# AgentTeam — Product Specification

## Overview
AgentTeam is an internal AI agent management platform for **CANNECT.AI**. Five specialized AI agents (Orchestrator, Lawyer, Content, SMM, Sales) communicate in a unified chat interface. All public-facing actions go through an **Approval Gate** — owners review and approve before anything is published or sent externally.

**Platform:** Flutter (iOS + Web + Desktop) + Node.js/Fastify backend
**AI Provider:** OpenRouter (supports Claude, Gemini, and other models)

---

## User Roles

| Role | Permissions |
|------|-------------|
| **Owner** | Full access: manage agents, integrations, approve/reject tasks, delete threads, register users |
| **Admin** | Read/write access to threads and messages (approval restricted) |
| **Viewer** | Read-only access |

There are 3 founders (all Owner role): Batyr, Farkhat, Nurlan.

---

## Screens & Navigation

### Shell Layout
- **Mobile (<800px):** Bottom navigation bar with 3 tabs
- **Desktop (>=800px):** Side navigation rail
- **Extended desktop (>=1100px):** Expanded rail with labels
- **Tabs:** Chat (single unified chat), Approvals, Settings

---

### 1. Login Screen
**Route:** `/login`

- Email + password form with validation
- "CANNECT.AI" branding
- Password visibility toggle
- Loading indicator during authentication
- Error messages via SnackBar
- Redirects to `/threads` on success

---

### 2. Chat — Single Unified Chat
**Route:** `/` (default screen)

- Single chat thread where all agents share context
- Auto-loads or creates the main thread on first launch
- **Agent Status Bar:** Horizontal scrollable chips showing online agents with colored dots
- **Message List:** Reverse-scrolling list with pagination (loads 20 messages at a time)
  - User messages: right-aligned, dark surface color
  - Agent messages: left-aligned, with agent avatar (colored circle + initial), agent name label
  - File attachments shown as preview chips (images thumbnail, PDF/doc icon)
  - Long-press user message → delete option
- **Typing Indicator:** Shows which agent is currently "thinking" with animated dots
- **Input Area:**
  - Multi-line text field with "Message agents..." placeholder
  - Attachment button (paperclip icon) → file picker supporting:
    - Images (jpg, png, gif, webp)
    - Documents (pdf, doc, docx, txt)
    - Spreadsheets (xlsx, csv)
    - Video (mp4, avi)
  - Attached files shown as removable chips above input
  - Send button (arrow icon), disabled while sending
- **@Mention System:**
  - Typing `@` opens agent picker popup (overlay)
  - Shows all active agents with colored icons
  - Selecting agent inserts `@agentname ` into text field
  - Deleting `@` character closes the popup
- **File size limit:** 10MB per file, up to 5 files per message

---

### 3. Approvals — List
**Route:** `/approvals`

- **Filter Chips:** All, Pending, Approved, Rejected (horizontal scroll)
- **Approval Cards:** Each card shows:
  - Left color stripe matching agent color
  - Agent icon (circle avatar with initial)
  - Agent name
  - Action type label (e.g., "generated_image", "post_social_media", "generate_contract")
  - Payload preview (first 2 lines of text content)
  - Status badge: Pending (amber), Approved (green), Rejected (red)
  - Timestamp
  - Quick action buttons for pending items: Approve (green), Reject (red)
- Pull-to-refresh
- Tap card → opens Approval Detail

---

### 4. Approvals — Detail
**Route:** `/approvals/{id}`

- **Header:** Agent avatar + name with colored background
- **Details Card:**
  - Status (with colored badge)
  - Action Type
  - Agent Name
  - Notes (if any)
- **Content Section:**
  - Text content (selectable, copyable)
  - Image preview (supports base64 data URLs and HTTP URLs)
  - All payload key-value pairs displayed
- **Timeline Section:**
  - Requested: timestamp
  - Resolved: timestamp + method (approved/rejected/modified)
- **Action Bar (for pending items):**
  - Notes text field (optional, for reject/modify reason)
  - Three buttons:
    - **Reject** (outlined, red) — with confirmation dialog
    - **Modify** (outlined, amber) — updates payload with notes
    - **Approve** (filled, green) — with confirmation dialog

---

### 5. Settings — Main
**Route:** `/settings`

- **Configuration Section:**
  - Agents → Agent management screen
  - Integrations → External service connections
- **Account Section:**
  - Profile → User profile and preferences

---

### 6. Settings — Agent List
**Route:** `/settings/agents`

- Lists all 5 agents (Orchestrator, Content, Lawyer, Sales, SMM)
- Each card shows:
  - Colored dot indicator
  - Agent display name
  - Current model (e.g., "anthropic/claude-sonnet-4-5")
  - Active/Inactive badge
  - Toggle switch to enable/disable agent
- Tap card → opens Agent Edit screen

---

### 7. Settings — Agent Edit
**Route:** `/settings/agents/{slug}`

- **Header:** Agent icon + name with agent color
- **Form Fields:**
  - System Prompt: multi-line text area (8 lines visible)
  - Model: dropdown selector (Opus, Sonnet, Haiku)
  - Temperature: slider (0.0 — 1.0) with current value display
  - Tools: list of available tools with toggle switches
- **Save Button:** in AppBar and at bottom of form
- Loading state during save, auto-navigates back on success

---

### 8. Settings — Integrations
**Route:** `/settings/integrations`

- **Available Services:**

| Service | Type | Credential Fields | Icon |
|---------|------|-------------------|------|
| OpenRouter | Single-account | `apiKey` | Smart Toy |
| WhatsApp | Multi-account | `apiKey` (per account) | Chat |
| Instagram | Single-account | `accessToken`, `accountId` | Camera |
| TikTok | Single-account | `username`, `password` | Video Library |
| Threads | Single-account | `accessToken`, `userId` | Forum |
| Notion | Single-account | `integrationToken`, `databaseId` | Book |

- **Single-Account Card:**
  - Service icon + name
  - Connected/Disconnected badge
  - Tap → bottom sheet with credential form
  - "Test Connection" button
  - "Save Credentials" button
  - Secret fields masked with `obscureText`

- **Multi-Account Card (WhatsApp):**
  - Service icon + name + account count
  - "Add Account" button (+ icon)
  - List of existing accounts with:
    - Account label (e.g., "Mecca Cola Almaty")
    - Edit (pencil icon) → bottom sheet with label + credentials
    - Test (play icon) → connection test
    - Delete (trash icon) → confirmation dialog

---

### 9. Settings — Profile
**Route:** `/settings/profile`

- **User Avatar:** Large circle with initials, colored background
- **User Info:** Name, email, role badge (OWNER/ADMIN/VIEWER)
- **Preferences:**
  - Push Notifications toggle
  - Biometric Login toggle
- **Logout Button:** Red outlined button with confirmation dialog
- Navigates to login screen on logout

---

## AI Agents

### Orchestrator
**Slug:** `orchestrator`
**Role:** Message router — analyzes user intent and delegates to specialist agents.

- Detects `@mentions` in messages (e.g., `@content create a post`)
- If mention found → routes directly without LLM call
- If no mention → LLM decides which agent to invoke
- **Tool:** `route_to_agent(agent, task_summary)` — enqueues job for specialist

---

### Content Agent
**Slug:** `content`
**Role:** Content creation — plans, scripts, images, videos.

**Tools:**
| Tool | Parameters | Description |
|------|-----------|-------------|
| `generate_content_plan` | topic, period (week/month), platforms[] | Creates content calendar |
| `write_script` | topic, format (reels/tiktok/post/story), duration_seconds? | Generates script/caption |
| `generate_image` | prompt, aspect_ratio? | AI image generation (Gemini 3 Pro) |
| `generate_video` | prompt, duration? | AI video generation (Veo 3.1) |

- All generated content goes through Approval Gate
- Image model: `google/gemini-3-pro-image-preview`
- Video model: `google/veo-3.1`

---

### Lawyer Agent
**Slug:** `lawyer`
**Role:** Legal counsel — document search, risk analysis, contract drafting.

**Tools:**
| Tool | Parameters | Description |
|------|-----------|-------------|
| `search_documents` | query, limit? | Semantic search over uploaded docs (RAG with pgvector) |
| `check_legal_risks` | text | Analyzes text for legal/compliance issues |
| `generate_contract` | title, type (contract/nda/agreement), parties[], body | Creates legal document |

- Uses vector embeddings (pgvector 1536d) for document search
- Contract generation requires approval before finalization

---

### Sales Agent
**Slug:** `sales`
**Role:** CRM management — leads, proposals, outreach.

**Tools:**
| Tool | Parameters | Description |
|------|-----------|-------------|
| `create_lead` | name, phone?, email?, source (whatsapp/instagram/manual), notes? | Creates lead in Notion CRM |
| `update_lead_status` | leadId, status (new/in_progress/proposal_sent/closed_won/closed_lost), notes? | Updates lead status |
| `generate_proposal` | leadId, product?, price?, terms? | Creates sales proposal |
| `send_email` | to, subject, body | Sends email response |

- Integrates with Notion as CRM database
- Proposals go through Approval Gate

---

### SMM Agent
**Slug:** `smm`
**Role:** Social media management — trends, posts, visuals.

**Tools:**
| Tool | Parameters | Description |
|------|-----------|-------------|
| `analyze_trends` | topic, platform? (instagram/tiktok/threads/twitter/youtube) | Trend research |
| `write_post` | topic, platform (instagram/tiktok/threads), tone? | Generates caption + hashtags |
| `create_visual` | description, style?, aspect_ratio? | AI image creation (Gemini 3 Pro) |
| `schedule_post` | platform, content, mediaUrl?, scheduledTime? | Queues post for approval |

- Auto-adjusts aspect ratio per platform (9:16 for stories/reels, 1:1 for feed, 16:9 for YouTube)
- All posts require approval before publishing

---

## Approval Gate Workflow

```
Agent generates content
       ↓
Creates approval_task (status: pending)
       ↓
Appears in Approvals tab (real-time via Redis Pub/Sub)
       ↓
Owner reviews content (text, image, video)
       ↓
  ┌─────────┬──────────┬──────────┐
  │ Approve │  Modify  │  Reject  │
  │ (green) │ (amber)  │  (red)   │
  └─────────┴──────────┴──────────┘
       ↓          ↓          ↓
  Execute    Update &    Notify
  action     re-queue    agent
```

**Action Types:**
- `generated_image` — AI-generated image for review
- `generated_video` — AI-generated video for review
- `post_social_media` — Social media post draft
- `generate_contract` — Legal document draft
- `generate_proposal` — Sales proposal draft
- `send_email` — Email draft

---

## External Integrations

### OpenRouter (LLM Provider)
- Single API key for all AI models
- Supports: Claude (Opus/Sonnet/Haiku), Gemini (image/video generation)
- Model selection per agent via config

### WhatsApp (360Dialog)
- Multi-account support (multiple phone numbers)
- Send/receive text messages
- Send images and documents
- Webhook verification via HMAC-SHA256
- API: `https://waba.360dialog.io/v1`

### Instagram (Meta Graph API v19.0)
- Publish: feed posts, stories, carousels, reels
- Read/reply comments
- Direct messages
- Token refresh (60-day long-lived tokens)
- Requires: Instagram Business Account + Facebook Page

### TikTok (Playwright Automation)
- Video publishing via browser automation
- Account analytics
- Scheduled posting
- Runs in Docker container (Playwright Service)

### Threads (Meta Graph API)
- Text and image posts
- Feed reading, likes, replies
- API: `https://graph.threads.net/v1.0`

### Notion (CRM)
- Lead management database
- CRUD operations on leads
- Status tracking pipeline

---

## Real-Time Communication

- **WebSocket** connection per thread for live message updates
- **Redis Pub/Sub** channels:
  - `thread:{id}:messages` — new messages broadcast
  - `thread:{id}:approvals` — approval events
  - `agent:status:{slug}` — agent thinking/idle status
- **Polling fallback:** Flutter polls `/threads/{id}/messages` every few seconds
- **Typing indicators:** Agent "thinking" state shown with animated dots

---

## File Management

- **Upload:** Via multipart form to `/files/upload`
- **Storage:** MinIO (S3-compatible object storage)
- **Access:** Presigned URLs with 5-minute expiry
- **Size limit:** 10MB per file, 5 files per message
- **Supported formats:**
  - Images: jpg, jpeg, png, gif, webp
  - Documents: pdf, doc, docx, txt
  - Spreadsheets: xlsx, csv
  - Video: mp4, avi

---

## Database Schema

### Core Tables
| Table | Purpose |
|-------|---------|
| `users` | User accounts (email, name, role, password hash) |
| `sessions` | Refresh token storage with rotation & theft detection |
| `threads` | Chat conversations |
| `messages` | Chat messages (user + agent), with metadata (files, tool calls) |
| `approval_tasks` | Agent action approvals with flexible JSON payload |
| `agent_configs` | Per-agent configuration (prompt, model, temperature, tools) |
| `integrations` | External service credentials (AES-256-GCM encrypted) |
| `files` | File upload metadata + MinIO storage paths |
| `tool_logs` | Agent tool call execution logs (input, output, duration, status) |
| `audit_log` | Access audit trail (actor, action, resource, IP) |
| `document_chunks` | RAG embeddings for Lawyer agent (pgvector 1536d) |

---

## Security

- **Authentication:** JWT access tokens + HttpOnly refresh token cookies
- **Token Rotation:** Refresh token family tracking with theft detection
- **Password Storage:** bcrypt with salt
- **Credential Encryption:** AES-256-GCM for all integration API keys
- **File Access:** Presigned URLs (5-min expiry), no direct MinIO access
- **Rate Limiting:** 1000 req/min API, 100 msg/min WebSocket
- **CORS:** Configurable allowed origins
- **Helmet:** Security headers (XSS, HSTS, etc.)

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) — iOS, Web, Desktop |
| Backend | Node.js 20 / Fastify / TypeScript |
| ORM | Drizzle ORM |
| Database | PostgreSQL 16 + pgvector |
| Queue | BullMQ + Redis 7 |
| File Storage | MinIO (S3-compatible) |
| AI | OpenRouter (Claude, Gemini, Veo) |
| Real-time | WebSocket + Redis Pub/Sub |
| Auth | JWT + bcrypt + AES-256-GCM |
| Infra | Docker Compose |
