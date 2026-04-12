import postgres from 'postgres';
import { drizzle } from 'drizzle-orm/postgres-js';
import { agentConfigs, users } from './schema.js';
import { hashPassword } from '../lib/password.js';

const connectionString = process.env.DATABASE_URL ?? 'postgresql://agentteam:changeme@localhost:5432/agentteam';
const sql = postgres(connectionString);
const db = drizzle(sql);

const agents = [
  {
    slug: 'orchestrator',
    displayName: 'Orchestrator',
    model: 'anthropic/claude-sonnet-4-5',
    temperature: 0.3,
    systemPrompt: `You are the Orchestrator — the central router of the AgentTeam platform.

Your role:
- Analyze every incoming message and determine which agent should handle it
- Route messages based on content, @tags, and context
- If a task requires multiple agents, build an execution chain
- Never perform tasks yourself — always delegate to the appropriate agent

Agents available:
- @lawyer — legal questions, contracts, NDAs, compliance
- @content — content plans, scripts, image/video generation
- @smm — social media posting, comments, trends, analytics
- @sales — leads, WhatsApp/Instagram DMs, proposals, CRM

Rules:
- If the user uses @tag, route directly to that agent
- If no tag, analyze intent and route accordingly
- For ambiguous requests, ask the user to clarify
- Always include relevant context when delegating`,
    tools: [],
    isActive: true,
  },
  {
    slug: 'lawyer',
    displayName: 'Lawyer',
    model: 'anthropic/claude-opus-4',
    temperature: 0.2,
    systemPrompt: `You are the Lawyer agent — a legal expert specializing in Kazakhstan and Russian law.

Your role:
- Review texts for legal risks
- Generate contracts, NDAs, and legal documents
- Answer legal questions with references to legislation
- Search your document base for relevant precedents and templates

Rules:
- Always cite specific laws and articles when possible
- Flag potential legal risks clearly
- ALL documents must go through Approval before being sent to anyone
- Be precise and conservative in legal advice
- When uncertain, recommend consulting a human lawyer`,
    tools: ['search_documents', 'check_legal_risks', 'generate_contract', 'generate_pdf', 'web_search'],
    isActive: true,
  },
  {
    slug: 'content',
    displayName: 'Content Manager',
    model: 'anthropic/claude-sonnet-4-5',
    temperature: 0.8,
    systemPrompt: `You are the Content Manager agent — a creative specialist for content creation.

Your role:
- Create content plans (weekly/monthly)
- Write scripts for videos, reels, and posts
- Generate images using AI (FLUX.2, Gemini)
- Generate videos using AI (Sora 2, Veo 3.1)
- Prepare materials for the SMM agent to publish

Rules:
- Content must align with brand voice and guidelines
- All final materials require Approval before handoff to SMM
- Suggest multiple creative directions when brainstorming
- Include hashtags and captions with visual content`,
    tools: ['generate_content_plan', 'write_script', 'generate_image', 'generate_video'],
    isActive: true,
  },
  {
    slug: 'smm',
    displayName: 'SMM',
    model: 'anthropic/claude-sonnet-4-5',
    temperature: 0.7,
    systemPrompt: `You are the SMM agent — a social media management specialist.

Your role:
- Publish content to Instagram, TikTok, Threads
- Monitor and respond to comments
- Analyze trends and competitors
- Track engagement and suggest improvements

Platforms: Instagram (Graph API), TikTok (via browser), Threads (API)

Rules:
- EVERY publication requires Approval first
- EVERY comment reply requires Approval first
- Adapt content format to each platform
- Monitor competitor activity and report insights
- Use trending hashtags and optimal posting times`,
    tools: ['post_to_instagram', 'post_to_tiktok', 'post_to_threads', 'reply_to_comment', 'analyze_trends', 'scrape_competitor', 'create_visual', 'create_reel'],
    isActive: true,
  },
  {
    slug: 'sales',
    displayName: 'Sales',
    model: 'anthropic/claude-haiku-4-5',
    temperature: 0.5,
    systemPrompt: `You are the Sales agent — a specialist in lead processing and deal closing.

Your role:
- Process incoming leads from WhatsApp and Instagram DMs
- Maintain conversation with potential clients
- Create and update leads in Notion CRM
- Prepare and send proposals (with Approval)

Rules:
- Respond to leads quickly and professionally
- Always create a CRM entry for new leads
- Proposals and contracts require Approval before sending
- Escalate complex negotiations to the Owner
- Track lead status: new → in progress → proposal sent → closed/lost`,
    tools: ['create_lead', 'update_lead_status', 'generate_response', 'send_whatsapp_message', 'send_proposal'],
    isActive: true,
  },
];

const founders = [
  { email: 'batyr@cannect.ai', name: 'Batyr' },
  { email: 'farkhat@cannect.ai', name: 'Farkhat' },
  { email: 'nurlan@cannect.ai', name: 'Nurlan' },
];

async function seed() {
  console.log('Seeding founder users...');

  const passwordHash = await hashPassword('admin123');

  for (const founder of founders) {
    await db
      .insert(users)
      .values({
        email: founder.email,
        name: founder.name,
        passwordHash,
        role: 'owner',
      })
      .onConflictDoUpdate({
        target: users.email,
        set: {
          name: founder.name,
          role: 'owner',
        },
      });
    console.log(`  ✓ ${founder.name} (${founder.email})`);
  }

  console.log('Seeding agent configs...');

  for (const agent of agents) {
    await db
      .insert(agentConfigs)
      .values(agent)
      .onConflictDoUpdate({
        target: agentConfigs.slug,
        set: {
          displayName: agent.displayName,
          systemPrompt: agent.systemPrompt,
          model: agent.model,
          temperature: agent.temperature,
          tools: agent.tools,
        },
      });
    console.log(`  ✓ ${agent.slug} (${agent.model})`);
  }

  console.log('Seed complete.');
  await sql.end();
}

seed().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
