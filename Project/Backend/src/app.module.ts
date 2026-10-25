import { Module } from '@nestjs/common';
import { HealthModule } from './modules/health/health.module';
import { UsersModule } from './modules/users/users.module';
import { AuthModule } from './modules/auth/auth.module';
import { NewsModule } from './modules/news/news.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { SemanticNotificationsModule } from './modules/semantic-notifications/semantic-notifications.module';
import { SharedCollectionsModule } from './modules/shared-collections/shared-collections.module';
import { DatabaseModule } from './modules/database/database.module'
import { ConfigModule } from '@nestjs/config';

@Module({
  imports: [ConfigModule.forRoot({
    isGlobal: true,
    envFilePath: '.env',
  }),
    HealthModule, UsersModule, AuthModule, NewsModule, NotificationsModule, 
    HealthModule, UsersModule, AuthModule, NewsModule, NotificationsModule,
    SemanticNotificationsModule, SharedCollectionsModule,DatabaseModule,
],
})
export class AppModule { }
