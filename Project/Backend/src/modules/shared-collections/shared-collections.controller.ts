import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { SharedCollectionsCoreService } from './services/shared-collections-core.service';
import { SharedCollectionArticlesService } from './services/shared-collection-articles.service';
import { SharedCollectionReportsService } from './services/shared-collection-reports.service';
import { SharedCollectionJoinRequestsService } from './services/shared-collection-join-requests.service';
import { SharedCollectionMembersService } from './services/shared-collection-members.service';
import { CreateSharedCollectionDto } from './dto/create-shared-collection.dto';
import { UpdateSharedCollectionDto } from './dto/update-shared-collection.dto';
import { ReportAddedNewsDto } from './dto/report-added-news.dto';
import { DecideJoinRequestDto } from './dto/decide-join-request.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { Request } from 'express';

@Controller('shared-collections')
export class SharedCollectionsController {
  constructor(
    private readonly core: SharedCollectionsCoreService,
    private readonly articles: SharedCollectionArticlesService,
    private readonly reports: SharedCollectionReportsService,
    private readonly joinRequests: SharedCollectionJoinRequestsService,
    private readonly members: SharedCollectionMembersService,
  ) {}

  @UseGuards(JwtAuthGuard)
  @Post('createCollection')
  create(@Req() req: Request, @Body() dto: CreateSharedCollectionDto) {
    const ownerId = (req as any).user?.userId;
    return this.core.createCollection(ownerId, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('getOthersCollections')
  async getOthers(@Req() req: Request) {
    const u = (req as any).user;
    const viewerId = u?.userId ?? u?.sub ?? u?.id ?? u?._id;
    if (!viewerId) throw new UnauthorizedException('غير مصرح لك');
    return this.core.getOthersCollections(viewerId);
  }

  @UseGuards(JwtAuthGuard)
  @Get('getOwnedCollections')
  async getOwned(@Req() req: Request) {
    const u = (req as any).user;
    const userId = u?.userId ?? u?.sub ?? u?.id ?? u?._id;
    if (!userId) throw new UnauthorizedException('غير مصرح لك');
    return this.core.getOwnedCollections(userId);
  }

  @UseGuards(JwtAuthGuard)
  @Get('getJoinedCollections')
  async getJoined(@Req() req: Request) {
    const u = (req as any).user;
    const userId = u?.userId ?? u?.sub ?? u?.id ?? u?._id;
    if (!userId) throw new UnauthorizedException('غير مصرح لك');
    return this.core.getJoinedCollections(userId);
  }

  @UseGuards(JwtAuthGuard)
  @Get('getcollectionDetails')
  async getDetails(@Req() req: Request, @Query('id') id: string) {
    const u = (req as any).user;
    const viewerId = u?.userId ?? u?.sub ?? u?.id ?? u?._id;
    if (!id) throw new BadRequestException('معرف المجموعة مفقود');
    if (!viewerId) throw new UnauthorizedException('غير مصرح لك');
    return this.core.getCollectionDetails(id, viewerId);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/incrementView')
  incrementView(@Param('id') id: string, @Req() req: Request) {
    const u = (req as any).user;
    const userId = u?.userId ?? u?.sub ?? u?.id ?? u?._id;
    if (!userId) throw new UnauthorizedException('لم يتم العثور على المستخدم');
    return this.core.incrementView(id, userId.toString());
  }

  @UseGuards(JwtAuthGuard)
  @Patch(':id/updateCollection')
  update(@Param('id') id: string, @Body() dto: UpdateSharedCollectionDto) {
    return this.core.updateCollection(id, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':id/deleteCollection')
  delete(@Param('id') id: string) {
    return this.core.deleteCollection(id);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/addArticle')
  addArticleToCollection(
    @Req() req: Request,
    @Param('id') collectionId: string,
    @Body() body: any,
  ) {
    const u = (req as any).user;
    const addedByUID = u?.userId ?? u?.sub ?? u?.id ?? u?._id;
    return this.articles.addArticleToCollection(collectionId, body, addedByUID);
  }

  @UseGuards(JwtAuthGuard)
  @Get(':collectionId/addedNews/:addedNewsId/summary')
  async getAddedNewsSummary(
    @Param('collectionId') collectionId: string,
    @Param('addedNewsId') addedNewsId: string,
  ) {
    return this.articles.getAddedNewsSummary(collectionId, addedNewsId);
  }

@UseGuards(JwtAuthGuard)
@Get(':id/addedNews/:addedNewsId/audio')
async getAddedNewsAudio(
  @Param('id') collectionId: string,
  @Param('addedNewsId') addedNewsId: string,
  @Query('mode') mode: string,
) {
  return this.articles.getOrCreateAddedNewsAudioUrl(
    collectionId,
    addedNewsId,
    mode === 'summary' ? 'summary' : 'full',
  );
}

  @UseGuards(JwtAuthGuard)
  @Patch(':id/addedNews/:addedNewsId/archive')
  archiveAddedNews(
    @Req() req: Request,
    @Param('id') collectionId: string,
    @Param('addedNewsId') addedNewsId: string,
  ) {
    const u = (req as any).user;
    const actorUID = u?.userId ?? u?.sub ?? u?.id ?? u?._id;
    return this.articles.archiveAddedNews(collectionId, addedNewsId, actorUID);
  }

  @UseGuards(JwtAuthGuard)
  @Patch(':id/addedNews/:addedNewsId/restore')
  restoreAddedNews(
    @Req() req: Request,
    @Param('id') collectionId: string,
    @Param('addedNewsId') addedNewsId: string,
  ) {
    const u = (req as any).user;
    const actorUID = u?.userId ?? u?.sub ?? u?.id ?? u?._id;
    return this.articles.restoreAddedNews(collectionId, addedNewsId, actorUID);
  }

  @UseGuards(JwtAuthGuard)
  @Get(':id/archivedNews')
  getArchivedNews(
    @Req() req: Request,
    @Param('id') collectionId: string,
  ) {
    const u = (req as any).user;
    const actorUID = u?.userId ?? u?.sub ?? u?.id ?? u?._id;
    return this.articles.getArchivedNews(collectionId, actorUID);
  }

@UseGuards(JwtAuthGuard)
@Delete(':id/addedNews/:addedNewsId')
deleteAddedNews(
  @Req() req: Request,
  @Param('id') collectionId: string,
  @Param('addedNewsId') addedNewsId: string,
) {
  const u = (req as any).user;
  const actorUID = u?.userId ?? u?.sub ?? u?.id ?? u?._id;

  if (!actorUID) {
    throw new UnauthorizedException('غير مصرح لك');
  }

  return this.articles.deleteAddedNews(
    collectionId,
    addedNewsId,
    actorUID,
  );
}

  @UseGuards(JwtAuthGuard)
  @Get(':id/reports')
  getReports(@Param('id') collectionId: string, @Req() req: any) {
    return this.reports.getReports(collectionId, req.user.userId);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':collectionId/addedNews/:addedNewsId/report')
  reportAddedNews(
    @Param('collectionId') collectionId: string,
    @Param('addedNewsId') addedNewsId: string,
    @Body() dto: ReportAddedNewsDto,
    @Req() req: any,
  ) {
    return this.reports.reportAddedNews(
      collectionId,
      addedNewsId,
      req.user.userId,
      dto,
    );
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/joinRequests/create')
  createJoinRequest(@Param('id') collectionId: string, @Req() req: Request) {
    const u = (req as any).user;
    const userId = u?.userId ?? u?.sub ?? u?.id ?? u?._id;
    if (!collectionId) throw new BadRequestException('معرف المجموعة مفقود');
    if (!userId) throw new UnauthorizedException('غير مصرح لك');
    return this.joinRequests.createJoinRequest(collectionId, userId);
  }

  @UseGuards(JwtAuthGuard)
  @Patch(':id/joinRequests/:requestId/decide')
  decideJoinRequest(
    @Param('id') collectionId: string,
    @Param('requestId') requestId: string,
    @Body() dto: DecideJoinRequestDto,
    @Req() req: Request,
  ) {
    const u = (req as any).user;
    const ownerId = u?.userId ?? u?.sub ?? u?.id ?? u?._id;
    if (!collectionId) throw new BadRequestException('معرف المجموعة مفقود');
    if (!requestId) throw new BadRequestException('معرف الطلب مفقود');
    if (!ownerId) throw new UnauthorizedException('غير مصرح لك');
    return this.joinRequests.decideJoinRequest(
      collectionId,
      requestId,
      ownerId,
      dto.decision,
    );
  }

  @UseGuards(JwtAuthGuard)
  @Get(':id/joinRequests')
  getJoinRequests(@Param('id') collectionId: string, @Req() req: Request) {
    const u = (req as any).user;
    const ownerId = u?.userId ?? u?.sub ?? u?.id ?? u?._id;
    if (!collectionId) throw new BadRequestException('معرف المجموعة مفقود');
    if (!ownerId) throw new UnauthorizedException('غير مصرح لك');
    return this.joinRequests.getJoinRequestsForCollection(collectionId, ownerId);
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':id/members/leave')
  leaveCollection(@Param('id') collectionId: string, @Req() req: Request) {
    const u = (req as any).user;
    const userId = u?.userId ?? u?.sub ?? u?.id ?? u?._id;
    if (!collectionId) throw new BadRequestException('معرف المجموعة مفقود');
    if (!userId) throw new UnauthorizedException('غير مصرح لك');
    return this.members.leaveCollection(collectionId, userId);
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':id/members/:memberId')
  deleteMember(
    @Param('id') collectionId: string,
    @Param('memberId') memberId: string,
  ) {
    if (memberId === 'leave') {
      throw new BadRequestException('استخدم مسار المغادرة الصحيح');
    }
    return this.members.deleteMember(collectionId, memberId);
  }

// =========================== SHARE LINK GENERATION ===========================
  @UseGuards(JwtAuthGuard)
@Get(':id/share-link')
getShareLink(@Param('id') collectionId: string) {
  return this.core.getShareLink(collectionId);
}
}