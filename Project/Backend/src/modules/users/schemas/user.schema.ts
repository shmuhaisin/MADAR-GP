import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { Interest } from '../../enums/interests.enum';

@Schema({ timestamps: true, collection: 'users' })
export class User extends Document {
  @Prop({ required: true, unique: true })
  userID!: string;

  @Prop({ required: true, unique: true, trim: true })
  username!: string;

  @Prop({ required: true, unique: true, lowercase: true, trim: true })
  email!: string;

  @Prop({ required: true })
  password!: string;

  @Prop({ required: true, trim: true, unique: true })
  phoneNumber!: string;

  @Prop({ required: true })
  birthdate!: Date;

  @Prop({ required: true, type: [String], enum: Object.values(Interest) })
  interests!: Interest[];

  @Prop({ type: [String], default: [] })
  hiddenArticles: string[];

  @Prop({ type: String, default: null })
  fcmToken: string | null;
}

export const UserSchema = SchemaFactory.createForClass(User);