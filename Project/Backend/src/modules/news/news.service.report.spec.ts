import { NotFoundException, InternalServerErrorException } from '@nestjs/common';
import { getModelToken } from '@nestjs/mongoose';
import { Test, TestingModule } from '@nestjs/testing';
import { Types } from 'mongoose';

import { NewsService } from './news.service';
import { NewsArticle } from './schemas/news-article.schema';
import { NewsReported } from './schemas/news-reported.schema';
import { User } from '../users/schemas/user.schema';
import { SharedCollectionAddedNews } from '../shared-collections/schemas/shared-collection-added-news.schema';
import { SummaryService } from './providers/summary.service';
import { NewsAudioService } from './providers/news-audio.service';
import { BlobStorageService } from './providers/blob-storage.service';

const makeId = () => new Types.ObjectId().toHexString();

function mockModel(overrides: Record<string, jest.Mock> = {}) {
  return {
    exists: jest.fn(),
    create: jest.fn(),
    findByIdAndUpdate: jest.fn(),
    deleteOne: jest.fn(),
    deleteMany: jest.fn(),
    find: jest.fn(),
    findById: jest.fn(),
    findOne: jest.fn(),
    findOneAndUpdate: jest.fn(),
    countDocuments: jest.fn(),
    updateMany: jest.fn(),
    ...overrides,
  };
}

describe('NewsService – reportNews()', () => {
  let service: NewsService;

  let newsArticleModel: ReturnType<typeof mockModel>;
  let newsReportedModel: ReturnType<typeof mockModel>;
  let userModel: ReturnType<typeof mockModel>;
  let addedNewsModel: ReturnType<typeof mockModel>;

  beforeEach(async () => {
    newsArticleModel = mockModel();
    newsReportedModel = mockModel();
    userModel        = mockModel();
    addedNewsModel   = mockModel();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        NewsService,
        { provide: getModelToken(NewsArticle.name),               useValue: newsArticleModel },
        { provide: getModelToken(NewsReported.name),              useValue: newsReportedModel },
        { provide: getModelToken(User.name),                      useValue: userModel },
        { provide: getModelToken(SharedCollectionAddedNews.name), useValue: addedNewsModel },
        // these providers are not used by reportNews but are required by the service constructor
        { provide: SummaryService,    useValue: { enableAiSummaryForArticle: jest.fn() } },
        { provide: NewsAudioService,  useValue: { generateAudio: jest.fn(), generateLongAudio: jest.fn() } },
        { provide: BlobStorageService,useValue: { generateReadSasUrl: jest.fn(), uploadAudio: jest.fn() } },
      ],
    }).compile();

    service = module.get<NewsService>(NewsService);
  });

  afterEach(() => jest.clearAllMocks());

  // TC_1: article reported successfully, count is below the deletion threshold (20)
  it('TC_1 should create a report record and increment reportsCount then return status "reported"', async () => {
    const newsId = makeId();
    const userId = makeId();
    const currentReportsCount = 5; 

    newsArticleModel.exists.mockResolvedValue({ _id: newsId });
    newsReportedModel.create.mockResolvedValue({});
    newsArticleModel.findByIdAndUpdate.mockReturnValue({
      lean: jest.fn().mockResolvedValue({ reportsCount: currentReportsCount + 1 }),
    });

    const result = await service.reportNews(newsId, userId);

    expect(newsReportedModel.create).toHaveBeenCalledTimes(1);
    expect(newsReportedModel.create).toHaveBeenCalledWith(
      expect.objectContaining({
        newsId:           new Types.ObjectId(newsId),
        reportedByUserId: new Types.ObjectId(userId),
      }),
    );

    expect(newsArticleModel.findByIdAndUpdate).toHaveBeenCalledWith(
      new Types.ObjectId(newsId),
      { $inc: { reportsCount: 1 } },
      { new: true },
    );
    expect(result).toEqual({ status: 'reported', reportsCount: currentReportsCount + 1 });

    expect(newsArticleModel.deleteOne).not.toHaveBeenCalled();
  });

  // TC_2: article gets deleted when report count hits the threshold which is 20
  it('TC_2 should delete the article when reportsCount reaches 20 then return status "deleted"', async () => {
    const newsId = makeId();
    const userId = makeId();

    newsArticleModel.exists.mockResolvedValue({ _id: newsId });
    newsReportedModel.create.mockResolvedValue({});
    newsArticleModel.findByIdAndUpdate.mockReturnValue({
      lean: jest.fn().mockResolvedValue({ reportsCount: 20 }),
    });
    newsArticleModel.deleteOne.mockResolvedValue({ deletedCount: 1 });
    newsReportedModel.deleteMany.mockResolvedValue({ deletedCount: 20 });

    const result = await service.reportNews(newsId, userId);

    expect(newsArticleModel.deleteOne).toHaveBeenCalledWith({ _id: new Types.ObjectId(newsId) });
    expect(newsReportedModel.deleteMany).toHaveBeenCalledWith({ newsId: new Types.ObjectId(newsId) });
    expect(result).toEqual({ status: 'deleted' });
  });

  // TC_3: user already reported this article, process stops with no changes
  it('TC_3 should return "already_reported" and make zero DB changes when article was already reported', async () => {
    const newsId = makeId();
    const userId = makeId();

    const duplicateKeyError = Object.assign(new Error('duplicate key'), { code: 11000 });

    newsArticleModel.exists.mockResolvedValue({ _id: newsId });
    newsReportedModel.create.mockRejectedValue(duplicateKeyError);

    const result = await service.reportNews(newsId, userId);

    expect(result).toEqual({ status: 'already_reported' });
    expect(newsArticleModel.findByIdAndUpdate).not.toHaveBeenCalled();
    expect(newsArticleModel.deleteOne).not.toHaveBeenCalled();
  });

  // TC_4: newsId is not a valid ObjectId format, fails before hitting the database
  it('TC_4 should throw NotFoundException for an invalid newsId format', async () => {
    const userId = makeId();

await expect(service.reportNews('invalid-object-id', userId))
      .rejects.toThrow(NotFoundException);
    expect(newsArticleModel.exists).not.toHaveBeenCalled();
  });

  // TC_5: userId is not a valid ObjectId format, fails before hitting the database
  it('TC_5 should throw NotFoundException for an invalid userId format', async () => {
    const newsId = makeId();

    await expect(service.reportNews(newsId, 'invalid-object-id'))
      .rejects.toThrow(NotFoundException);
    expect(newsArticleModel.exists).not.toHaveBeenCalled();
  });

  // TC_6: article does not exist in the database
  it('TC_6 should throw NotFoundException when the article does not exist in the DB', async () => {
    const newsId = makeId();
    const userId = makeId();

    newsArticleModel.exists.mockResolvedValue(null);

    await expect(service.reportNews(newsId, userId))
      .rejects.toThrow(NotFoundException);

    expect(newsReportedModel.create).not.toHaveBeenCalled();
  });

  // TC_7: unexpected database error during insert, error is re-thrown
  it('TC_7 should re-throw an unexpected DB error ', async () => {
    const newsId = makeId();
    const userId = makeId();
    const dbError = new InternalServerErrorException('DB connection lost');

    newsArticleModel.exists.mockResolvedValue({ _id: newsId });
    newsReportedModel.create.mockRejectedValue(dbError);

    await expect(service.reportNews(newsId, userId))
      .rejects.toThrow(InternalServerErrorException);
    expect(newsArticleModel.findByIdAndUpdate).not.toHaveBeenCalled();
  });

  // TC_8: article was deleted by another request between the exists check and the update
  it('TC_8 should throw NotFoundException when findByIdAndUpdate returns null', async () => {
    const newsId = makeId();
    const userId = makeId();

    newsArticleModel.exists.mockResolvedValue({ _id: newsId });
    newsReportedModel.create.mockResolvedValue({});
    newsArticleModel.findByIdAndUpdate.mockReturnValue({
      lean: jest.fn().mockResolvedValue(null),
    });

    await expect(service.reportNews(newsId, userId))
      .rejects.toThrow(NotFoundException);
  });
});