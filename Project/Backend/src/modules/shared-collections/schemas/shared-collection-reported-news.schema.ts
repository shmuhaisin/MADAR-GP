import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type SharedCollectionReportedNewsDocument = HydratedDocument<SharedCollectionReportedNews>;

@Schema({ collection: 'shared_collection_reported_news' })
export class SharedCollectionReportedNews {
  @Prop({ type: Types.ObjectId, required: true, index: true })
  sharedCollectionId!: Types.ObjectId;

  @Prop({ type: Types.ObjectId, required: true, index: true,ref: 'SharedCollectionAddedNews'  })
  addedNewsId!: Types.ObjectId;

  @Prop({ type: Types.ObjectId, required: true, index: true, ref: 'User'  })
  reportedByUserId!: Types.ObjectId;

  @Prop({ required: true })
  reportReason!: string;

  @Prop({ default: () => new Date() })
  reportedAt!: Date;
}

export const SharedCollectionReportedNewsSchema =
  SchemaFactory.createForClass(SharedCollectionReportedNews);

SharedCollectionReportedNewsSchema.index({ addedNewsId: 1, reportedByUserId: 1 },{ unique: true });
SharedCollectionReportedNewsSchema.index({ sharedCollectionId: 1, reportedAt: -1 });
