import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type SharedCollectionAddedNewsDocument = HydratedDocument<SharedCollectionAddedNews>;

@Schema({ timestamps: { createdAt: true, updatedAt: false }, collection: 'shared_collection_added_news' })
export class SharedCollectionAddedNews {
  @Prop({ type: Types.ObjectId, required: true, index: true })
  sharedCollectionId!: Types.ObjectId;

  @Prop({ type: Types.ObjectId, required: true, index: true })
  originalNewsId!: Types.ObjectId;


  @Prop({ type: Types.ObjectId, required: true, index: true })
  addedByUserId!: Types.ObjectId;


  @Prop({ required: true })
  newsContent!: string;

  @Prop({ required: true })
  newsTitle!: string;

  @Prop({required: true, default: '' })
  newsSource!: string;

  @Prop({required: true, default: '' })
  sourceLink!: string;

  @Prop({ required: true, default: '' })
  category!: string;

  @Prop({type:Date, required: true})
  publishDate!: Date;

  @Prop({default: '' })
  ttsAudioURLforContent!: string;

  @Prop({ default: '' })
  ttsAudioURLforSummary!: string;

  @Prop({default: '' })
  summaryText!: string;
   @Prop({ type: Boolean, default: false, index: true })
  isArchived!: boolean;
}

export const SharedCollectionAddedNewsSchema =
  SchemaFactory.createForClass(SharedCollectionAddedNews);

  //Enforce no duplicates news articles
SharedCollectionAddedNewsSchema.index(
  { sharedCollectionId: 1, originalNewsId: 1 },
  { unique: true },
);

// normal list
SharedCollectionAddedNewsSchema.index({
  sharedCollectionId: 1,
  isArchived: 1,
  createdAt: -1,
});

// archived list
SharedCollectionAddedNewsSchema.index({
  sharedCollectionId: 1,
  isArchived: 1,
  publishDate: -1,
});