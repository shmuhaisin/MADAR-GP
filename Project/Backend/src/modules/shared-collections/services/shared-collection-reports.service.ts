import { Injectable, ConflictException , ForbiddenException,NotFoundException} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model,Types } from 'mongoose';
import { SharedCollectionReportedNews } from '../schemas/shared-collection-reported-news.schema';
import {ReportAddedNewsDto} from '../dto/report-added-news.dto';
import { SharedCollection } from '../schemas/shared-collection.schema';
import { SharedCollectionMember } from '../schemas/shared-collection-member.schema';
import { User } from 'src/modules/users/schemas/user.schema';
import { MemberRole } from 'src/modules/enums/memberRole';
import { SharedCollectionAddedNews } from '../schemas/shared-collection-added-news.schema';

@Injectable()
export class SharedCollectionReportsService {
  constructor(
    @InjectModel(SharedCollectionReportedNews.name)
    private readonly reportModel: Model<SharedCollectionReportedNews>,
      @InjectModel(SharedCollection.name)
    private readonly collectionModel: Model<SharedCollection>,

    @InjectModel(SharedCollectionMember.name)
    private readonly memberModel: Model<SharedCollectionMember>,

    @InjectModel(SharedCollectionAddedNews.name)
    private readonly addedNewsModel: Model<SharedCollectionAddedNews>,

    @InjectModel(User.name)
    private readonly userModel: Model<User>,
  ) {}


  async getReports(collectionId: string, ownerId: string) {
    const _cid = new Types.ObjectId(collectionId);
    const _ownerId = new Types.ObjectId(ownerId);

    // 1) owner check
    const isOwner = await this.memberModel.exists({
      sharedCollectionId: _cid,
      userId: _ownerId,
      role: MemberRole.OWNER,
    });
    if (!isOwner) throw new ForbiddenException('Not allowed');

    // 2) get reports + populate
    const reports = await this.reportModel
      .find({ sharedCollectionId: _cid })
      .sort({ reportedAt: -1 })
      .populate({ path: 'reportedByUserId', select: 'username', model: this.userModel })
      .populate({
        path: 'addedNewsId',
        
        select: 'newsTitle addedByUserId publishDate',
        model: this.addedNewsModel,
        populate: { path: 'addedByUserId', select: 'username', model: this.userModel },
      })
      .lean();

    // 3) shape for frontend
    return {
      collectionId,
      reports: (reports as any[]).map((r) => ({
        id: r._id.toString(),
        reportReason: r.reportReason,
        reportedAt: r.reportedAt,

        reportedBy: {
          userId: r.reportedByUserId?._id?.toString?.() ?? null,
          username: r.reportedByUserId?.username ?? null,
        },

        news: {
          addedNewsId: r.addedNewsId?._id?.toString?.() ?? null,
          title: r.addedNewsId?.newsTitle ?? null,
          publishDate: r.addedNewsId?.publishDate ?? null,
          addedBy: {
            userId: r.addedNewsId?.addedByUserId?._id?.toString?.() ?? null,
            username: r.addedNewsId?.addedByUserId?.username ?? null,
          },
        },
      })),
    };
  }


  // Report
  async reportAddedNews(
    collectionId: string,
    addedNewsId: string,
    reporterId: string,
    dto: ReportAddedNewsDto,
  ) {
    const _cid = new Types.ObjectId(collectionId);
    const _nid = new Types.ObjectId(addedNewsId);
    const _uid = new Types.ObjectId(reporterId);

    // 1) ensure user is member (owner OR member)
    const membership = await this.memberModel.findOne({
      sharedCollectionId: _cid,
      userId: _uid,
    });

    if (!membership) throw new ForbiddenException('أنت لست عضوا في هذه المجموعة');

    // 2) ensure addedNews exists + belongs to collection
    const news = await this.addedNewsModel.findOne({ _id: _nid, sharedCollectionId: _cid }).lean();
    if (!news) throw new NotFoundException('Added news not found in this collection');

    // 3) create report 
    try {
      const created = await this.reportModel.create({
        sharedCollectionId: _cid,
        addedNewsId: _nid,
        reportedByUserId: _uid,
        reportReason: dto.reportReason,
        reportedAt: new Date(),
      });

      return {
        message: 'تم إرسال البلاغ بنجاح',
        report: {
          id: created._id.toString(),
          sharedCollectionId: collectionId,
          addedNewsId: addedNewsId,
          reportReason: created.reportReason,
          reportedAt: created.reportedAt,
        },
      };
    } catch (e: any) {
      if (e?.code === 11000) throw new ConflictException('لقد قمت بالإبلاغ مسبقا');
      throw e;
    }
  }

}
