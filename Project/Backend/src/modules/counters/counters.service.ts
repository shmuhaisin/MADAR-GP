import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Counter } from './schemas/counter.schema';

@Injectable()
export class CountersService {
  constructor(@InjectModel(Counter.name) private readonly counterModel: Model<Counter>) {}

  async next(sequenceId: string): Promise<number> {
    const doc = await this.counterModel.findByIdAndUpdate(
      sequenceId,
      { $inc: { seq: 1 } },
      { new: true, upsert: true } 
    );

    return doc.seq;
  }
}
