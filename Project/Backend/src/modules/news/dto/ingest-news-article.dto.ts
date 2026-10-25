import { IsArray, IsDateString, IsEnum, IsNotEmpty, IsOptional, IsString, IsUrl } from 'class-validator';
import { Interest } from '../../enums/interests.enum';

export class IngestNewsArticleDto {
  @IsString()
  @IsNotEmpty()
  newsTitle!: string;

  @IsString()
  @IsNotEmpty()
  newsContent!: string;

  @IsString()
  @IsNotEmpty()
  newsSource!: string;

  @IsString()
  @IsNotEmpty()
  @IsUrl({ require_tld: false })
  sourceLink!: string;

  @IsEnum(Interest)
  category!: Interest;

  @IsDateString()
  publishDate!: string;

  @IsOptional()
  @IsString()
  ttsAudioURLforContent?: string;

  @IsOptional()
  @IsString()
  ttsAudioURLforSummary?: string;

  @IsOptional()
  @IsString()
  summaryText?: string;

  @IsOptional()
  @IsArray()
  NAEmbedding?: number[];
}