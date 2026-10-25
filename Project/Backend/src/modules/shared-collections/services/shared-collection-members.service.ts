//shared-collection-members.service.ts
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { SharedCollectionMember } from '../schemas/shared-collection-member.schema';
import { MemberRole } from 'src/modules/enums/memberRole';
import { User } from 'src/modules/users/schemas/user.schema';
import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { SharedCollectionJoinRequest } from '../schemas/shared-collection-join-request.schema';

@Injectable()
export class SharedCollectionMembersService {
  constructor(
    @InjectModel(SharedCollectionMember.name)
    private readonly memberModel: Model<SharedCollectionMember>,
     @InjectModel(User.name)
    private readonly userModel: Model<User>,
      @InjectModel(SharedCollectionJoinRequest.name)
  private readonly joinRequestModel: Model<SharedCollectionJoinRequest>,
  ) {}

 async getAllMembers(collectionId: string) {
    const _id = new Types.ObjectId(collectionId);

    const memberships = await this.memberModel
      .find({ sharedCollectionId: _id })
      .select('_id userId role')
      .populate({ path: 'userId', select: 'username', model: this.userModel })
      .lean();

    const members = memberships.map((m: any) => ({
      id: m._id.toString(),
      userId: m.userId?._id?.toString?.() ?? null,
      username: m.userId?.username ?? null,
      role: m.role, 
    }));

    return { collectionId, members };
  }

  async addMemberToCollection(
    collectionId: string,
    userId: string,
    role: MemberRole = MemberRole.MEMBER,
  ) {
    const _collectionId = new Types.ObjectId(collectionId);
    const _userId = new Types.ObjectId(userId);

    await this.memberModel.updateOne(
      { sharedCollectionId: _collectionId, userId: _userId },
      { $setOnInsert: { role } },
      { upsert: true },
    );

    return { collectionId, userId, role, message: 'تم إضافة العضو '};
  }

  async deleteMember(collectionId: string, memberId: string) {
  const _collectionId = new Types.ObjectId(collectionId);
  const _memberId = new Types.ObjectId(memberId);

  const membership = await this.memberModel.findOne({
    _id: _memberId,
    sharedCollectionId: _collectionId,
  });

  if (!membership) {
    throw new NotFoundException('العضو غير موجود في هذه المجموعة');
  }

  if (membership.role === MemberRole.OWNER) {
    throw new BadRequestException('لا يمكن حذف مالك المجموعة من الأعضاء');
  }

  const removedUserId = membership.userId;

  await this.memberModel.deleteOne({
    _id: _memberId,
    sharedCollectionId: _collectionId,
  });


  await this.joinRequestModel.deleteOne({
    sharedCollectionId: _collectionId,
    userId: removedUserId,
  });

  return {
    collectionId,
    memberId,
    removedUserId: removedUserId.toString(),
    message: 'تم إزالة العضو بنجاح',
  };
}

  async leaveCollection(collectionId: string, userId: string) {
    const _collectionId = new Types.ObjectId(collectionId);
    const _userId = new Types.ObjectId(userId);
  
    const membership = await this.memberModel.findOne({
      sharedCollectionId: _collectionId,
      userId: _userId,
    });
  
    if (!membership) {
      throw new NotFoundException('أنت لست عضوًا في هذه المجموعة');
    }
  
    if (membership.role === MemberRole.OWNER) {
      throw new BadRequestException('المالك لا يمكنه مغادرة المجموعة. احذف المجموعة بدلاً من ذلك.');
    }
  
    await this.memberModel.deleteOne({
      sharedCollectionId: _collectionId,
      userId: _userId,
    });
  
    return { 
      collectionId, 
      userId,
      message: 'تم مغادرة المجموعة بنجاح' 
    };
  }
  async deleteAllMembers(collectionId: string) {
    const _collectionId = new Types.ObjectId(collectionId);
  
    await this.memberModel.deleteMany({
      sharedCollectionId: _collectionId,
    });
  
    return { message: 'تم حذف جميع الأعضاء' };
  }



}
