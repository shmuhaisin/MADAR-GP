import { IsNotEmpty, IsString } from 'class-validator';

export class DeleteSemanticNotificationDto {
  @IsString()
  @IsNotEmpty()
  interest!: string;

  @IsString()
  @IsNotEmpty()
  keyword!: string;
}