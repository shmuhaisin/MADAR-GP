import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import OpenAI from 'openai';
import { NewsArticle } from '../../news/schemas/news-article.schema';

import {
  SharedCollectionAddedNews,
  SharedCollectionAddedNewsDocument,
} from '../schemas/shared-collection-added-news.schema';

@Injectable()
export class AddedNewsSummaryService {
  private openai: OpenAI;

  constructor(
    @InjectModel(SharedCollectionAddedNews.name)
    private readonly addedNewsModel: Model<SharedCollectionAddedNewsDocument>,
      @InjectModel(NewsArticle.name)
  private readonly newsArticleModel: Model<NewsArticle>,
  ) {
    this.openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });
  }

  // ─── ENABLE_AI_SUMMARY_FOR_ADDED_NEWS ──────────────────────────────

  async enableAiSummaryForAddedNews(collectionId: string, addedNewsId: string) {
  try {
    const collectionObjId = new Types.ObjectId(collectionId);
    const addedNewsObjId = new Types.ObjectId(addedNewsId);

    const addedNewsDoc = await this.addedNewsModel
      .findOne({
        _id: addedNewsObjId,
        sharedCollectionId: collectionObjId,
      })
      .exec();

    if (!addedNewsDoc) {
      return { success: false, summaryText: '' };
    }

    if (addedNewsDoc.summaryText && addedNewsDoc.summaryText.trim() !== '') {
      return { success: true, summaryText: addedNewsDoc.summaryText };
    }

    const originalNewsId = addedNewsDoc.originalNewsId;

    const articleDoc = await this.newsArticleModel
      .findById(originalNewsId)
      .select('_id summaryText newsTitle newsContent')
      .exec();

    if (articleDoc?.summaryText && articleDoc.summaryText.trim() !== '') {
      const existingSummary = articleDoc.summaryText.trim();

      await this.addedNewsModel.updateMany(
        { originalNewsId },
        { $set: { summaryText: existingSummary } },
      );

      return { success: true, summaryText: existingSummary };
    }

    const rawText = this.buildSummaryInput(
      addedNewsDoc.newsTitle,
      addedNewsDoc.newsContent,
    );

    const aiSummary = await this.generateSummaryViaAi(rawText);
    const finalSummary = this.postProcessSummaryText(aiSummary);

    if (!finalSummary.trim()) {
      return { success: false, summaryText: '' };
    }

    await this.newsArticleModel.findByIdAndUpdate(
      originalNewsId,
      { $set: { summaryText: finalSummary } },
    );

    await this.addedNewsModel.updateMany(
      { originalNewsId },
      { $set: { summaryText: finalSummary } },
    );

    return { success: true, summaryText: finalSummary };
  } catch (error) {
    return { success: false, summaryText: '' };
  }
}

  // Private Helpers

  private buildSummaryInput(newsTitle: string, newsContent: string): string {
    return `Title: ${newsTitle}\n\nContent: ${newsContent}`;
  }

  private async generateSummaryViaAi(rawText: string): Promise<string> {
    const response = await this.openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: `You are a precise news summarizer.
Only use the information explicitly written in the provided article.
Do not add, guess, infer, or fabricate details.
If a detail is unclear or missing, leave it out.
Return a short factual summary in Arabic.`,
        },
        {
          role: 'user',
          content: `Summarize the following news article based only on the text provided. Use only facts from the article.
Do not add background information or analysis:\n\n${rawText}`,
        },
      ],
      max_tokens: 300,
      temperature: 0,
    });

    return response.choices[0].message.content?.trim() ?? '';
  }

  private postProcessSummaryText(aiSummary: string): string {
    if (!aiSummary) return '';
    return aiSummary.trim().replace(/\s+/g, ' ').replace(/^["']|["']$/g, '');
  }
}