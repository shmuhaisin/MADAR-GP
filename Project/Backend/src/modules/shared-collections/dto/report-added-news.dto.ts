import { IsNotEmpty, IsString } from 'class-validator';

export class ReportAddedNewsDto {

  @IsString()
  @IsNotEmpty()
  reportReason!: string;
}
