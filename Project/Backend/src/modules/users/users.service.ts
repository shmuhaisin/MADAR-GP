import {
  BadRequestException,
  ConflictException,
  Injectable,
  InternalServerErrorException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { JwtService } from '@nestjs/jwt';
import { User } from './schemas/user.schema';
import { Interest } from '../enums/interests.enum';
import { CountersService } from '../counters/counters.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { NewsReported } from '../news/schemas/news-reported.schema';
import { Notification } from '../notifications/schemas/notification.schema';
import { SemanticNotification } from '../semantic-notifications/schemas/semantic-notification.schema';
import { SharedCollection } from '../shared-collections/schemas/shared-collection.schema';
import { SharedCollectionMember } from '../shared-collections/schemas/shared-collection-member.schema';
import { SharedCollectionAddedNews } from '../shared-collections/schemas/shared-collection-added-news.schema';

type CreateUserInput = {
  username: string;
  email: string;
  password: string;
  phoneNumber: string;
  birthdate: string;
  interests: Interest[];
};

@Injectable()
export class UsersService {
  constructor(
    @InjectModel(User.name)
    private readonly userModel: Model<User>,

    @InjectModel(NewsReported.name)
    private readonly newsReportedModel: Model<NewsReported>,

    @InjectModel(Notification.name)
    private readonly notificationModel: Model<Notification>,

    @InjectModel(SemanticNotification.name)
    private readonly semanticNotificationModel: Model<SemanticNotification>,

    @InjectModel(SharedCollection.name)
    private readonly sharedCollectionModel: Model<SharedCollection>,

    @InjectModel(SharedCollectionMember.name)
    private readonly sharedCollectionMemberModel: Model<SharedCollectionMember>,

    @InjectModel(SharedCollectionAddedNews.name)
    private readonly sharedCollectionAddedNewsModel: Model<SharedCollectionAddedNews>,

    private readonly counters: CountersService,
    private readonly jwt: JwtService,
  ) {}

  private handleDuplicateKeyError(error: any): never {
    if (error?.code === 11000 || error?.codeName === 'DuplicateKey') {
      if (error?.keyPattern?.username || error?.keyValue?.username) {
        throw new ConflictException('Username already exists');
      }

      if (error?.keyPattern?.email || error?.keyValue?.email) {
        throw new ConflictException('Email already exists');
      }

      if (error?.keyPattern?.phoneNumber || error?.keyValue?.phoneNumber) {
        throw new ConflictException('Phone already exists');
      }

      throw new ConflictException('User already exists');
    }

    throw new InternalServerErrorException('Failed to update profile');
  }

  async getProfileById(id: string) {
    if (!id) throw new BadRequestException('Missing user id in token');

    const user = await this.userModel.findById(id).lean();
    if (!user) throw new BadRequestException('User not found');

    return {
      id: user._id.toString(),
      userID: user.userID,
      username: user.username,
      email: user.email,
      phoneNumber: user.phoneNumber,
      birthdate: user.birthdate?.toISOString().slice(0, 10),
      interests: user.interests,
    };
  }

  async updateProfileById(id: string, dto: UpdateProfileDto) {
    if (!id) throw new BadRequestException('Missing user id in token');

    if (!Types.ObjectId.isValid(id)) {
      throw new BadRequestException('Invalid Mongo user id in token');
    }

    const current = await this.userModel.findById(id).lean();
    if (!current) throw new BadRequestException('User not found');

    const set: any = {};
    const userObjectId = new Types.ObjectId(id);

    if (dto.username) {
      const nextUsername = dto.username.trim();
      const usernameChanged = nextUsername !== current.username;

      if (usernameChanged) {
        const existingUsername = await this.userModel
          .findOne({
            username: nextUsername,
            _id: { $ne: userObjectId },
          })
          .lean();

        if (existingUsername) {
          throw new ConflictException('Username already exists');
        }
      }

      set.username = nextUsername;
    }

    if (dto.email) {
      const nextEmail = dto.email.trim().toLowerCase();
      const emailChanged = nextEmail !== current.email;

      if (emailChanged) {
        const existingEmail = await this.userModel
          .findOne({
            email: nextEmail,
            _id: { $ne: userObjectId },
          })
          .lean();

        if (existingEmail) {
          throw new ConflictException('Email already exists');
        }
      }

      set.email = nextEmail;
    }

    if (dto.birthdate) {
      const d = new Date(dto.birthdate);
      if (Number.isNaN(d.getTime())) {
        throw new BadRequestException('Invalid birthdate format');
      }
      set.birthdate = d;
    }

    // ---------------------------
    // Phone change requires OTP proof
    // ---------------------------
    if (dto.phoneNumber) {
      const nextPhone = dto.phoneNumber.trim();
      const oldPhone = (current.phoneNumber ?? '').trim();
      const phoneChanged = nextPhone !== oldPhone;

      if (phoneChanged) {
        // Ensure unique phone (race safety)
        const existing = await this.userModel
          .findOne({
            phoneNumber: nextPhone,
            _id: { $ne: userObjectId },
          })
          .lean();

        if (existing) {
          throw new ConflictException('Phone already exists');
        }

        const token = dto.phoneChangeVerificationToken?.trim();
        if (!token) {
          throw new BadRequestException(
            'Phone change verification token is required',
          );
        }

        let payload: any;
        try {
          payload = await this.jwt.verifyAsync(token);
        } catch {
          throw new BadRequestException(
            'Invalid or expired phone change verification token',
          );
        }

        if (payload?.type !== 'PHONE_CHANGE') {
          throw new BadRequestException(
            'Invalid phone change verification token type',
          );
        }

        if (payload?.sub !== id) {
          throw new BadRequestException(
            'Phone change token does not belong to this user',
          );
        }

        if ((payload?.phoneNumber ?? '').trim() !== nextPhone) {
          throw new BadRequestException(
            'Phone change token does not match requested phone number',
          );
        }
      }

      set.phoneNumber = nextPhone;
    }

    try {
      const updated = await this.userModel
        .findByIdAndUpdate(id, { $set: set }, { new: true })
        .lean();

      if (!updated) throw new BadRequestException('User not found');

      return {
        message: 'profile updated',
        user: {
          id: updated._id.toString(),
          userID: updated.userID,
          username: updated.username,
          email: updated.email,
          phoneNumber: updated.phoneNumber,
          birthdate: updated.birthdate?.toISOString().slice(0, 10),
          interests: updated.interests,
        },
      };
    } catch (error) {
      this.handleDuplicateKeyError(error);
    }
  }

  async deleteById(id: string) {
    if (!id) throw new BadRequestException('Missing user id in token');

    if (!Types.ObjectId.isValid(id)) {
      throw new BadRequestException('Invalid Mongo user id in token');
    }

    const userObjectId = new Types.ObjectId(id);

    const session = await this.userModel.db.startSession();
    session.startTransaction();

    try {
      await this.newsReportedModel
        .deleteMany({
          reportedByUserId: userObjectId,
        })
        .session(session);

      await this.notificationModel
        .deleteMany({
          userId: userObjectId,
        })
        .session(session);

      await this.semanticNotificationModel
        .deleteMany({
          userId: userObjectId,
        })
        .session(session);

      await this.sharedCollectionAddedNewsModel
        .deleteMany({
          addedByUserId: userObjectId,
        })
        .session(session);

      await this.sharedCollectionMemberModel
        .deleteMany({
          userId: userObjectId,
        })
        .session(session);

      const ownedCollections = await this.sharedCollectionModel
        .find({ ownerId: userObjectId })
        .select('_id')
        .lean();

      const collectionIds = ownedCollections.map((c: any) => c._id);

      if (collectionIds.length > 0) {
        await this.sharedCollectionAddedNewsModel
          .deleteMany({
            sharedCollectionId: { $in: collectionIds },
          })
          .session(session);

        await this.sharedCollectionMemberModel
          .deleteMany({
            sharedCollectionId: { $in: collectionIds },
          })
          .session(session);
      }

      await this.sharedCollectionModel
        .deleteMany({
          ownerId: userObjectId,
        })
        .session(session);

      await this.userModel.deleteOne({ _id: userObjectId }).session(session);

      await session.commitTransaction();
    } catch (e) {
      await session.abortTransaction();
      throw e;
    } finally {
      await session.endSession();
    }
  }

  async addInterests(id: string, interests: Interest[]) {
    if (!id) throw new BadRequestException('Missing user id in token');
    const updated = await this.userModel
      .findByIdAndUpdate(
        id,
        { $addToSet: { interests: { $each: interests } } },
        { new: true },
      )
      .lean();

    if (!updated) throw new BadRequestException('User not found');

    return { message: 'interest(s) added', interests: updated.interests };
  }

async removeInterest(id: string, interest: Interest) {
  if (!id) throw new BadRequestException('Missing user id in token');
  if (!Types.ObjectId.isValid(id)) {
    throw new BadRequestException('Invalid Mongo user id in token');
  }

  const userObjectId = new Types.ObjectId(id);
  const session = await this.userModel.db.startSession();
  session.startTransaction();

  try {
    const updated = await this.userModel
      .findByIdAndUpdate(
        id,
        { $pull: { interests: interest } },
        { new: true, session },
      )
      .lean();

    if (!updated) throw new BadRequestException('User not found');

    await this.semanticNotificationModel
      .deleteMany({ userId: userObjectId, Interest: interest })
      .session(session);

    await session.commitTransaction();
    return { message: 'interest removed', interests: updated.interests };
  } catch (e) {
    await session.abortTransaction();
    throw e;
  } finally {
    await session.endSession();
  }
}

  async existsEmail(email: string) {
    return !!(await this.userModel.exists({
      email: email.trim().toLowerCase(),
    }));
  }

  async existsUsername(username: string) {
    return !!(await this.userModel.exists({ username: username.trim() }));
  }

  async existsPhone(phoneNumber: string) {
    return !!(await this.userModel.exists({ phoneNumber: phoneNumber.trim() }));
  }

  async findByIdentifier(identifier: string) {
    const key = identifier.trim().toLowerCase();
    return this.userModel.findOne({
      $or: [{ email: key }, { username: identifier.trim() }],
    });
  }

  async create(input: CreateUserInput) {
    const birth = new Date(input.birthdate);
    if (Number.isNaN(birth.getTime())) {
      throw new BadRequestException('Invalid birthdate format');
    }

    const nextNum = await this.counters.next('usersIDs');
    const userID = `user${nextNum}`;

    return this.userModel.create({
      userID,
      username: input.username.trim(),
      email: input.email.trim().toLowerCase(),
      password: input.password,
      phoneNumber: input.phoneNumber.trim(),
      birthdate: birth,
      interests: input.interests,
      hiddenArticles: [],
    });
  }

  async findByPhone(phoneNumber: string) {
    return this.userModel.findOne({ phoneNumber: phoneNumber.trim() }).exec();
  }

  async findById(id: string) {
    return this.userModel.findById(id).exec();
  }

  async updatePasswordById(id: string, newPassword: string) {
    return this.userModel
      .updateOne({ _id: id }, { $set: { password: newPassword } })
      .exec();
  }

  async saveFcmToken(id: string, fcmToken: string) {
    await this.userModel.findByIdAndUpdate(id, { $set: { fcmToken } });
    return { message: 'FCM token saved' };
  }
}