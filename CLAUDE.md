# AgentTeam — Developer Guide

## Project Overview
Internal AI agent management platform for CANNECT.AI. 5 AI agents (Orchestrator, Lawyer, Content, SMM, Sales) communicate in a unified chat, all public actions go through Approval Gate.

## Tech Stack
- **Backend:** Node.js 20 / Fastify / TypeScript / Drizzle ORM
- **Database:** PostgreSQL 16 + pgvector
- **Queue:** BullMQ + Redis 7
- **Files:** MinIO (S3-compatible)
- **AI:** OpenRouter (single provider for text, images, video)
- **Frontend:** Flutter (iOS + Desktop) — separate repo
- **Infra:** Docker Compose on Windows 11 + WSL2

## Quick Start
```bash
cp .env.example .env  # fill in values
docker compose -f docker-compose.yml -f docker-compose.dev.yml up
# API: http://localhost:3000
# MinIO Console: http://localhost:9001
# noVNC (Playwright): http://localhost:6080
```

## Project Structure
```
backend/src/
├── agents/        # AI agent classes (base, orchestrator, lawyer, content, smm, sales)
├── db/            # Drizzle schema + seed
├── lib/           # Shared utilities (openrouter, jwt, crypto, rag, pubsub, audit)
├── plugins/       # Fastify plugins (db, redis, minio, ws, auth)
├── routes/        # API routes (auth, threads, messages, approvals, agents, etc.)
├── tools/         # External service clients (whatsapp, instagram, threads, tiktok, notion)
├── workers/       # BullMQ workers (agent-runner)
└── app.ts         # Entry point
```

## Key Commands
```bash
cd backend
npm run dev          # Start API with hot reload
npm run worker:dev   # Start agent worker with hot reload
npm run db:generate  # Generate Drizzle migrations
npm run db:migrate   # Run migrations
npm run db:seed      # Seed founders + agent configs
npm run typecheck    # TypeScript check
npm run test         # Run tests
```

## Conventions
- TypeScript strict mode, ESM modules
- Drizzle ORM for all DB queries, raw SQL only for pgvector operations
- @sinclair/typebox for route validation schemas
- pino for structured JSON logging
- All agent actions that affect external systems must go through Approval Queue
- Credentials stored AES-256-GCM encrypted in DB, key from env

## 3 Founders (all Owner role)
- Batyr (batyr@cannect.ai)
- Farkhat (farkhat@cannect.ai)
- Nurlan (nurlan@cannect.ai)
