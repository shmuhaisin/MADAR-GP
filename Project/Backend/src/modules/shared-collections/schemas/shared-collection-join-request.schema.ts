import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';
import { JoinStatus } from 'src/modules/enums/joinStatus';

export type SharedCollectionJoinRequestDocument = HydratedDocument<SharedCollectionJoinRequest>;



@Schema({ timestamps: { createdAt: true, updatedAt: false }, collection: 'shared_collection_join_requests' })
export class SharedCollectionJoinRequest {
  @Prop({ type: Types.ObjectId, required: true, index: true })
  sharedCollectionId!: Types.ObjectId;

  @Prop({ type: Types.ObjectId, required: true,ref: 'User', index: true })
  userId!: Types.ObjectId;

  @Prop({ type: String, enum: JoinStatus,default: JoinStatus.PENDING, index: true })
  status!: JoinStatus;
}

export const SharedCollectionJoinRequestSchema =
  SchemaFactory.createForClass(SharedCollectionJoinRequest);


SharedCollectionJoinRequestSchema.index(
  { sharedCollectionId: 1, userId: 1 },
  { unique: true }
);
