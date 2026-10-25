import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import OpenAI from 'openai';
import {
  SharedCollectionAddedNews,
} from '../../shared-collections/schemas/shared-collection-added-news.schema';
import { NewsArticle, NewsArticleDocument } from '../schemas/news-article.schema';

@Injectable()
export class SummaryService {
  private openai: OpenAI;

  constructor(
    @InjectModel(NewsArticle.name)
    private readonly newsArticleModel: Model<NewsArticleDocument>,
      @InjectModel(SharedCollectionAddedNews.name)
  private readonly addedNewsModel: Model<SharedCollectionAddedNews>,
  ) {
    this.openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });
  }

  // ─── Algorithm 4: ENABLE_AI_SUMMARY_FOR_ARTICLE ──────────────────────────────
async enableAiSummaryForArticle(newsId: string) {
  try {
    const newsObjId = new Types.ObjectId(newsId);

    const articleDoc = await this.newsArticleModel
      .findOne({ _id: newsObjId })
      .exec();

    if (!articleDoc) {
      return { success: false, summaryText: '' };
    }

    // 1) If original news article already has summary,
    // sync it to all added-news copies and return it.
    if (articleDoc.summaryText && articleDoc.summaryText.trim() !== '') {
      const existingSummary = articleDoc.summaryText.trim();

      await this.addedNewsModel.updateMany(
        { originalNewsId: newsObjId },
        { $set: { summaryText: existingSummary } },
      );

      return { success: true, summaryText: existingSummary };
    }

    // 2) If the original article does not have summary,
    // check if any added-news copy already has one.
    const addedNewsWithSummary = await this.addedNewsModel
      .findOne({
        originalNewsId: newsObjId,
        summaryText: { $exists: true, $ne: '' },
      })
      .select('summaryText')
      .lean();

    if (addedNewsWithSummary?.summaryText?.trim()) {
      const existingSummary = addedNewsWithSummary.summaryText.trim();

      // Copy from added news back to original news article.
      await this.newsArticleModel.findOneAndUpdate(
        { _id: newsObjId },
        { $set: { summaryText: existingSummary } },
      );

      // Also sync all other added-news copies.
      await this.addedNewsModel.updateMany(
        { originalNewsId: newsObjId },
        { $set: { summaryText: existingSummary } },
      );

      return { success: true, summaryText: existingSummary };
    }

    // 3) If no summary exists anywhere, generate it.
    const rawText = this.buildSummaryInput(
      articleDoc.newsTitle,
      articleDoc.newsContent,
    );

    const aiSummary = await this.generateSummaryViaAi(rawText);

    const finalSummary = this.postProcessSummaryText(aiSummary);

    if (!finalSummary.trim()) {
      return { success: false, summaryText: '' };
    }

    // 4) Save generated summary into original news article.
    await this.newsArticleModel.findOneAndUpdate(
      { _id: newsObjId },
      { $set: { summaryText: finalSummary } },
    );

    // 5) Save generated summary into all added-news copies.
    await this.addedNewsModel.updateMany(
      { originalNewsId: newsObjId },
      { $set: { summaryText: finalSummary } },
    );

    return { success: true, summaryText: finalSummary };
  } catch (error) {
    return { success: false, summaryText: '' };
  }
}

  // ─── Private Helpers ─────────────────────────────────────────────────────────

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
Return a short factual summary in Arabic.`
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