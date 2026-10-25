import { IsOptional, IsString, MaxLength, IsNotEmpty } from 'class-validator';

export class UpdateSharedCollectionDto {
  
  @IsString()
  @IsOptional()
  @IsNotEmpty()
 @MaxLength(40) 
  collectionName?: string;

  @IsString()
  @IsOptional()
  @IsNotEmpty()
 @MaxLength(90)
  collectionDescription?: string;
}
