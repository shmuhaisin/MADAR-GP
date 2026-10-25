import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Notification, NotifType } from './schemas/notification.schema';
import { User } from '../users/schemas/user.schema';
import { FirebaseService } from '../firebase/firebase.service';

@Injectable()
export class NotificationsService {
  constructor(
    @InjectModel(Notification.name)
    private readonly notifModel: Model<Notification>,
    @InjectModel(User.name)
    private readonly userModel: Model<User>,
    private readonly firebaseService: FirebaseService,
  ) {}

  /**
   * Convert any id-like value into a clean 24-char hex string.
   * Accepts: ObjectId | string | null/undefined
   */
  private toIdString(value: unknown): string | null {
    if (!value) return null;
    if (value instanceof Types.ObjectId) return value.toString();
    if (typeof value === 'string' && Types.ObjectId.isValid(value)) {
      return value;
    }
    return null;
  }

  async getNotifications(
    userId: string,
    query: { type?: string; interest?: string; keyword?: string },
  ) {
    if (!Types.ObjectId.isValid(userId)) {
      throw new BadRequestException('Invalid userId');
    }

    // userId in DB may be stored as string (n8n) or ObjectId (NestJS) — match both
    const filter: any = {
      $or: [
        { userId: userId },
        { userId: new Types.ObjectId(userId) },
      ],
    };

    if (query.type && query.type !== 'all') {
      filter.notifType = query.type;
    }

    if (query.interest) {
      filter.notifType = NotifType.SEMANTIC;
      filter.interest = query.interest;
    }

    if (query.keyword) {
      filter.notifType = NotifType.SEMANTIC;
      filter.$and = [
        {
          $or: [
            { keyword: query.keyword },
            { notifTitle: { $regex: query.keyword, $options: 'i' } },
            { notifMessage: { $regex: query.keyword, $options: 'i' } },
          ],
        },
      ];
    }

    const docs = await this.notifModel
      .find(filter)
      .sort({ createdAt: -1 })
      .lean();

    return {
      message: 'تم جلب الإشعارات',
      notifications: docs.map((d: any) => ({
        id: d.notificationID,
        title: d.notifTitle,
        message: d.notifMessage,
        type: d.notifType,
        date: d.createdAt?.toISOString?.() ?? '',
        isRead: d.isRead ?? false,
        status: d.status ?? null,
        interest: d.interest ?? null,
        keyword: d.keyword ?? null,
        relatedNewsId: this.toIdString(d.relatedNewsID),
        collectionId: this.toIdString(d.collectionId),
      })),
    };
  }

  async getNotificationDetails(userId: string, notificationId: string) {
    if (!Types.ObjectId.isValid(userId)) {
      throw new BadRequestException('Invalid userId');
    }

    const doc = await this.notifModel
      .findOne({
        $or: [
          { userId: userId },
          { userId: new Types.ObjectId(userId) },
        ],
        notificationID: Number(notificationId),
      })
      .lean();

    if (!doc) throw new NotFoundException('الإشعار غير موجود');

    return {
      message: 'تم جلب تفاصيل الإشعار',
      notification: {
        id: (doc as any).notificationID,
        title: (doc as any).notifTitle,
        message: (doc as any).notifMessage,
        type: (doc as any).notifType,
        date: (doc as any).createdAt?.toISOString?.() ?? '',
        isRead: (doc as any).isRead ?? false,
        status: (doc as any).status ?? null,
        interest: (doc as any).interest ?? null,
        keyword: (doc as any).keyword ?? null,
        relatedNewsId: this.toIdString((doc as any).relatedNewsID),
      },
    };
  }

  async getUnreadCount(userId: string) {
    if (!Types.ObjectId.isValid(userId)) {
      throw new BadRequestException('Invalid userId');
    }

    const count = await this.notifModel.countDocuments({
      $or: [
        { userId: userId },
        { userId: new Types.ObjectId(userId) },
      ],
      isRead: false,
    });
    return { unreadCount: count };
  }

  async markAllAsRead(userId: string) {
    if (!Types.ObjectId.isValid(userId)) {
      throw new BadRequestException('Invalid userId');
    }

    await this.notifModel.updateMany(
      {
        $or: [
          { userId: userId },
          { userId: new Types.ObjectId(userId) },
        ],
        isRead: false,
      },
      { $set: { isRead: true } },
    );
    return { message: 'تم تعليم جميع الإشعارات كمقروءة' };
  }

  async createNotification(data: {
    userId: string;
    title: string;
    message: string;
    type: NotifType;
    status?: string;
    interest?: string;
    keyword?: string;
    relatedNewsID?: string;
    collectionId?: string;
  }) {
    if (!Types.ObjectId.isValid(data.userId)) {
      throw new BadRequestException('Invalid userId');
    }

    const notif = await this.notifModel.create({
      userId: new Types.ObjectId(data.userId),
      notifTitle: data.title,
      notifMessage: data.message,
      notifType: data.type,
      isRead: false,
      status: data.status ?? null,
      interest: data.interest ?? null,
      keyword: data.keyword ?? null,
      relatedNewsID: data.relatedNewsID ?? null,
      collectionId: data.collectionId ?? null,
    });

    const user = await this.userModel
      .findById(data.userId)
      .select('fcmToken')
      .lean();
    const token = (user as any)?.fcmToken;
    if (token) {
      await this.firebaseService.sendPushNotification(
        token,
        data.title,
        data.message,
        { type: data.type, collectionId: data.collectionId ?? '' },
      );
    }

    return notif;
  }
}