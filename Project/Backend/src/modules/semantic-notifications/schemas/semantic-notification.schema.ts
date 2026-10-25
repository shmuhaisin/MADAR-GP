import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type SemanticNotificationDocument = HydratedDocument<SemanticNotification>;

@Schema({ timestamps: { createdAt: true, updatedAt: false }, versionKey: false, collection: 'semantic_notifications' })
export class SemanticNotification {

  @Prop({ type: Types.ObjectId, required: true, ref: 'User', index: true })
  userId!: Types.ObjectId;

  @Prop({ required: true })
  Interest!: string;

  @Prop({ required: true })
  keyword!: string;

  @Prop({ type: [Number], default: [] })
  SNEmbedding!: number[];

  @Prop({ type: String, default: '' })
  SNEmbeddingModel!: string;
}

export const SemanticNotificationSchema =
  SchemaFactory.createForClass(SemanticNotification);

SemanticNotificationSchema.index(
  { userId: 1, Interest: 1, keyword: 1 },
  { unique: true },
);