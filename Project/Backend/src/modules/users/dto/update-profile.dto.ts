import {
  IsDateString,
  IsEmail,
  IsOptional,
  IsString,
  IsNotEmpty,
  IsArray,
} from 'class-validator';
import { Interest } from '../../enums/interests.enum';

export class UpdateProfileDto {
  @IsString()
  @IsOptional()
  @IsNotEmpty()
  username?: string;

  @IsEmail()
  @IsOptional()
  @IsNotEmpty()
  email?: string;

  @IsDateString()
  @IsOptional()
  @IsNotEmpty()
  birthdate?: string;

  @IsString()
  @IsOptional()
  @IsNotEmpty()
  phoneNumber?: string;

  @IsString()
  @IsOptional()
  @IsNotEmpty()
  phoneChangeVerificationToken?: string;

  @IsArray()
  @IsOptional()
  interests?: Interest[];
}