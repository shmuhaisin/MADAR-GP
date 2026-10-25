import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';

import { NewsController } from './news.controller';
import { NewsService } from './news.service';

import { NewsArticle, NewsArticleSchema } from './schemas/news-article.schema';
import { NewsReported, NewsReportedSchema } from './schemas/news-reported.schema';

import { User, UserSchema } from '../users/schemas/user.schema';
import { SummaryService } from './providers/summary.service';
import { NewsAudioService } from './providers/news-audio.service';
import { BlobStorageService } from './providers/blob-storage.service';
import {SharedCollectionAddedNews,SharedCollectionAddedNewsSchema,} from '../shared-collections/schemas/shared-collection-added-news.schema';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: NewsArticle.name, schema: NewsArticleSchema },
      { name: NewsReported.name, schema: NewsReportedSchema },
      { name: User.name, schema: UserSchema },
      {
  name: SharedCollectionAddedNews.name,
  schema: SharedCollectionAddedNewsSchema,
},
    ]),
  ],
  controllers: [NewsController],
  providers: [
    NewsService,
    SummaryService,
    NewsAudioService,
    BlobStorageService,
  ],
  exports: [
    NewsService,
    SummaryService,
    NewsAudioService,
    BlobStorageService,
  ],
})
export class NewsModule {}
