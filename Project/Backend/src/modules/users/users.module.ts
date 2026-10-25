import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { JwtModule } from '@nestjs/jwt';

import { UsersController } from './users.controller';
import { UsersService } from './users.service';

import { User, UserSchema } from './schemas/user.schema';
import { CountersModule } from '../counters/counters.module';

import {
  NewsReported,
  NewsReportedSchema,
} from '../news/schemas/news-reported.schema';

import {
  Notification,
  NotificationSchema,
} from '../notifications/schemas/notification.schema';

import {
  SemanticNotification,
  SemanticNotificationSchema,
} from '../semantic-notifications/schemas/semantic-notification.schema';

import {
  SharedCollection,
  SharedCollectionSchema,
} from '../shared-collections/schemas/shared-collection.schema';

import {
  SharedCollectionMember,
  SharedCollectionMemberSchema,
} from '../shared-collections/schemas/shared-collection-member.schema';

import {
  SharedCollectionAddedNews,
  SharedCollectionAddedNewsSchema,
} from '../shared-collections/schemas/shared-collection-added-news.schema';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: User.name, schema: UserSchema },

      { name: NewsReported.name, schema: NewsReportedSchema },
      { name: Notification.name, schema: NotificationSchema },
      {
        name: SemanticNotification.name,
        schema: SemanticNotificationSchema,
      },

      { name: SharedCollection.name, schema: SharedCollectionSchema },
      {
        name: SharedCollectionMember.name,
        schema: SharedCollectionMemberSchema,
      },
      {
        name: SharedCollectionAddedNews.name,
        schema: SharedCollectionAddedNewsSchema,
      },
    ]),
    CountersModule,
    JwtModule,
  ],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}