import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Schema as MongooseSchema, HydratedDocument } from 'mongoose';

export type CounterDocument = HydratedDocument<Counter>;

@Schema({ collection: 'counters' })
export class Counter {
  @Prop({ required: true })
  _id!: string;

  @Prop({ required: true, default: 0 })
  seq!: number;
}

export const CounterSchema: MongooseSchema = SchemaFactory.createForClass(Counter);