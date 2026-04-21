import { logger } from '../lib/logger.js';

// ── Types ─────────────────────────────────────────────────────────────

export interface ParsedWhatsAppMessage {
  from: string; // phone number without @c.us (e.g. "77001234567")
  name?: string;
  messageId: string;
  type: 'text' | 'image' | 'document' | 'audio' | 'video';
  text?: string;
  mediaUrl?: string;
  timestamp: Date;
  idInstance: string; // Green API instance that received the message
}

// ── Green API WhatsApp client ─────────────────────────────────────────
//
// Docs: https://green-api.com/en/docs/
// Send text:   POST https://api.green-api.com/waInstance{idInstance}/sendMessage/{apiTokenInstance}
// Send file:   POST https://api.green-api.com/waInstance{idInstance}/sendFileByUrl/{apiTokenInstance}
// Status:      GET  https://api.green-api.com/waInstance{idInstance}/getStateInstance/{apiTokenInstance}

const BASE_URL = 'https://api.green-api.com';

export class WhatsAppClient {
  constructor(
    private idInstance: string,
    private apiTokenInstance: string,
  ) {}

  // Convert "77001234567" → "77001234567@c.us" (Green API chat format).
  private static toChatId(to: string): string {
    const clean = to.replace(/\D/g, '');
    return clean.includes('@') ? to : `${clean}@c.us`;
  }

  private urlFor(method: string): string {
    return `${BASE_URL}/waInstance${this.idInstance}/${method}/${this.apiTokenInstance}`;
  }

  async sendMessage(
    to: string,
    text: string,
  ): Promise<{ messageId: string }> {
    const body = {
      chatId: WhatsAppClient.toChatId(to),
      message: text,
    };

    const res = await fetch(this.urlFor('sendMessage'), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const detail = await res.text();
      logger.error({ status: res.status, detail }, 'WhatsApp sendMessage failed');
      throw new Error(`Green API error ${res.status}: ${detail}`);
    }

    const data = (await res.json()) as { idMessage?: string };
    if (!data.idMessage) {
      throw new Error('Green API did not return idMessage');
    }
    return { messageId: data.idMessage };
  }

  async sendMedia(
    to: string,
    mediaUrl: string,
    type: 'image' | 'document',
    caption?: string,
  ): Promise<{ messageId: string }> {
    const fileName = mediaUrl.split('/').pop() ?? (type === 'image' ? 'image.jpg' : 'document.pdf');

    const body: Record<string, string> = {
      chatId: WhatsAppClient.toChatId(to),
      urlFile: mediaUrl,
      fileName,
    };
    if (caption) body.caption = caption;

    const res = await fetch(this.urlFor('sendFileByUrl'), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const detail = await res.text();
      logger.error({ status: res.status, detail }, 'WhatsApp sendMedia failed');
      throw new Error(`Green API error ${res.status}: ${detail}`);
    }

    const data = (await res.json()) as { idMessage?: string };
    if (!data.idMessage) throw new Error('Green API did not return idMessage');
    return { messageId: data.idMessage };
  }

  // ── Parse an incoming Green API webhook payload ───────────────────
  //
  // Reference payload (typeWebhook: incomingMessageReceived):
  // {
  //   typeWebhook: "incomingMessageReceived",
  //   instanceData: { idInstance: 123, wid: "...@c.us" },
  //   timestamp: 1712345678,
  //   idMessage: "ABCDEF",
  //   senderData: { chatId: "7700...@c.us", sender: "...@c.us", senderName: "Name" },
  //   messageData: {
  //     typeMessage: "textMessage" | "extendedTextMessage" | "imageMessage" | ...,
  //     textMessageData?: { textMessage: "..." },
  //     extendedTextMessageData?: { text: "..." },
  //     fileMessageData?: { downloadUrl, caption, fileName, mimeType }
  //   }
  // }
  static parseIncoming(body: unknown): ParsedWhatsAppMessage | null {
    try {
      const root = body as Record<string, unknown>;
      if (root.typeWebhook !== 'incomingMessageReceived') return null;

      const instanceData = root.instanceData as Record<string, unknown> | undefined;
      const idInstance = instanceData?.idInstance != null
        ? String(instanceData.idInstance)
        : '';

      const senderData = root.senderData as Record<string, unknown> | undefined;
      const chatId = senderData?.chatId as string | undefined;
      const senderName = senderData?.senderName as string | undefined;
      if (!chatId) return null;

      // chatId = "77001234567@c.us" → take the digits before "@"
      const from = chatId.split('@')[0] ?? '';

      const messageData = root.messageData as Record<string, unknown> | undefined;
      const typeMessage = messageData?.typeMessage as string | undefined;
      if (!messageData || !typeMessage) return null;

      let parsedType: ParsedWhatsAppMessage['type'] = 'text';
      let text: string | undefined;
      let mediaUrl: string | undefined;

      if (typeMessage === 'textMessage') {
        const d = messageData.textMessageData as Record<string, unknown> | undefined;
        text = d?.textMessage as string | undefined;
      } else if (typeMessage === 'extendedTextMessage') {
        const d = messageData.extendedTextMessageData as Record<string, unknown> | undefined;
        text = d?.text as string | undefined;
      } else if (
        typeMessage === 'imageMessage' ||
        typeMessage === 'videoMessage' ||
        typeMessage === 'documentMessage' ||
        typeMessage === 'audioMessage'
      ) {
        const d = messageData.fileMessageData as Record<string, unknown> | undefined;
        mediaUrl = d?.downloadUrl as string | undefined;
        text = d?.caption as string | undefined;
        if (typeMessage === 'imageMessage') parsedType = 'image';
        else if (typeMessage === 'videoMessage') parsedType = 'video';
        else if (typeMessage === 'documentMessage') parsedType = 'document';
        else if (typeMessage === 'audioMessage') parsedType = 'audio';
      } else {
        return null;
      }

      const idMessage = root.idMessage as string | undefined;
      const timestampSec = root.timestamp as number | undefined;

      return {
        from,
        name: senderName,
        messageId: idMessage ?? `${idInstance}-${timestampSec ?? Date.now()}`,
        type: parsedType,
        text,
        mediaUrl,
        timestamp: new Date((timestampSec ?? Math.floor(Date.now() / 1000)) * 1000),
        idInstance,
      };
    } catch (err) {
      logger.warn({ err }, 'Failed to parse incoming WhatsApp message');
      return null;
    }
  }
}
