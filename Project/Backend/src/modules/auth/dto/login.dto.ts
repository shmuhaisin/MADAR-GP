import { IsNotEmpty, IsString } from 'class-validator';

export class LoginDto {
  @IsString()
  @IsNotEmpty()
  identifier!: string; // can be email or username

  @IsString()
  @IsNotEmpty()
  password!: string;
}
