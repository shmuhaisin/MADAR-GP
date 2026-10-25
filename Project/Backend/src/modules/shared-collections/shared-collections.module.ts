import { Module } from '@nestjs/common';
import { SharedCollectionsController } from './shared-collections.controller';
import { MongooseModule } from '@nestjs/mongoose';
import {SharedCollection,SharedCollectionSchema} from './schemas/shared-collection.schema';
import {SharedCollectionMember,SharedCollectionMemberSchema} from './schemas/shared-collection-member.schema'
import {SharedCollectionAddedNews,SharedCollectionAddedNewsSchema} from './schemas/shared-collection-added-news.schema'
import {SharedCollectionJoinRequest,SharedCollectionJoinRequestSchema} from './schemas/shared-collection-join-request.schema'
import {SharedCollectionReportedNews,SharedCollectionReportedNewsSchema} from './schemas/shared-collection-reported-news.schema'
import { SharedCollectionsCoreService } from './services/shared-collections-core.service';
import { SharedCollectionArticlesService } from './services/shared-collection-articles.service';
import { SharedCollectionMembersService } from './services/shared-collection-members.service';
import { SharedCollectionJoinRequestsService } from './services/shared-collection-join-requests.service';
import { SharedCollectionReportsService } from './services/shared-collection-reports.service';
import { User, UserSchema } from '../users/schemas/user.schema';
import { NewsArticle, NewsArticleSchema } from '../news/schemas/news-article.schema'; 
import {SharedCollectionView,SharedCollectionViewSchema,} from './schemas/shared-collection-view.schema';
import { NotificationsModule } from '../notifications/notifications.module';
import { Notification, NotificationSchema } from '../notifications/schemas/notification.schema';
import { AddedNewsSummaryService } from './providers/addedNewSummary.service';
import {NewsModule} from '../news/news.module';

@Module({
    imports: [
        MongooseModule.forFeature([ 
      { name: SharedCollection.name, schema: SharedCollectionSchema },
      { name: SharedCollectionMember.name, schema: SharedCollectionMemberSchema },
      { name: SharedCollectionAddedNews.name, schema: SharedCollectionAddedNewsSchema },
      { name: SharedCollectionJoinRequest.name, schema: SharedCollectionJoinRequestSchema },
      { name: SharedCollectionReportedNews.name, schema: SharedCollectionReportedNewsSchema },
      { name: User.name, schema: UserSchema },
      { name: NewsArticle.name, schema: NewsArticleSchema },
      { name: SharedCollectionView.name, schema: SharedCollectionViewSchema },
      { name: Notification.name, schema: NotificationSchema },
    ]),
            NotificationsModule,
               NewsModule,
    ],
  controllers: [SharedCollectionsController],
  providers: [ 
    SharedCollectionsCoreService,
    SharedCollectionArticlesService,
    SharedCollectionMembersService,
    SharedCollectionJoinRequestsService,
    SharedCollectionReportsService, AddedNewsSummaryService,],
  exports: [SharedCollectionMembersService, AddedNewsSummaryService,],
})
export class SharedCollectionsModule {}