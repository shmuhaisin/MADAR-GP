import {
  Injectable,
  NotFoundException,
  InternalServerErrorException,
  BadRequestException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';

import { NewsArticle, NewsArticleDocument } from './schemas/news-article.schema';
import { NewsReported, NewsReportedDocument } from './schemas/news-reported.schema';
import { User } from '../users/schemas/user.schema';

import { IngestNewsArticleDto } from './dto/ingest-news-article.dto';
import { QueryNewsDto } from './dto/query-news.dto';
import {
  SharedCollectionAddedNews,
  SharedCollectionAddedNewsDocument,
} from '../shared-collections/schemas/shared-collection-added-news.schema';
import { SummaryService } from './providers/summary.service';
import { NewsAudioService } from './providers/news-audio.service';
import { BlobStorageService } from './providers/blob-storage.service';

@Injectable()
export class NewsService {
  private readonly REPORT_DELETE_THRESHOLD = 20;

  constructor(
    @InjectModel(NewsArticle.name)
    private readonly newsArticleModel: Model<NewsArticleDocument>,

    @InjectModel(NewsReported.name)
    private readonly newsReportedModel: Model<NewsReportedDocument>,

    @InjectModel(User.name)
    private readonly userModel: Model<User>,
    @InjectModel(SharedCollectionAddedNews.name)
    private readonly addedNewsModel: Model<SharedCollectionAddedNewsDocument>,
    private readonly summaryService: SummaryService,
    private readonly newsAudioService: NewsAudioService,
    private readonly blobStorageService: BlobStorageService,
  ) {}

  async ingest(dto: IngestNewsArticleDto) {
    try {
      const created = await this.newsArticleModel.create({
        ...dto,
        publishDate: new Date(dto.publishDate),
      });
      return { news: created };
    } catch (e: any) {
      if (e?.code === 11000) {
        return { status: 'duplicate', message: 'هذا الخبر موجود مسبقًا' };
      }
      throw e;
    }
  }

  async getFeed(query: QueryNewsDto, userId: string) {
    const { category, page = 1, limit = 10 } = query;

    if (!Types.ObjectId.isValid(userId)) {
      throw new NotFoundException('المستخدم غير موجود');
    }

    const userObjectId = new Types.ObjectId(userId);

    const user = await this.userModel
      .findById(userObjectId)
      .select({ interests: 1 })
      .lean();

    if (!user) throw new NotFoundException('المستخدم غير موجود');

    const userInterests: string[] = Array.isArray((user as any).interests)
      ? (user as any).interests
      : [];

    if (userInterests.length === 0) {
      throw new NotFoundException('لا توجد اهتمامات للمستخدم');
    }

    const reportedDocs = await this.newsReportedModel
      .find({ reportedByUserId: userObjectId })
      .select({ newsId: 1, _id: 0 })
      .lean();

    const reportedIds = reportedDocs.map((d) => d.newsId);

    const filter: any = {};

    if (category) {
      if (!userInterests.includes(category)) {
        throw new NotFoundException('التصنيف غير مسموح لهذا المستخدم');
      }
      filter.category = category;
    } else {
      filter.category = { $in: userInterests };
    }

    if (reportedIds.length > 0) filter._id = { $nin: reportedIds };

    const skip = (page - 1) * limit;

    const projection = {
      newsTitle: 1,
      newsSource: 1,
      sourceLink: 1,
      category: 1,
      publishDate: 1,
      reportsCount: 1,
      _id: 1,
      newsContent: 1,
      summaryText: 1,
      ttsAudioURLforContent: 1,
      ttsAudioURLforSummary: 1,
    };

    const [items, total] = await Promise.all([
      this.newsArticleModel
        .find(filter)
        .select(projection)
        .sort({ publishDate: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      this.newsArticleModel.countDocuments(filter),
    ]);

    return { page, limit, total, items };
  }

  async getById(id: string) {
    if (!Types.ObjectId.isValid(id)) {
      throw new NotFoundException('الخبر غير موجود');
    }

    const oid = new Types.ObjectId(id);
    const doc = await this.newsArticleModel.findOne({ _id: oid }).lean();

    if (!doc) throw new NotFoundException('الخبر غير موجود');

    return { news: doc };
  }

  async getSummary(newsId: string) {
    if (!Types.ObjectId.isValid(newsId)) {
      throw new NotFoundException('الخبر غير موجود');
    }

    const { success, summaryText } =
      await this.summaryService.enableAiSummaryForArticle(newsId);

    if (!success) throw new InternalServerErrorException('تعذر توليد الملخص');

    return { summaryText };
  }

async getOrCreateAudioUrl(
  newsId: string,
  mode: 'summary' | 'full' = 'full',
) {
  try {
    if (!Types.ObjectId.isValid(newsId)) {
      throw new NotFoundException('الخبر غير موجود');
    }

    const oid = new Types.ObjectId(newsId);
    const article = await this.newsArticleModel.findOne({ _id: oid });

    if (!article) {
      throw new NotFoundException('الخبر غير موجود');
    }

    const audioField =
      mode === 'summary'
        ? 'ttsAudioURLforSummary'
        : 'ttsAudioURLforContent';

    if (mode === 'summary') {
      if (!article.summaryText?.trim()) {
        const { success, summaryText } =
          await this.summaryService.enableAiSummaryForArticle(newsId);

        if (!success || !summaryText?.trim()) {
          throw new BadRequestException('تعذر توليد ملخص لهذا الخبر');
        }

        article.summaryText = summaryText.trim();
        await article.save();

        await this.addedNewsModel.updateMany(
          { originalNewsId: oid },
          { $set: { summaryText: article.summaryText } },
        );
      }

      if (article.ttsAudioURLforSummary?.trim()) {
        await this.addedNewsModel.updateMany(
          { originalNewsId: oid },
          {
            $set: {
              ttsAudioURLforSummary: article.ttsAudioURLforSummary,
              summaryText: article.summaryText ?? '',
            },
          },
        );

        const url = await this.blobStorageService.generateReadSasUrl(
          article.ttsAudioURLforSummary,
        );

        return {
          url,
          news: article.toObject(),
        };
      }

      const audioBuffer = await this.newsAudioService.generateAudio(
        article.summaryText,
      );

      const blobUrl = await this.blobStorageService.uploadAudio(
        audioBuffer,
        `news/${article._id.toString()}/summary.mp3`,
      );

      article.ttsAudioURLforSummary = blobUrl;
      await article.save();

      await this.addedNewsModel.updateMany(
        { originalNewsId: oid },
        {
          $set: {
            ttsAudioURLforSummary: blobUrl,
            summaryText: article.summaryText ?? '',
          },
        },
      );

      const url = await this.blobStorageService.generateReadSasUrl(blobUrl);

      return {
        url,
        news: article.toObject(),
      };
    }

    if (!article.newsContent?.trim()) {
      throw new BadRequestException('لا يوجد محتوى صوتي لهذا الخبر');
    }

    if (article.ttsAudioURLforContent?.trim()) {
      await this.addedNewsModel.updateMany(
        { originalNewsId: oid },
        {
          $set: {
            ttsAudioURLforContent: article.ttsAudioURLforContent,
          },
        },
      );

      const url = await this.blobStorageService.generateReadSasUrl(
        article.ttsAudioURLforContent,
      );

      return {
        url,
        news: article.toObject(),
      };
    }

    const audioBuffer = await this.newsAudioService.generateLongAudio(
      article.newsContent,
    );

    const blobUrl = await this.blobStorageService.uploadAudio(
      audioBuffer,
      `news/${article._id.toString()}/content.mp3`,
    );

    article.ttsAudioURLforContent = blobUrl;
    await article.save();

    await this.addedNewsModel.updateMany(
      { originalNewsId: oid },
      {
        $set: {
          ttsAudioURLforContent: blobUrl,
        },
      },
    );

    const url = await this.blobStorageService.generateReadSasUrl(blobUrl);

    return {
      url,
      news: article.toObject(),
    };
  } catch (error: any) {
    console.error('GET OR CREATE AUDIO ERROR =>', error);
    console.error(
      'GET OR CREATE AUDIO ERROR RESPONSE =>',
      error?.details || error?.message || error,
    );
    throw error;
  }
}



  async reportNews(newsId: string, userId: string) {
    if (!Types.ObjectId.isValid(newsId)) {
      throw new NotFoundException('الخبر غير موجود');
    }
    if (!Types.ObjectId.isValid(userId)) {
      throw new NotFoundException('المستخدم غير موجود');
    }

    const newsObjectId = new Types.ObjectId(newsId);
    const userObjectId = new Types.ObjectId(userId);

    const exists = await this.newsArticleModel.exists({ _id: newsObjectId });
    if (!exists) throw new NotFoundException('الخبر غير موجود');

    try {
      await this.newsReportedModel.create({
        newsId: newsObjectId,
        reportedByUserId: userObjectId,
      });
    } catch (e: any) {
      if (e?.code === 11000) {
        return { status: 'already_reported' };
      }
      throw e;
    }

    const updated = await this.newsArticleModel
      .findByIdAndUpdate(newsObjectId, { $inc: { reportsCount: 1 } }, { new: true })
      .lean();

    if (!updated) throw new NotFoundException('الخبر غير موجود');

    if ((updated.reportsCount ?? 0) >= this.REPORT_DELETE_THRESHOLD) {
      await Promise.all([
        this.newsArticleModel.deleteOne({ _id: newsObjectId }),
        this.newsReportedModel.deleteMany({ newsId: newsObjectId }),
      ]);

      return { status: 'deleted' };
    }

    return { status: 'reported', reportsCount: updated.reportsCount };
  }
}
