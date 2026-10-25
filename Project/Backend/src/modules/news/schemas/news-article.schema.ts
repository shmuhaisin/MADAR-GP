//news-article.schema.ts
import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';
import { Interest } from '../../enums/interests.enum';

export type NewsArticleDocument = HydratedDocument<NewsArticle>;

@Schema({ timestamps: true, collection: 'news_articles' })
export class NewsArticle {

  @Prop({ type: Types.ObjectId })
  _id!: Types.ObjectId;

  @Prop({ required: true, trim: true })
  newsTitle!: string;

  @Prop({ required: true })
  newsContent!: string;

  @Prop({ required: true, default: '', trim: true })
  newsSource!: string;

  @Prop({ required: true, default: '', trim: true })
  sourceLink!: string;

  @Prop({ type: String, enum: Object.values(Interest), required: true })
  category!: Interest;

  @Prop({ type: Date, required: true })
  publishDate!: Date;

  @Prop({ type: Number, default: 0 })
  reportsCount!: number;

  @Prop({ default: '' })
  ttsAudioURLforContent!: string;

  @Prop({ default: '' })
  ttsAudioURLforSummary!: string;

  @Prop({ default: '' })
  summaryText!: string;

  @Prop({ type: [Number], default: [] })
  NAEmbedding!: number[];
}

export const NewsArticleSchema = SchemaFactory.createForClass(NewsArticle);

NewsArticleSchema.index({ publishDate: -1 });
NewsArticleSchema.index({ category: 1, publishDate: -1 });
NewsArticleSchema.index(
  { sourceLink: 1 },
  {
    unique: true, partialFilterExpression: { sourceLink: { $type: "string", $ne: "" } }
  }
);