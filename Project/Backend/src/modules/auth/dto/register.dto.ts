import {
    IsEmail,
    IsNotEmpty,
    IsString,
    IsDateString,
    IsArray,
    ArrayMinSize,
    IsEnum,
} from 'class-validator';
import { Interest } from '../../enums/interests.enum';

export class RegisterDto {
    @IsString()
    @IsNotEmpty()
    username!: string;

    @IsEmail()
    @IsNotEmpty()
    email!: string;

    @IsString()
    @IsNotEmpty()
    password!: string;

    @IsString()
    @IsNotEmpty()
    phoneNumber!: string;

    @IsDateString()
    @IsNotEmpty()
    birthdate!: string;

    @IsArray()
    @ArrayMinSize(1)
    @IsEnum(Interest, { each: true })
    interests!: Interest[];
}
