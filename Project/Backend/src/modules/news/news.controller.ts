import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
  UnauthorizedException,
} from '@nestjs/common';
import type { Request } from 'express';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { NewsService } from './news.service';
import { IngestNewsArticleDto } from './dto/ingest-news-article.dto';
import { QueryNewsDto } from './dto/query-news.dto';

@Controller('news')
export class NewsController {
  constructor(private readonly newsService: NewsService) {}

  @UseGuards(JwtAuthGuard)
  @Get()
  async getFeed(@Req() req: Request, @Query() query: QueryNewsDto) {
    const u = (req as any).user;
    const userId = u?.userId ?? u?.sub ?? u?.id ?? u?._id;
    if (!userId) throw new UnauthorizedException('غير مصرح لك');

    return this.newsService.getFeed(query, userId);
  }

  @UseGuards(JwtAuthGuard)
  @Get(':id/summary')
  async getSummary(@Param('id') id: string) {
    return this.newsService.getSummary(id);
  }

  @UseGuards(JwtAuthGuard)
  @Get(':id')
  async getById(@Param('id') id: string) {
    return this.newsService.getById(id);
  }

  @UseGuards(JwtAuthGuard)
  @Patch(':id/report')
  async reportNews(@Param('id') newsId: string, @Req() req: Request) {
    const u = (req as any).user;
    const userId = u?.userId ?? u?.sub ?? u?.id ?? u?._id;
    if (!userId) throw new UnauthorizedException('غير مصرح لك');

    return this.newsService.reportNews(newsId, userId);
  }

  @UseGuards(JwtAuthGuard)
  @Post('ingest')
  async ingest(@Body() dto: IngestNewsArticleDto) {
    return this.newsService.ingest(dto);
  }
  
@UseGuards(JwtAuthGuard)
@Get(':id/audio')
async getAudio(@Param('id') id: string, @Query('mode') mode: string) {
  return this.newsService.getOrCreateAudioUrl(
    id,
    mode === 'summary' ? 'summary' : 'full',
  );
}

}
