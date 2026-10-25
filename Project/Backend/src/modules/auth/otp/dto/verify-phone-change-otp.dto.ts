import { IsNotEmpty, IsString } from 'class-validator';

export class VerifyPhoneChangeOtpDto {
  @IsString()
  @IsNotEmpty()
  phone!: string;

  @IsString()
  @IsNotEmpty()
  code!: string;
}