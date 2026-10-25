import { IsIn } from 'class-validator';

export class DecideJoinRequestDto {
  @IsIn(['accept', 'reject'])
  decision!: 'accept' | 'reject';
}