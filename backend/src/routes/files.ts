import type { FastifyInstance } from 'fastify';
import { Type, type Static } from '@sinclair/typebox';
import { eq } from 'drizzle-orm';
import { files } from '../db/schema.js';
import { NotFoundError, ValidationError } from '../lib/errors.js';
import { nanoid } from 'nanoid';
import path from 'node:path';

const BUCKET = process.env.MINIO_BUCKET ?? 'agentteam-files';
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB

// Allowed MIME types (validated by magic bytes in the multipart parser)
const ALLOWED_MIME_TYPES = new Set([
  // Images
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp',
  'image/svg+xml',
  // Documents
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  // Spreadsheets
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'text/csv',
  // Text
  'text/plain',
  // Video
  'video/mp4',
  'video/quicktime',
  'video/x-msvideo',
  // Fallback for browser quirks
  'application/octet-stream',
]);

const FileIdParams = Type.Object({
  id: Type.String({ format: 'uuid' }),
});
type FileIdParams = Static<typeof FileIdParams>;

export default async function fileRoutes(fastify: FastifyInstance) {
  // ----- POST /files/upload -----
  fastify.post(
    '/upload',
    { preHandler: [fastify.authenticate] },
    async (request, reply) => {
      const data = await request.file();
      if (!data) throw new ValidationError('No file uploaded');

      const { mimetype, filename: originalName } = data;

      if (!ALLOWED_MIME_TYPES.has(mimetype)) {
        throw new ValidationError(`File type "${mimetype}" is not allowed`);
      }

      // Read file into buffer (respects the 10MB multipart limit)
      const chunks: Buffer[] = [];
      let totalSize = 0;

      for await (const chunk of data.file) {
        totalSize += chunk.length;
        if (totalSize > MAX_FILE_SIZE) {
          throw new ValidationError('File exceeds 10MB limit');
        }
        chunks.push(chunk as Buffer);
      }

      const buffer = Buffer.concat(chunks);

      // Generate UUID-based stored name (prevents path traversal)
      const ext = path.extname(originalName);
      const storedName = `${nanoid(32)}${ext}`;
      const storagePath = `uploads/${storedName}`;

      // Upload to MinIO
      await fastify.minio.putObject(BUCKET, storagePath, buffer, buffer.length, {
        'Content-Type': mimetype,
      });

      // Get thread_id from query if provided
      const threadId = (request.query as Record<string, string>).threadId ?? null;

      // Save metadata to DB
      const [file] = await fastify.db
        .insert(files)
        .values({
          originalName,
          storedName,
          mimeType: mimetype,
          sizeBytes: buffer.length,
          storagePath,
          uploadedBy: request.user.id,
          threadId,
        })
        .returning();

      return reply.status(201).send({
        id: file!.id,
        originalName: file!.originalName,
        mimeType: file!.mimeType,
        sizeBytes: file!.sizeBytes,
        createdAt: file!.createdAt,
      });
    },
  );

  // ----- GET /files/:id -----
  fastify.get<{ Params: FileIdParams }>(
    '/:id',
    {
      preHandler: [fastify.authenticate],
      schema: { params: FileIdParams },
    },
    async (request, reply) => {
      const { id } = request.params;

      const [file] = await fastify.db
        .select()
        .from(files)
        .where(eq(files.id, id))
        .limit(1);

      if (!file) throw new NotFoundError('File');

      // Generate presigned URL (valid for 5 minutes)
      const presignedUrl = await fastify.minio.presignedGetObject(
        BUCKET,
        file.storagePath,
        300, // 5 min in seconds
      ) as unknown as string;

      return reply.redirect(presignedUrl);
    },
  );
}
