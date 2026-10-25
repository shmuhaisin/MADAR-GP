// src/modules/semantic-notifications/semantic-notifications.service.ts
import { Injectable, ConflictException, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { SemanticNotification } from './schemas/semantic-notification.schema';
import { EmbeddingService } from './providers/embedding.service';

@Injectable()
export class SemanticNotificationsService {
  constructor(
    @InjectModel(SemanticNotification.name)
    private readonly semNotifModel: Model<SemanticNotification>,
    private readonly embeddingService: EmbeddingService,
  ) {}


  private buildEmbeddingText(interest: string, keyword: string): string {
    return [
      'Semantic notification:',
      `Topic: ${interest}`,
      `Keyword: ${keyword}`,
      `User intent: notify me about news related to "${keyword}" within ${interest}.`,
    ].join('\n');
  }

  async getAll(userId: string) {
    const _userId = new Types.ObjectId(userId);

    const docs = await this.semNotifModel
      .find({ userId: _userId })
      .select('-SNEmbedding') 
      .sort({ Interest: 1, keyword: 1 })
      .lean();

    const grouped: Record<string, string[]> = {};
    for (const doc of docs) {
      const interest = (doc as any).Interest;
      if (!grouped[interest]) grouped[interest] = [];
      grouped[interest].push((doc as any).keyword);
    }

    return {
      message: 'تم جلب الإشعارات الدلالية',
      semanticNotifications: grouped,
    };
  }

  async create(userId: string, interest: string, keyword: string) {
    const _userId = new Types.ObjectId(userId);
    const trimmed = keyword.trim();

    // Generate embedding BEFORE insert.
    const embeddingText = this.buildEmbeddingText(interest, trimmed);
    const vector = await this.embeddingService.generateEmbedding(embeddingText);

    try {
      const doc = await this.semNotifModel.create({
        userId: _userId,
        Interest: interest,
        keyword: trimmed,
        SNEmbedding: vector,
        SNEmbeddingModel: this.embeddingService.getModel(),
      });

      return {
        message: 'تم إنشاء الإشعار الدلالي',
        semanticNotification: {
          id: doc._id,
          interest: doc.Interest,
          keyword: doc.keyword,
         
        },
      };
    } catch (e: any) {
      if (e?.code === 11000) {
        throw new ConflictException(
          'هذه الكلمة الدلالية موجودة مسبقاً لنفس الاهتمام',
        );
      }
      throw e;
    }
  }

  async delete(userId: string, interest: string, keyword: string) {
    const _userId = new Types.ObjectId(userId);

    const result = await this.semNotifModel.deleteOne({
      userId: _userId,
      Interest: interest,
      keyword: keyword.trim(),
    });

    if (result.deletedCount === 0) {
      throw new NotFoundException('الإشعار الدلالي غير موجود');
    }

    return { message: 'تم حذف الإشعار الدلالي' };
  }
}