import { IsNotEmpty, IsString } from 'class-validator';

export class RequestResetOtpDto {
  @IsString() @IsNotEmpty()
  phoneNumber!: string;
}
