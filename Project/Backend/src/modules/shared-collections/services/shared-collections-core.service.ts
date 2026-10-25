import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { SharedCollection } from '../schemas/shared-collection.schema';
import { CreateSharedCollectionDto } from '../dto/create-shared-collection.dto';
import { UpdateSharedCollectionDto } from '../dto/update-shared-collection.dto';
import { SharedCollectionMember } from '../schemas/shared-collection-member.schema';
import { MemberRole } from '../../enums/memberRole';
import { User } from '../../users/schemas/user.schema';
import { SharedCollectionAddedNews } from '../schemas/shared-collection-added-news.schema';
import { SharedCollectionJoinRequest } from '../schemas/shared-collection-join-request.schema';
import { SharedCollectionView, SharedCollectionViewDocument } from '../schemas/shared-collection-view.schema';
import { JoinStatus } from '../../enums/joinStatus';
import { SharedCollectionMembersService } from './shared-collection-members.service';
import {SharedCollectionReportedNews,SharedCollectionReportedNewsDocument} from '../schemas/shared-collection-reported-news.schema';

@Injectable()
export class SharedCollectionsCoreService {
  constructor(
    @InjectModel(SharedCollection.name)
    private readonly collectionModel: Model<SharedCollection>,
    @InjectModel(SharedCollectionMember.name)
    private readonly memberModel: Model<SharedCollectionMember>,
    @InjectModel(User.name) private readonly userModel: Model<User>,
    @InjectModel(SharedCollectionAddedNews.name)
    private readonly addedNewsModel: Model<SharedCollectionAddedNews>,
    @InjectModel(SharedCollectionJoinRequest.name)
    private readonly joinRequestModel: Model<SharedCollectionJoinRequest>,
    private readonly memberService: SharedCollectionMembersService,
     @InjectModel(SharedCollectionView.name)
     private readonly collectionViewModel: Model<SharedCollectionViewDocument>,
    @InjectModel(SharedCollectionReportedNews.name)
  private readonly reportedNewsModel: Model<SharedCollectionReportedNewsDocument>,
  ) { }

  // =========================== CREATE ===========================
  async createCollection(ownerId: string, dto: CreateSharedCollectionDto) {
    const ownerObjectId = new Types.ObjectId(ownerId);

    // 1) create SharedCollection
    const collection = await this.collectionModel.create({
      ownerId: ownerObjectId,
      collectionName: dto.collectionName,
      collectionDescription: dto.collectionDescription,
      numOfViewers: 0,
    });

    // 2) create owner membership
    try {
      await this.memberModel.create({
        sharedCollectionId: collection._id,
        userId: ownerObjectId,
        role: MemberRole.OWNER,
      });
    } catch (e: any) {
      if (e?.code === 11000) {
        throw new ConflictException('Owner is already a member of this collection');
      }
      throw e;
    }

    // 3) get owner username
    const me = await this.userModel
      .findById(ownerObjectId)
      .select('username')
      .lean();


    return {
      message: 'تم إنشاء المجموعة المشتركة',
      collection: {
        id: collection._id.toString(),
        collectionName: collection.collectionName ?? '',
        collectionDescription: collection.collectionDescription ?? '',
        numOfViewers: collection.numOfViewers ?? 0,
        ownerUsername: me?.username ?? null,
      },
    };
  }

  // =========================== LISTS ===========================

  async getOthersCollections(viewerId: string) {
    const uid = new Types.ObjectId(viewerId);

    const myOwnedMemberships = await this.memberModel
      .find({ userId: uid })
      .select('sharedCollectionId')
      .lean();

    const excludeIds = myOwnedMemberships
      .map((m: any) => m.sharedCollectionId)
      .filter(Boolean);

    const collections = await this.collectionModel
      .find(excludeIds.length ? { _id: { $nin: excludeIds } } : {})
      .select('_id collectionName collectionDescription numOfViewers')
      .sort({ createdAt: -1 })
      .lean();

    if (!collections.length) return [];

    const collectionIds = collections.map((c: any) => c._id);

    const ownerMemberships = await this.memberModel
      .find({ sharedCollectionId: { $in: collectionIds }, role: MemberRole.OWNER })
      .select('sharedCollectionId userId username')
      .populate({ path: 'userId', select: 'username', model: this.userModel })
      .lean();

    const ownerByCollectionId = new Map<string, string | null>();
    for (const om of ownerMemberships as any[]) {
      const cid = om.sharedCollectionId?.toString?.();
      if (!cid) continue;
      ownerByCollectionId.set(cid, om.username ?? om.userId?.username ?? null);
    }


    const pending = await this.joinRequestModel
      .find({ userId: uid, sharedCollectionId: { $in: collectionIds }, status: JoinStatus.PENDING })
      .select('sharedCollectionId')
      .lean();

    const pendingSet = new Set(pending.map((r: any) => r.sharedCollectionId?.toString?.()).filter(Boolean));

    return collections.map((c: any) => {
      const cid = c._id.toString();
      return {
        id: cid,
        collectionName: c.collectionName ?? '',
        collectionDescription: c.collectionDescription ?? '',
        numOfViewers: c.numOfViewers ?? null,
        ownerUsername: ownerByCollectionId.get(cid) ?? null,
        joinStatus: pendingSet.has(cid) ? JoinStatus.PENDING : 'none',
      };
    });
  }

  // ---------------------------
  // OWNED
  // ---------------------------
  async getOwnedCollections(userId: string) {
    const uid = new Types.ObjectId(userId);

    const ownerMemberships = await this.memberModel
      .find({ userId: uid, role: 'owner' as MemberRole })
      .select('sharedCollectionId')
      .lean();

    const collectionIds = ownerMemberships
      .map((m: any) => m.sharedCollectionId)
      .filter(Boolean);

    if (collectionIds.length === 0) return [];

    const collections = await this.collectionModel
      .find({ _id: { $in: collectionIds } })
      .select('_id collectionName collectionDescription numOfViewers')
      .lean();

    const me = await this.userModel.findById(uid).select('username').lean();
    console.log('ownerMemberships', ownerMemberships.length);
    console.log('collectionIds', collectionIds);

    return collections.map((c: any) => ({
      id: c._id.toString(),
      collectionName: c.collectionName ?? '',
      collectionDescription: c.collectionDescription ?? '',
      numOfViewers: c.numOfViewers ?? null,
      ownerUsername: me?.username ?? null,
    }));
  }



  // ---------------------------
  // JOINED
  // ---------------------------
  async getJoinedCollections(userId: string) {
    const uid = new Types.ObjectId(userId);

    const myMemberships = await this.memberModel
      .find({ userId: uid, role: 'member' as MemberRole })
      .select('sharedCollectionId')
      .lean();

    const joinedCollectionIds = myMemberships
      .map((m: any) => m.sharedCollectionId)
      .filter(Boolean);

    if (joinedCollectionIds.length === 0) return [];

    const collections = await this.collectionModel
      .find({ _id: { $in: joinedCollectionIds } })
      .select('_id collectionName collectionDescription numOfViewers')
      .lean();


    const ownerMemberships = await this.memberModel
      .find({ sharedCollectionId: { $in: joinedCollectionIds }, role: MemberRole.OWNER })
      .select('sharedCollectionId userId username')
      .populate({ path: 'userId', select: 'username' })
      .lean();

    const ownerByCollectionId = new Map<string, string | null>();

    for (const om of ownerMemberships as any[]) {
      const cid = om.sharedCollectionId?.toString();
      if (!cid) continue;

      const snapshot = om.username;
      if (snapshot && typeof snapshot === 'string') {
        ownerByCollectionId.set(cid, snapshot);
        continue;
      }

      const uname = om.userId?.username ?? null;
      ownerByCollectionId.set(cid, uname);
    }

    return collections.map((c: any) => {
      const cid = c._id.toString();
      return {
        id: cid,
        collectionName: c.collectionName ?? '',
        collectionDescription: c.collectionDescription ?? '',
        numOfViewers: c.numOfViewers ?? null,
        ownerUsername: ownerByCollectionId.get(cid) ?? null,
      };
    });
  }


  // =========================== DETAILS ===========================
  async getCollectionDetails(collectionId: string, viewerId?: string) {
    const _id = new Types.ObjectId(collectionId);
    const viewerObjId = viewerId ? new Types.ObjectId(viewerId) : null;

    // 1) collection
    const collection = await this.collectionModel
      .findById(_id)
      .select('_id ownerId collectionName collectionDescription numOfViewers')
      .lean();

    if (!collection) throw new NotFoundException('لم يتم العثور على مجموعة مشتركة');

    // 2) members
    const memberships = await this.memberModel
      .find({ sharedCollectionId: _id })
      .select('_id userId role')
      .populate({ path: 'userId', select: 'username', model: this.userModel })
      .lean();

    const members = memberships.map((m: any) => ({
      id: m._id.toString(),
      userId: m.userId?._id?.toString?.() ?? null,
      username: m.userId?.username ?? null,
      role: (m.role === MemberRole.OWNER || m.role === 'owner') ? 'owner' : 'member',
    }));

    // 3) owner username
    const ownerUser = await this.userModel
      .findById(collection.ownerId)
      .select('username')
      .lean();


    const isOwned = viewerObjId ? collection.ownerId.toString() === viewerObjId.toString() : false;

// 5) added news
let reportedAddedNewsIds: Types.ObjectId[] = [];

if (viewerObjId && !isOwned) {
  const reportedDocs = await this.reportedNewsModel
    .find({
      sharedCollectionId: _id,
      reportedByUserId: viewerObjId,
    })
    .select('addedNewsId')
    .lean();

  reportedAddedNewsIds = reportedDocs
    .map((r: any) => r.addedNewsId)
    .filter(Boolean);
}

const addedNewsDocs = await this.addedNewsModel
  .find({
    sharedCollectionId: _id,
    isArchived: { $ne: true },
    ...(reportedAddedNewsIds.length > 0
      ? { _id: { $nin: reportedAddedNewsIds } }
      : {}),
  })
  .sort({ createdAt: -1 })
  .select(
    '_id sharedCollectionId originalNewsId addedByUserId newsTitle newsContent newsSource sourceLink category publishDate ttsAudioURLforContent ttsAudioURLforSummary summaryText createdAt isArchived',
  )
  .lean();

const addedNews = addedNewsDocs.map((n: any) => ({
  id: n._id.toString(),
  sharedCollectionId: n.sharedCollectionId?.toString?.() ?? collection._id.toString(),
  originalNewsId: n.originalNewsId?.toString?.() ?? '',
  addedByUserId: n.addedByUserId?.toString?.() ?? '',
  newsTitle: n.newsTitle ?? '',
  newsContent: n.newsContent ?? '',
  newsSource: n.newsSource ?? '',
  sourceLink: n.sourceLink ?? '',
  category: n.category ?? '',
  publishDate: n.publishDate ? new Date(n.publishDate).toISOString() : null,
  ttsAudioURLforContent: n.ttsAudioURLforContent ?? '',
  ttsAudioURLforSummary: n.ttsAudioURLforSummary ?? '',
  summaryText: n.summaryText ?? '',
  createdAt: n.createdAt ? new Date(n.createdAt).toISOString() : null,
  isArchived: n.isArchived === true,
  sharedByCreator: n.addedByUserId?.toString?.() === collection.ownerId.toString(),
  isAddedByMe: viewerObjId
    ? n.addedByUserId?.toString?.() === viewerObjId.toString()
    : false,
}));

    return {
      message: 'تم جلب تفاصيل المجموعة',
      collection: {
        id: collection._id.toString(),
        collectionName: collection.collectionName ?? '',
        collectionDescription: collection.collectionDescription ?? '',
        numOfViewers: collection.numOfViewers ?? 0,
        ownerUsername: ownerUser?.username ?? null,
        isOwned,
        members,
      },
      addedNews,
    };
  }



   // ======================== VIEW COUNTER ========================
  async incrementView(collectionId: string, userId: string) {
    if (!Types.ObjectId.isValid(collectionId)) {
      throw new NotFoundException('معرّف المجموعة غير صالح');
    }

    if (!Types.ObjectId.isValid(userId)) {
      throw new NotFoundException('معرّف المستخدم غير صالح');
    }

    const collectionObjectId = new Types.ObjectId(collectionId);
    const userObjectId = new Types.ObjectId(userId);

    const collection = await this.collectionModel
      .findById(collectionObjectId)
      .select('_id numOfViewers')
      .lean();

    if (!collection) {
      throw new NotFoundException('لم يتم العثور على المجموعة المشتركة');
    }

    const existingView = await this.collectionViewModel
      .findOne({
        collectionId: collectionObjectId,
        userId: userObjectId,
      })
      .select('_id')
      .lean();

    if (existingView) {
      return {
        collectionId,
        numOfViewers: collection.numOfViewers ?? 0,
        alreadyViewed: true,
        message: 'تم احتساب المشاهدة مسبقًا',
      };
    }

    try {
      await this.collectionViewModel.create({
        collectionId: collectionObjectId,
        userId: userObjectId,
      });
    } catch (e: any) {
      if (e?.code === 11000) {
        const sameCollection = await this.collectionModel
          .findById(collectionObjectId)
          .select('numOfViewers')
          .lean();

        return {
          collectionId,
          numOfViewers: sameCollection?.numOfViewers ?? 0,
          alreadyViewed: true,
          message: 'تم احتساب المشاهدة مسبقًا',
        };
      }
      throw e;
    }

    const updated = await this.collectionModel.findByIdAndUpdate(
      collectionObjectId,
      { $inc: { numOfViewers: 1 } },
      { new: true, projection: { numOfViewers: 1 } },
    );

    if (!updated) {
      throw new NotFoundException('لم يتم العثور على المجموعة المشتركة');
    }

    return {
      collectionId,
      numOfViewers: updated.numOfViewers,
      alreadyViewed: false,
      message: 'ازدادت عدد المشاهدات',
    };
  }

  // =========================== UPDATE ===========================
  async updateCollection(collectionId: string, dto: UpdateSharedCollectionDto) {
    const _id = new Types.ObjectId(collectionId);

    const updates: any = {};
    if (dto.collectionName) updates.collectionName = dto.collectionName;
    if (dto.collectionDescription) updates.collectionDescription = dto.collectionDescription;

    const updated = await this.collectionModel.findByIdAndUpdate(
      _id,
      { $set: updates },
      { new: true }
    );

    if (!updated) {
      throw new NotFoundException('لم يتم العثور على المجموعة المشتركة');
    }

    const ownerUser = await this.userModel
      .findById(updated.ownerId)
      .select('username')
      .lean();

    return {
      message: 'تم تحديث المجموعة بنجاح',
      collection: {
        id: updated._id.toString(),
        collectionName: updated.collectionName ?? '',
        collectionDescription: updated.collectionDescription ?? '',
        numOfViewers: updated.numOfViewers ?? 0,
        ownerUsername: ownerUser?.username ?? null,
      },
    };
  }

  // =========================== DELETE ===========================
  async deleteCollection(collectionId: string) {
    const _id = new Types.ObjectId(collectionId);

    const deleted = await this.collectionModel.findByIdAndDelete(_id);

    if (!deleted) {
      throw new NotFoundException('لم يتم العثور على المجموعة المشتركة');
    }

    await this.memberService.deleteAllMembers(collectionId);
    await this.addedNewsModel.deleteMany({ sharedCollectionId: _id });
    await this.joinRequestModel.deleteMany({ sharedCollectionId: _id });

    return {
      collectionId,
      message: 'تم حذف المجموعة وجميع البيانات المرتبطة بها بنجاح'
    };
  }
  // =========================== SHARE LINK GENERATION ===========================
async getShareLink(collectionId: string) {
  const collection = await this.collectionModel
    .findById(collectionId)
    .select('_id')
    .lean();

  if (!collection) {
    throw new NotFoundException('لم يتم العثور على المجموعة المشتركة');
  }

const shareableLink = `https://madarnews.app/collection/${collectionId}`;

  return {
    link: shareableLink,
    message: 'رابط المشاركة جاهز',
  };
}





}