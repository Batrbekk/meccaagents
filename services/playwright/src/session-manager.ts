import fs from 'node:fs';
import path from 'node:path';

export interface SessionInfo {
  platform: string;
  exists: boolean;
  lastModified: Date | null;
  sizeBytes: number;
}

export class SessionManager {
  constructor(private sessionsDir: string) {
    if (!fs.existsSync(sessionsDir)) {
      fs.mkdirSync(sessionsDir, { recursive: true });
    }
  }

  private sessionPath(platform: string): string {
    // Sanitize platform name to prevent path traversal
    const safe = platform.replace(/[^a-z0-9_-]/gi, '');
    return path.join(this.sessionsDir, `${safe}.json`);
  }

  async listSessions(): Promise<SessionInfo[]> {
    const platforms = ['tiktok', 'instagram', 'threads'];
    return platforms.map((platform) => {
      const filePath = this.sessionPath(platform);
      const exists = fs.existsSync(filePath);
      let lastModified: Date | null = null;
      let sizeBytes = 0;

      if (exists) {
        const stats = fs.statSync(filePath);
        lastModified = stats.mtime;
        sizeBytes = stats.size;
      }

      return { platform, exists, lastModified, sizeBytes };
    });
  }

  async isSessionValid(platform: string): Promise<boolean> {
    const filePath = this.sessionPath(platform);
    if (!fs.existsSync(filePath)) return false;

    try {
      const raw = fs.readFileSync(filePath, 'utf8');
      const data = JSON.parse(raw);

      // Check if session has cookies
      if (!data.cookies || data.cookies.length === 0) return false;

      // Check if any cookies are expired
      const now = Date.now() / 1000;
      const hasValidCookies = data.cookies.some(
        (c: { expires: number }) => c.expires === -1 || c.expires > now,
      );

      return hasValidCookies;
    } catch {
      return false;
    }
  }

  async saveCurrentSession(_platform: string): Promise<void> {
    // This will be called after the user logs in via noVNC
    // The actual browser context's storageState() output should be
    // written to the session file by the automation code
    // For now, this is a placeholder
    console.log(`Session save requested for ${_platform}`);
  }

  async loadSession(platform: string): Promise<object | null> {
    const filePath = this.sessionPath(platform);
    if (!fs.existsSync(filePath)) return null;

    try {
      const raw = fs.readFileSync(filePath, 'utf8');
      return JSON.parse(raw);
    } catch {
      return null;
    }
  }
}
