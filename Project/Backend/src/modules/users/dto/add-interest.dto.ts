import { IsEnum, IsArray, ArrayMinSize } from 'class-validator';
import { Interest } from '../../enums/interests.enum';

export class AddInterestDto {

  @IsArray()
  @ArrayMinSize(1)
  @IsEnum(Interest, { each: true })
  interests!: Interest[];
}
