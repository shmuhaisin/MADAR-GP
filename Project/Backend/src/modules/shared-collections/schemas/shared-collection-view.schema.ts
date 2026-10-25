import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type SharedCollectionViewDocument = HydratedDocument<SharedCollectionView>;

@Schema({ collection: 'shared_collection_views',timestamps: { createdAt: 'viewedAt', updatedAt: false },
})
export class SharedCollectionView {
  @Prop({ type: Types.ObjectId, required: true,index: true, ref: 'SharedCollection',
  })
  collectionId!: Types.ObjectId;

  @Prop({ type: Types.ObjectId, required: true,index: true, ref: 'User',
  })
  userId!: Types.ObjectId;

  viewedAt?: Date;
}

export const SharedCollectionViewSchema = SchemaFactory.createForClass(SharedCollectionView);

SharedCollectionViewSchema.index( { collectionId: 1, userId: 1 },{ unique: true },
);