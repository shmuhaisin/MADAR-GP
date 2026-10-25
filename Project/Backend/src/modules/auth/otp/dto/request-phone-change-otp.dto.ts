import { IsNotEmpty, IsString } from 'class-validator';

export class RequestPhoneChangeOtpDto {
  @IsString()
  @IsNotEmpty()
  phoneNumber!: string;
}