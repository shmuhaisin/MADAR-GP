import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type NotificationDocument = HydratedDocument<Notification>;

export enum NotifType {
  JOIN_REQ = 'joinReq',
  REQ_REPLY = 'reqReply',
  SEMANTIC = 'semantic',
}

@Schema({ timestamps: { createdAt: true, updatedAt: false }, collection: 'notifications', versionKey: false })
export class Notification {

  @Prop({ type: Types.ObjectId, required: true, ref: 'User', index: true })
  userId!: Types.ObjectId;

  @Prop({ required: true })
  notifTitle!: string;

  @Prop({ required: true })
  notifMessage!: string;

  @Prop({ type: String, enum: NotifType, required: true, index: true })
  notifType!: NotifType;

  @Prop({ default: false })
  isRead!: boolean;

  @Prop({ type: String, default: null })
  status!: string | null;

  @Prop({ type: String, default: null })
  interest!: string | null;

  @Prop({ type: String, default: null })
  keyword!: string | null;

  @Prop({ type: String, default: null })
  relatedNewsID!: string | null;

  @Prop({ type: Types.ObjectId, ref: 'SharedCollection', default: null, index: true })
  sharedCollectionId!: Types.ObjectId | null;

  @Prop({ type: Types.ObjectId, ref: 'Collection', default: null })
  collectionId!: Types.ObjectId | null;
}

export const NotificationSchema = SchemaFactory.createForClass(Notification);