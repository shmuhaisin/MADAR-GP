import { Injectable, NotFoundException, ConflictException, ForbiddenException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { SharedCollectionJoinRequest } from '../schemas/shared-collection-join-request.schema';
import { JoinStatus } from '../../enums/joinStatus';
import { SharedCollection } from '../schemas/shared-collection.schema';
import { SharedCollectionMembersService } from './shared-collection-members.service';
import { NotificationsService } from '../../notifications/notifications.service';
import { NotifType } from '../../notifications/schemas/notification.schema';
import { User } from '../../users/schemas/user.schema';
import { Notification } from '../../notifications/schemas/notification.schema';

@Injectable()
export class SharedCollectionJoinRequestsService {
  constructor(
    @InjectModel(SharedCollectionJoinRequest.name)
    private readonly joinRequestModel: Model<SharedCollectionJoinRequest>,
    @InjectModel(SharedCollection.name)
    private readonly sharedCollectionModel: Model<SharedCollection>,

    private readonly membersService: SharedCollectionMembersService,

    private readonly notificationsService: NotificationsService,

    @InjectModel(User.name)
    private readonly userModel: Model<User>,
    @InjectModel(Notification.name)         
    private readonly notifModel: Model<Notification>,
  ) { }

  async createJoinRequest(collectionId: string, userId: string) {
    const _collectionId = new Types.ObjectId(collectionId);
    const _userId = new Types.ObjectId(userId);

    try {
      const doc = await this.joinRequestModel.create({
        sharedCollectionId: _collectionId,
        userId: _userId,
        status: JoinStatus.PENDING,
      });
      const collection = await this.sharedCollectionModel.findById(collectionId).lean();
      const requestingUser = await this.userModel
        .findById(_userId)
        .select('username')
        .lean();

      const username = (requestingUser as any)?.username ?? userId;
      await this.notificationsService.createNotification({
        userId: (collection as any).ownerId.toString(),
        title: 'طلب انضمام جديد إلى مجموعتك',
        message: `قام ${username} بإرسال طلب انضمام إلى مجموعة ${(collection as any)?.collectionName ?? ''}`, 
        type: NotifType.JOIN_REQ,
        collectionId: collectionId, 
      });
      return {
        message: 'تم إرسال طلب الانضمام',
        request: {
          id: doc._id.toString(),
          sharedCollectionId: collectionId,
          userId,
          status: doc.status,
          createdAt: (doc as any).createdAt?.toISOString?.() ?? null,
        },
      };
    } catch (e: any) {
      if (e?.code === 11000) {
        throw new ConflictException('تم إرسال طلب الانضمام مسبقًا');
      }
      throw e;
    }
  }


  //Helper to ensure ownerID
  private async assertOwner(collectionId: string, ownerId: string) {
    const col = await this.sharedCollectionModel
      .findById(collectionId)
      .select('_id ownerId')
      .lean();

    if (!col) throw new NotFoundException('لا توجد مجموعة مشاركة');

    const isOwner = col.ownerId?.toString?.() === ownerId;
    if (!isOwner) throw new ForbiddenException('غير مصرح لك');
  }



  async decideJoinRequest(
    collectionId: string,
    requestId: string,
    ownerId: string,
    decision: 'accept' | 'reject',
  ) {
    await this.assertOwner(collectionId, ownerId);

    const _collectionId = new Types.ObjectId(collectionId);
    const _requestId = new Types.ObjectId(requestId);

    const reqDoc = await this.joinRequestModel.findOne({
      _id: _requestId,
      sharedCollectionId: _collectionId,
    });

    if (!reqDoc) throw new NotFoundException('طلب الانضمام غير موجود لهذه المجموعة');


    if (reqDoc.status !== JoinStatus.PENDING) {
      throw new ConflictException(`الطلب بالفعل ${reqDoc.status}`);
    }

    if (decision === 'accept') {
      reqDoc.status = JoinStatus.ACCEPTED;
      await reqDoc.save();

      // Add member 
      await this.membersService.addMemberToCollection(collectionId, reqDoc.userId.toString());
      const colAccept = await this.sharedCollectionModel.findById(collectionId).lean();
      await this.notifModel.deleteOne({
      notifType: 'joinReq',
      collectionId: collectionId,
  userId: new Types.ObjectId((colAccept  as any).ownerId),    });
      await this.notificationsService.createNotification({
        userId: reqDoc.userId.toString(),
        title: `تم قبول طلب انضمامك إلى ${(colAccept as any)?.collectionName ?? 'المجموعة'}`,
        message: `تم قبول طلب انضمامك إلى المجموعة المشتركة ${(colAccept as any)?.collectionName ?? ''}, يمكنك الآن مشاهدة الأخبار`,
        type: NotifType.REQ_REPLY,
        status: 'accepted',
      });
      // TODO: create notification "approved"
      return {
        message: 'تم قبول الطلب',
        request: {
          id: reqDoc._id.toString(),
          sharedCollectionId: collectionId,
          userId: reqDoc.userId.toString(),
          status: reqDoc.status,
        },
      };
    }

    // decision === 'reject'
    reqDoc.status = JoinStatus.REJECTED;
    await reqDoc.save();

    // TODO: create notification "rejected"

    await this.joinRequestModel.deleteOne({
      _id: _requestId,
      sharedCollectionId: _collectionId,
    });
    const colReject = await this.sharedCollectionModel.findById(collectionId).lean();
      await this.notifModel.deleteOne({
    notifType: 'joinReq',
    collectionId: collectionId,
  userId: new Types.ObjectId((colReject as any).ownerId),
  });
    await this.notificationsService.createNotification({
      userId: reqDoc.userId.toString(),
      title: `تم رفض طلب انضمامك إلى ${(colReject as any)?.collectionName ?? 'المجموعة'}`,
      message: `تم رفض طلب انضمامك إلى المجموعة المشتركة ${(colReject as any)?.collectionName ?? ''}`,
      type: NotifType.REQ_REPLY,
      status: 'rejected',
    });
    return {
      message: 'تم رفض الطلب',
      request: {
        id: reqDoc._id.toString(),
        sharedCollectionId: collectionId,
        userId: reqDoc.userId.toString(),
        status: JoinStatus.REJECTED,
        deleted: true,
      },
    };
  }

  //GET ALL JOIN REQUESTS
  async getJoinRequestsForCollection(collectionId: string, ownerId: string) {
    await this.assertOwner(collectionId, ownerId);

    const _collectionId = new Types.ObjectId(collectionId);

    const docs = await this.joinRequestModel
      .find({ sharedCollectionId: _collectionId, status: JoinStatus.PENDING })
      .select('_id userId status createdAt')
      .populate({ path: 'userId', select: 'username' })
      .lean();

    return {
      message: 'تم جلب طلبات الانضمام',
      requests: docs.map((d: any) => ({
        id: d._id.toString(),
        username: d.userId?.username ?? '',
        requestDate: d.createdAt ? new Date(d.createdAt).toISOString() : '',
        status: d.status,
      })),
    };
  }



}
