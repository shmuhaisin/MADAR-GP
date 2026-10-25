
import { IsNotEmpty, IsString } from 'class-validator';

export class ConfirmResetDto {
  @IsString()
  @IsNotEmpty()
  phone!: string;

  @IsString()
  @IsNotEmpty()
  code!: string;
}
