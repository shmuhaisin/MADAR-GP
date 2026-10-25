import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import {
  SemanticNotification,
  SemanticNotificationSchema,
} from './schemas/semantic-notification.schema';
import { SemanticNotificationsService } from './semantic-notifications.service';
import { SemanticNotificationsController } from './semantic-notifications.controller';
import { CountersModule } from '../counters/counters.module';
import { EmbeddingsModule } from './providers/embeddings.module';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: SemanticNotification.name, schema: SemanticNotificationSchema },
    ]),
    CountersModule,
    EmbeddingsModule,
  ],
  controllers: [SemanticNotificationsController],
  providers: [SemanticNotificationsService],
  exports: [SemanticNotificationsService],
})
export class SemanticNotificationsModule {}