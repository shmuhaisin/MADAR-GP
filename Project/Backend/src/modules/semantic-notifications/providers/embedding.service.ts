import { Injectable, InternalServerErrorException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import OpenAI from 'openai';

/**
 * Purpose: Centralized OpenAI embedding generation.
 * Flow: any service needing embeddings injects this and calls generateEmbedding(text).
 * 
 */
@Injectable()
export class EmbeddingService {
  private readonly logger = new Logger(EmbeddingService.name);
  private readonly client: OpenAI;
  private readonly model = 'text-embedding-3-small';

  constructor(config: ConfigService) {
    const apiKey = config.getOrThrow<string>('OPENAI_API_KEY');
    this.client = new OpenAI({ apiKey });
  }

  /**
   * Generate an embedding vector for the given text.
   * @param input — semantic text to embed (already-built, not raw fields)
   * @returns 1536-dim vector for text-embedding-3-small
   */
  async generateEmbedding(input: string): Promise<number[]> {
    const text = (input ?? '').trim();
    if (!text) {
      throw new InternalServerErrorException('Cannot embed empty text');
    }

    try {
      const res = await this.client.embeddings.create({
        model: this.model,
        input: text.slice(0, 24000), 
      });

      const vector = res.data?.[0]?.embedding;
      if (!Array.isArray(vector) || vector.length === 0) {
        throw new Error('OpenAI returned empty embedding');
      }

     
      this.logger.debug(
        `Embedding generated. model=${this.model} dims=${vector.length} chars=${text.length}`,
      );

      return vector;
    } catch (e: any) {
  
      this.logger.error(`Embedding failed: ${e?.message ?? 'unknown error'}`);
      throw new InternalServerErrorException('فشل توليد المتجه الدلالي');
    }
  }

  getModel(): string {
    return this.model;
  }
}