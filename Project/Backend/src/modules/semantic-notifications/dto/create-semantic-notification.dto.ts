import { IsNotEmpty, IsString } from 'class-validator';

export class CreateSemanticNotificationDto {
  @IsString()
  @IsNotEmpty()
  interest!: string;

  @IsString()
  @IsNotEmpty()
  keyword!: string;
}