
import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';
import { MemberRole } from 'src/modules/enums/memberRole';

export type SharedCollectionMemberDocument = HydratedDocument<SharedCollectionMember>;


@Schema({ timestamps: { createdAt: true, updatedAt: false }, collection: 'shared_collection_members' })
export class SharedCollectionMember {
  @Prop({ type: Types.ObjectId, required: true, index: true })
  sharedCollectionId!: Types.ObjectId;

  @Prop({ type: Types.ObjectId, required: true, index: true , ref: 'User'})
  userId!: Types.ObjectId;

  @Prop({ type: String, enum: MemberRole, required: true })
  role!: MemberRole;
}

export const SharedCollectionMemberSchema =
  SchemaFactory.createForClass(SharedCollectionMember);


SharedCollectionMemberSchema.index({ sharedCollectionId: 1, userId: 1 }, { unique: true });
SharedCollectionMemberSchema.index({ userId: 1, createdAt: -1 });
