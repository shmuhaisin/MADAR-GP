import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type NewsReportedDocument = HydratedDocument<NewsReported>;

@Schema({
  timestamps: { createdAt: true, updatedAt: false },
  collection: 'news_reported',
})
export class NewsReported {

    @Prop({ type: Types.ObjectId, required: true, index: true })
  newsId!: Types.ObjectId;

  @Prop({ type: Types.ObjectId, required: true, index: true })
  reportedByUserId!: Types.ObjectId;
}

export const NewsReportedSchema =
  SchemaFactory.createForClass(NewsReported);


NewsReportedSchema.index(
  { newsId: 1, reportedByUserId: 1 },
  { unique: true },
);