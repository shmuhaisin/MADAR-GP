import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type SharedCollectionDocument = HydratedDocument<SharedCollection>;

@Schema({ timestamps: true, collection: 'shared_collections' })
export class SharedCollection {
  @Prop({ type: Types.ObjectId, required: true, index: true })
  ownerId!: Types.ObjectId;

  @Prop({ required: true, trim: true })
  collectionName!: string;

  @Prop({ required: true, trim: true })
  collectionDescription!: string;

  @Prop({ default: 0 })
  numOfViewers!: number;
}

export const SharedCollectionSchema = SchemaFactory.createForClass(SharedCollection);
SharedCollectionSchema.index({ ownerId: 1, createdAt: -1 });
