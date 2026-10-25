//Backend/src/modules/notifications/notifications.controller.ts
import { Controller, Get, Param, Patch, Query, Req, UseGuards } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Request } from 'express';

@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(private readonly service: NotificationsService) {}

  @Get('getAll')
  getAll(
    @Req() req,
    @Query('type') type?: string,
    @Query('interest') interest?: string,
    @Query('keyword') keyword?: string,
  ) {
    return this.service.getNotifications(req.user.userId, {
      type,
      interest,
      keyword,
    });
  }

  @Get('unreadCount')
  getUnreadCount(@Req() req) {
    return this.service.getUnreadCount(req.user.userId);
  }

  @Get(':id/getDetails')
  getDetails(@Req() req, @Param('id') id: string) {
    return this.service.getNotificationDetails(req.user.userId, id);
  }

  @Patch('markAllRead')
  markAllAsRead(@Req() req) {
    return this.service.markAllAsRead(req.user.userId);
  }
}