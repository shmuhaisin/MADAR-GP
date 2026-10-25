import { IsMongoId, IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class CreateSharedCollectionDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  collectionName!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(90)
  collectionDescription!: string;
}
