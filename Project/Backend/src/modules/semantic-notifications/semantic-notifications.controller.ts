import { Controller, Get, Post, Delete, Body, Req, UseGuards, Query } from '@nestjs/common';
import { SemanticNotificationsService } from './semantic-notifications.service';
import { CreateSemanticNotificationDto } from './dto/create-semantic-notification.dto';
import { DeleteSemanticNotificationDto } from './dto/delete-semantic-notification.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@Controller('semantic-notifications')
@UseGuards(JwtAuthGuard)
export class SemanticNotificationsController {
  constructor(private readonly semService: SemanticNotificationsService) { }

  @Get('getAll')
  getAll(@Req() req) {
    return this.semService.getAll(req.user.userId);
  }

  @Post('create')
  create(@Req() req, @Body() dto: CreateSemanticNotificationDto) {
    return this.semService.create(req.user.userId, dto.interest, dto.keyword);
  }

  @Delete('delete')
  delete(@Req() req, @Query() dto: DeleteSemanticNotificationDto) {
    return this.semService.delete(req.user.userId, dto.interest, dto.keyword);
  }
}