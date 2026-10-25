import { Injectable, ConflictException, NotFoundException, BadRequestException,ForbiddenException,InternalServerErrorException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { SharedCollectionAddedNews } from '../schemas/shared-collection-added-news.schema';
import { NewsArticle } from '../../news/schemas/news-article.schema';
import { SharedCollection } from '../schemas/shared-collection.schema';
import { AddedNewsSummaryService } from '../providers/addedNewSummary.service';
import  {BlobStorageService} from '../../news/providers/blob-storage.service';
import {NewsAudioService} from '../../news/providers/news-audio.service';

@Injectable()
export class SharedCollectionArticlesService {
  constructor(
  @InjectModel(SharedCollectionAddedNews.name)
  private readonly addedNewsModel: Model<SharedCollectionAddedNews>,

  @InjectModel(NewsArticle.name)
  private readonly newsArticleModel: Model<NewsArticle>,

  @InjectModel(SharedCollection.name)
  private readonly collectionModel: Model<SharedCollection>,

  private readonly addedNewsSummaryService: AddedNewsSummaryService,
  private readonly blobStorageService: BlobStorageService,
  private readonly newsAudioService: NewsAudioService,
) {}

  async addArticleToCollection(collectionId: string, body: any, addedByUID: string) {
    const { originalNewsId } = body ?? {};

    if (!collectionId || !Types.ObjectId.isValid(collectionId)) {
      throw new BadRequestException('معرّف المجموعة غير صالح');
    }
    if (!originalNewsId || !Types.ObjectId.isValid(originalNewsId)) {
      throw new BadRequestException('معرّف الخبر الأصلي غير صالح');
    }
    if (!addedByUID || !Types.ObjectId.isValid(addedByUID)) {
      throw new BadRequestException('معرّف المستخدم غير صالح');
    }

    const sharedCollectionId = new Types.ObjectId(collectionId);
    const originalArticleId = new Types.ObjectId(originalNewsId);
    const addedByObjId = new Types.ObjectId(addedByUID);

    const collection = await this.collectionModel.findById(sharedCollectionId).lean();
    if (!collection) {
      throw new NotFoundException('لم يتم العثور على المجموعة المشتركة');
    }

    const originalArticle = await this.newsArticleModel.findById(originalArticleId).lean();
    if (!originalArticle) {
      throw new NotFoundException('لم يتم العثور على الخبر الأصلي');
    }

    try {
      const addedArticle = await this.addedNewsModel.create({
        sharedCollectionId,
        originalNewsId: originalArticleId,
        addedByUserId: addedByObjId,
        newsTitle: originalArticle.newsTitle,
        newsContent: originalArticle.newsContent,
        newsSource: originalArticle.newsSource ?? '',
        sourceLink: originalArticle.sourceLink ?? '',
        category: originalArticle.category ?? '',
        publishDate: originalArticle.publishDate,
        ttsAudioURLforContent: originalArticle.ttsAudioURLforContent ?? '',
        ttsAudioURLforSummary: originalArticle.ttsAudioURLforSummary ?? '',
        summaryText: originalArticle.summaryText ?? '',
        isArchived: false,
      });

      return {
        message: 'تمت إضافة الخبر إلى المجموعة بنجاح',
        addedNews: {
          id: addedArticle._id.toString(),
          sharedCollectionId: addedArticle.sharedCollectionId.toString(),
          originalNewsId: addedArticle.originalNewsId.toString(),
          addedByUID: addedArticle.addedByUserId.toString(),
          newsTitle: addedArticle.newsTitle,
          newsContent: addedArticle.newsContent,
          newsSource: addedArticle.newsSource,
          sourceLink: addedArticle.sourceLink,
          category: addedArticle.category,
          publishDate: addedArticle.publishDate,
          summaryText: addedArticle.summaryText,
          ttsAudioURLforContent: addedArticle.ttsAudioURLforContent,
          ttsAudioURLforSummary: addedArticle.ttsAudioURLforSummary,
          isArchived: addedArticle.isArchived,
        },
      };
    } catch (e: any) {
      if (e?.code === 11000) {
        throw new ConflictException('هذا الخبر موجود بالفعل في هذه المجموعة');
      }
      throw e;
    }
  }

 async archiveAddedNews(collectionId: string, addedNewsId: string, actorUID: string) {
    const { collectionObjId, addedNewsObjId, collection } =
        await this.validateOwnerAction(collectionId, addedNewsId, actorUID);

    const updated = await this.addedNewsModel
      .findOneAndUpdate(
        {
          _id: addedNewsObjId,
          sharedCollectionId: collectionObjId,
          isArchived: { $ne: true },
        },
        {
          $set: { isArchived: true },
        },
        { new: true },
      )
      .lean();

    if (!updated) {
      throw new NotFoundException('لم يتم العثور على الخبر أو أنه مؤرشف بالفعل');
    }

    return {
      message: 'تمت أرشفة الخبر بنجاح',
      addedNews: this.mapAddedNews(updated, collection.ownerId.toString(), actorUID),
    };
  }

  async restoreAddedNews(collectionId: string, addedNewsId: string, actorUID: string) {
    const { collectionObjId, addedNewsObjId, collection } =
        await this.validateOwnerAction(collectionId, addedNewsId, actorUID);

    const updated = await this.addedNewsModel
      .findOneAndUpdate(
        {
          _id: addedNewsObjId,
          sharedCollectionId: collectionObjId,
          isArchived: true,
        },
        {
          $set: { isArchived: false },
        },
        { new: true },
      )
      .lean();

    if (!updated) {
      throw new NotFoundException('لم يتم العثور على الخبر المؤرشف');
    }

    return {
      message: 'تمت استعادة الخبر بنجاح',
      addedNews: this.mapAddedNews(updated, collection.ownerId.toString(), actorUID),
    };
  }

  async getArchivedNews(collectionId: string, actorUID: string) {
    if (!collectionId || !Types.ObjectId.isValid(collectionId)) {
      throw new BadRequestException('معرّف المجموعة غير صالح');
    }
    if (!actorUID || !Types.ObjectId.isValid(actorUID)) {
      throw new BadRequestException('معرّف المستخدم غير صالح');
    }

    const collectionObjId = new Types.ObjectId(collectionId);

    const collection = await this.collectionModel
      .findById(collectionObjId)
      .select('_id ownerId')
      .lean();

    if (!collection) {
      throw new NotFoundException('لم يتم العثور على المجموعة المشتركة');
    }

    if (collection.ownerId.toString() != actorUID) {
      throw new ForbiddenException('فقط مالك المجموعة يستطيع عرض الأخبار المؤرشفة');
    }

    const archivedDocs = await this.addedNewsModel
      .find({
        sharedCollectionId: collectionObjId,
        isArchived: true,
      })
      .sort({ createdAt: -1 })
      .select('_id sharedCollectionId originalNewsId addedByUserId newsTitle newsContent newsSource sourceLink category publishDate ttsAudioURLforContent ttsAudioURLforSummary summaryText createdAt isArchived')
      .lean();

    return {
      message: 'تم جلب الأخبار المؤرشفة',
      archivedNews: archivedDocs.map((n: any) =>
        this.mapAddedNews(n, collection.ownerId.toString(), actorUID),
      ),
    };
  }

// SUMMARY
async getAddedNewsSummary(collectionId: string, addedNewsId: string) {
  if (!Types.ObjectId.isValid(collectionId) || !Types.ObjectId.isValid(addedNewsId)) {
    throw new NotFoundException('الخبر غير موجود');
  }

  const { success, summaryText } =
    await this.addedNewsSummaryService.enableAiSummaryForAddedNews(
      collectionId,
      addedNewsId,
    );

  if (!success) {
    throw new InternalServerErrorException('تعذر توليد الملخص');
  }

  return { summaryText };
}

async getOrCreateAddedNewsAudioUrl(
  collectionId: string,
  addedNewsId: string,
  mode: 'summary' | 'full' = 'full',
) {
  try {
    if (
      !Types.ObjectId.isValid(collectionId) ||
      !Types.ObjectId.isValid(addedNewsId)
    ) {
      throw new NotFoundException('الخبر غير موجود');
    }

    const collectionObjId = new Types.ObjectId(collectionId);
    const addedNewsObjId = new Types.ObjectId(addedNewsId);

    const addedNews = await this.addedNewsModel.findOne({
      _id: addedNewsObjId,
      sharedCollectionId: collectionObjId,
    });

    if (!addedNews) {
      throw new NotFoundException('الخبر غير موجود');
    }

    const originalNewsId = addedNews.originalNewsId;
    const article = await this.newsArticleModel.findById(originalNewsId);

    if (!article) {
      throw new NotFoundException('الخبر الأصلي غير موجود');
    }

    const audioField =
      mode === 'summary'
        ? 'ttsAudioURLforSummary'
        : 'ttsAudioURLforContent';

    if (mode === 'summary') {
      if (!article.summaryText?.trim() && !addedNews.summaryText?.trim()) {
        const { success, summaryText } =
          await this.addedNewsSummaryService.enableAiSummaryForAddedNews(
            collectionId,
            addedNewsId,
          );

        if (!success || !summaryText?.trim()) {
          throw new BadRequestException('تعذر توليد ملخص لهذا الخبر');
        }

        article.summaryText = summaryText.trim();
        addedNews.summaryText = summaryText.trim();

        await article.save();

        await this.addedNewsModel.updateMany(
          { originalNewsId },
          { $set: { summaryText: summaryText.trim() } },
        );
      }

      const finalSummary =
        article.summaryText?.trim() ||
        addedNews.summaryText?.trim() ||
        '';

      if (!finalSummary) {
        throw new BadRequestException('تعذر توليد ملخص لهذا الخبر');
      }

      if (article.summaryText !== finalSummary) {
        article.summaryText = finalSummary;
        await article.save();
      }

      await this.addedNewsModel.updateMany(
        { originalNewsId },
        { $set: { summaryText: finalSummary } },
      );
    }

    const existingBlobUrl =
      (article as any)[audioField]?.trim() ||
      (addedNews as any)[audioField]?.trim() ||
      '';

    if (existingBlobUrl) {
      await this.newsArticleModel.updateOne(
        { _id: originalNewsId },
        { $set: { [audioField]: existingBlobUrl } },
      );

      await this.addedNewsModel.updateMany(
        { originalNewsId },
        { $set: { [audioField]: existingBlobUrl } },
      );

      const updatedAddedNews = await this.addedNewsModel
        .findById(addedNewsObjId)
        .lean();

      const url =
        await this.blobStorageService.generateReadSasUrl(existingBlobUrl);

      return {
        url,
        addedNews: updatedAddedNews,
      };
    }

    if (mode === 'summary') {
      const text = article.summaryText?.trim() || addedNews.summaryText?.trim();

      if (!text) {
        throw new BadRequestException('تعذر توليد ملخص لهذا الخبر');
      }

      const audioBuffer = await this.newsAudioService.generateAudio(text);

      const blobUrl = await this.blobStorageService.uploadAudio(
        audioBuffer,
        `news/${originalNewsId.toString()}/summary.mp3`,
      );

      await this.newsArticleModel.updateOne(
        { _id: originalNewsId },
        {
          $set: {
            ttsAudioURLforSummary: blobUrl,
            summaryText: text,
          },
        },
      );

      await this.addedNewsModel.updateMany(
        { originalNewsId },
        {
          $set: {
            ttsAudioURLforSummary: blobUrl,
            summaryText: text,
          },
        },
      );

      const updatedAddedNews = await this.addedNewsModel
        .findById(addedNewsObjId)
        .lean();

      const url = await this.blobStorageService.generateReadSasUrl(blobUrl);

      return {
        url,
        addedNews: updatedAddedNews,
      };
    }

    const content = article.newsContent?.trim() || addedNews.newsContent?.trim();

    if (!content) {
      throw new BadRequestException('لا يوجد محتوى صوتي لهذا الخبر');
    }

    const audioBuffer = await this.newsAudioService.generateLongAudio(content);

    const blobUrl = await this.blobStorageService.uploadAudio(
      audioBuffer,
      `news/${originalNewsId.toString()}/content.mp3`,
    );

    await this.newsArticleModel.updateOne(
      { _id: originalNewsId },
      {
        $set: {
          ttsAudioURLforContent: blobUrl,
        },
      },
    );

    await this.addedNewsModel.updateMany(
      { originalNewsId },
      {
        $set: {
          ttsAudioURLforContent: blobUrl,
        },
      },
    );

    const updatedAddedNews = await this.addedNewsModel
      .findById(addedNewsObjId)
      .lean();

    const url = await this.blobStorageService.generateReadSasUrl(blobUrl);

    return {
      url,
      addedNews: updatedAddedNews,
    };
  } catch (error) {
    console.error('GET OR CREATE ADDED NEWS AUDIO ERROR =>', error);
    throw error;
  }
}

  private async validateOwnerAction(
    collectionId: string,
    addedNewsId: string,
    actorUID: string,
  ) {
    if (!collectionId || !Types.ObjectId.isValid(collectionId)) {
      throw new BadRequestException('معرّف المجموعة غير صالح');
    }
    if (!addedNewsId || !Types.ObjectId.isValid(addedNewsId)) {
      throw new BadRequestException('معرّف الخبر غير صالح');
    }
    if (!actorUID || !Types.ObjectId.isValid(actorUID)) {
      throw new BadRequestException('معرّف المستخدم غير صالح');
    }

    const collectionObjId = new Types.ObjectId(collectionId);
    const addedNewsObjId = new Types.ObjectId(addedNewsId);

    const collection = await this.collectionModel
      .findById(collectionObjId)
      .select('_id ownerId')
      .lean();

    if (!collection) {
      throw new NotFoundException('لم يتم العثور على المجموعة المشتركة');
    }

    if (collection.ownerId.toString() != actorUID) {
      throw new ForbiddenException('فقط مالك المجموعة يستطيع تنفيذ هذا الإجراء');
    }

    return { collectionObjId, addedNewsObjId, collection };
  }

  private mapAddedNews(n: any, ownerId?: string, viewerId?: string) {
    return {
      id: n._id?.toString?.() ?? '',
      sharedCollectionId: n.sharedCollectionId?.toString?.() ?? '',
      originalNewsId: n.originalNewsId?.toString?.() ?? '',
      addedByUID: n.addedByUserId?.toString?.() ?? '',
      addedByUserId: n.addedByUserId?.toString?.() ?? '',
      newsTitle: n.newsTitle ?? '',
      newsContent: n.newsContent ?? '',
      newsSource: n.newsSource ?? '',
      sourceLink: n.sourceLink ?? '',
      category: n.category ?? '',
      publishDate: n.publishDate ? new Date(n.publishDate).toISOString() : null,
      ttsAudioURLforContent: n.ttsAudioURLforContent ?? '',
      ttsAudioURLforSummary: n.ttsAudioURLforSummary ?? '',
      summaryText: n.summaryText ?? '',
      createdAt: n.createdAt ? new Date(n.createdAt).toISOString() : null,
      isArchived: n.isArchived === true,
      sharedByCreator: ownerId ? n.addedByUserId?.toString?.() === ownerId : false,
      isAddedByMe: viewerId ? n.addedByUserId?.toString?.() === viewerId : false,
    };
  }
async deleteAddedNews(
  collectionId: string,
  addedNewsId: string,
  actorUID: string,
) {
  if (!Types.ObjectId.isValid(collectionId)) {
    throw new BadRequestException('معرّف المجموعة غير صالح');
  }

  if (!Types.ObjectId.isValid(addedNewsId)) {
    throw new BadRequestException('معرّف الخبر غير صالح');
  }

  if (!Types.ObjectId.isValid(actorUID)) {
    throw new BadRequestException('معرّف المستخدم غير صالح');
  }

  const collectionObjId = new Types.ObjectId(collectionId);
  const addedNewsObjId = new Types.ObjectId(addedNewsId);
  const actorObjId = new Types.ObjectId(actorUID);

  const collection = await this.collectionModel
    .findById(collectionObjId)
    .select('_id ownerId')
    .lean();

  if (!collection) {
    throw new NotFoundException('لم يتم العثور على المجموعة المشتركة');
  }

  const addedNews = await this.addedNewsModel
    .findOne({
      _id: addedNewsObjId,
      sharedCollectionId: collectionObjId,
    })
    .select('_id sharedCollectionId addedByUserId')
    .lean();

  if (!addedNews) {
    throw new NotFoundException('لم يتم العثور على الخبر');
  }

  const isOwner = collection.ownerId.toString() === actorObjId.toString();

  const isAddedByMe =
    addedNews.addedByUserId.toString() === actorObjId.toString();

  if (!isOwner && !isAddedByMe) {
    throw new ForbiddenException('ليس لديك صلاحية حذف هذا الخبر');
  }

  await this.addedNewsModel.deleteOne({
    _id: addedNewsObjId,
    sharedCollectionId: collectionObjId,
  });

  return {
    message: 'تم حذف الخبر بنجاح',
    deletedAddedNewsId: addedNewsId,
  };
}


}