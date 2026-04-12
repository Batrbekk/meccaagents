import { logger } from '../lib/logger.js';

// ── Types ─────────────────────────────────────────────────────────────

export interface ParsedWhatsAppMessage {
  from: string; // phone number (e.g. "77001234567")
  name?: string; // contact display name
  messageId: string;
  type: 'text' | 'image' | 'document' | 'audio' | 'video';
  text?: string;
  mediaUrl?: string;
  timestamp: Date;
}

interface SendResponse {
  messages: Array<{ id: string }>;
}

// ── 360dialog WhatsApp client ─────────────────────────────────────────

const BASE_URL = 'https://waba.360dialog.io/v1';

export class WhatsAppClient {
  constructor(private apiKey: string) {}

  // ── Send a plain text message ─────────────────────────────────────

  async sendMessage(
    to: string,
    text: string,
  ): Promise<{ messageId: string }> {
    const body = {
      messaging_product: 'whatsapp',
      to,
      type: 'text',
      text: { body: text },
    };

    const res = await fetch(`${BASE_URL}/messages`, {
      method: 'POST',
      headers: this.headers(),
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const detail = await res.text();
      logger.error({ status: res.status, detail }, 'WhatsApp sendMessage failed');
      throw new Error(`WhatsApp API error ${res.status}: ${detail}`);
    }

    const data = (await res.json()) as SendResponse;
    return { messageId: data.messages[0]!.id };
  }

  // ── Send a media message (image / document) ───────────────────────

  async sendMedia(
    to: string,
    mediaUrl: string,
    type: 'image' | 'document',
    caption?: string,
  ): Promise<{ messageId: string }> {
    const mediaPayload: Record<string, string> = { link: mediaUrl };
    if (caption) mediaPayload.caption = caption;

    const body = {
      messaging_product: 'whatsapp',
      to,
      type,
      [type]: mediaPayload,
    };

    const res = await fetch(`${BASE_URL}/messages`, {
      method: 'POST',
      headers: this.headers(),
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const detail = await res.text();
      logger.error({ status: res.status, detail }, 'WhatsApp sendMedia failed');
      throw new Error(`WhatsApp API error ${res.status}: ${detail}`);
    }

    const data = (await res.json()) as SendResponse;
    return { messageId: data.messages[0]!.id };
  }

  // ── Parse an incoming 360dialog webhook payload ───────────────────

  static parseIncoming(body: unknown): ParsedWhatsAppMessage | null {
    try {
      const root = body as Record<string, unknown>;

      // Cloud API / 360dialog wraps in `entry[].changes[].value`
      const entries = (root.entry ?? []) as Array<Record<string, unknown>>;
      if (entries.length === 0) return null;

      const changes = (entries[0]!.changes ?? []) as Array<Record<string, unknown>>;
      if (changes.length === 0) return null;

      const value = changes[0]!.value as Record<string, unknown> | undefined;
      if (!value) return null;

      const msgsArr = (value.messages ?? []) as Array<Record<string, unknown>>;
      if (msgsArr.length === 0) return null;

      const msg = msgsArr[0]!;

      // Extract contact name
      const contacts = (value.contacts ?? []) as Array<Record<string, unknown>>;
      const profile = contacts[0]?.profile as Record<string, unknown> | undefined;
      const name = profile?.name as string | undefined;

      const msgType = msg.type as string;

      let text: string | undefined;
      let mediaUrl: string | undefined;

      if (msgType === 'text') {
        const textObj = msg.text as Record<string, unknown> | undefined;
        text = textObj?.body as string | undefined;
      } else if (['image', 'document', 'audio', 'video'].includes(msgType)) {
        const mediaObj = msg[msgType] as Record<string, unknown> | undefined;
        mediaUrl = mediaObj?.url as string | undefined;
        // Some media messages also carry a caption
        text = mediaObj?.caption as string | undefined;
      }

      const validTypes = ['text', 'image', 'document', 'audio', 'video'] as const;
      const parsedType = validTypes.includes(msgType as typeof validTypes[number])
        ? (msgType as ParsedWhatsAppMessage['type'])
        : 'text';

      return {
        from: msg.from as string,
        name,
        messageId: msg.id as string,
        type: parsedType,
        text,
        mediaUrl,
        timestamp: new Date(Number(msg.timestamp as string) * 1000),
      };
    } catch (err) {
      logger.warn({ err }, 'Failed to parse incoming WhatsApp message');
      return null;
    }
  }

  // ── Private helpers ───────────────────────────────────────────────

  private headers(): Record<string, string> {
    return {
      'D360-API-KEY': this.apiKey,
      'Content-Type': 'application/json',
    };
  }
}
