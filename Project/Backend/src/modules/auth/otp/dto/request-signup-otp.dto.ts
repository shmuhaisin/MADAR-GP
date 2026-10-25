import { IsArray, IsEmail, IsNotEmpty, IsString ,ArrayMinSize,IsEnum,IsDateString} from 'class-validator';
import { Interest } from '../../../enums/interests.enum';

export class RequestSignupOtpDto {
  @IsString() @IsNotEmpty()
  username!: string;

  @IsEmail()
  email!: string;

  @IsString() @IsNotEmpty()
  password!: string;

  @IsString() @IsNotEmpty()
  phoneNumber!: string;

  @IsDateString() @IsNotEmpty()
  birthdate!: string; // YYYY-MM-DD

    @IsArray()
     @ArrayMinSize(1)
     @IsEnum(Interest, { each: true })
     interests!: Interest[];
}
