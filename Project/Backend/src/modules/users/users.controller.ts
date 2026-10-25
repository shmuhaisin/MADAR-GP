import {
  Body,
  Controller,
  Delete,
  Get,
  Patch,
  Post,
  Param,
  Req,
  UseGuards,
} from '@nestjs/common';

import type { Request } from 'express';

import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { Interest } from '../enums/interests.enum';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) { }

  @UseGuards(JwtAuthGuard)
  @Get('profile')
  async getMyProfile(@Req() req: Request) {
    const userId = (req as any).user?.userId;
    return this.usersService.getProfileById(userId);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('profile')
  async updateMyProfile(@Req() req: Request, @Body() dto: UpdateProfileDto) {
    const userId = (req as any).user?.userId;
    return this.usersService.updateProfileById(userId, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Delete('profile')
  async deleteMyProfile(@Req() req: Request) {
    const userId = (req as any).user?.userId;
    await this.usersService.deleteById(userId);
    return { message: 'profile deleted' };
  }

  @UseGuards(JwtAuthGuard)
  @Post('interest')
  async addInterest(
    @Req() req: Request,
    @Body() body: { interests: Interest[] },
  ) {
    const userId = (req as any).user?.userId;
    return this.usersService.addInterests(userId, body?.interests ?? []);
  }

  @UseGuards(JwtAuthGuard)
  @Delete('interest/:interest')
  async removeInterest(@Req() req: Request, @Param('interest') interest: string) {
    const userId = (req as any).user?.userId;
    return this.usersService.removeInterest(userId, interest as Interest);
  }

  @UseGuards(JwtAuthGuard)
  @Post('fcm-token')
  async saveFcmToken(@Req() req: Request, @Body() body: { fcmToken: string }) {
    const userId = (req as any).user?.userId;
    return this.usersService.saveFcmToken(userId, body.fcmToken);
  }
}