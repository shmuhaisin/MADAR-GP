import {
  BadRequestException,
  ConflictException,
  InternalServerErrorException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { getModelToken } from '@nestjs/mongoose';
import { Test, TestingModule } from '@nestjs/testing';
import { Types } from 'mongoose';

import { UsersService } from './users.service';
import { User } from './schemas/user.schema';
import { CountersService } from '../counters/counters.service';

import { NewsReported } from '../news/schemas/news-reported.schema';
import { Notification } from '../notifications/schemas/notification.schema';
import { SemanticNotification } from '../semantic-notifications/schemas/semantic-notification.schema';
import { SharedCollection } from '../shared-collections/schemas/shared-collection.schema';
import { SharedCollectionMember } from '../shared-collections/schemas/shared-collection-member.schema';
import { SharedCollectionAddedNews } from '../shared-collections/schemas/shared-collection-added-news.schema';

describe('UsersService - Unit Tests', () => {
  let service: UsersService;

  const validUserId = '507f1f77bcf86cd799439011';

  const mockUserModel = {
    create: jest.fn(),
    exists: jest.fn(),
    findOne: jest.fn(),
    findById: jest.fn(),
    findByIdAndUpdate: jest.fn(),
    updateOne: jest.fn(),
    deleteOne: jest.fn(),
    db: {
      startSession: jest.fn(),
    },
  };

  const mockCountersService = {
    next: jest.fn(),
  };

  const mockJwtService = {
    verifyAsync: jest.fn(),
  };

  const mockNewsReportedModel = {
    deleteMany: jest.fn(),
  };

  const mockNotificationModel = {
    deleteMany: jest.fn(),
  };

  const mockSemanticNotificationModel = {
    deleteMany: jest.fn(),
  };

  const mockSharedCollectionModel = {
    deleteMany: jest.fn(),
    find: jest.fn(),
  };

  const mockSharedCollectionMemberModel = {
    deleteMany: jest.fn(),
  };

  const mockSharedCollectionAddedNewsModel = {
    deleteMany: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        {
          provide: getModelToken(User.name),
          useValue: mockUserModel,
        },
        {
          provide: getModelToken(NewsReported.name),
          useValue: mockNewsReportedModel,
        },
        {
          provide: getModelToken(Notification.name),
          useValue: mockNotificationModel,
        },
        {
          provide: getModelToken(SemanticNotification.name),
          useValue: mockSemanticNotificationModel,
        },
        {
          provide: getModelToken(SharedCollection.name),
          useValue: mockSharedCollectionModel,
        },
        {
          provide: getModelToken(SharedCollectionMember.name),
          useValue: mockSharedCollectionMemberModel,
        },
        {
          provide: getModelToken(SharedCollectionAddedNews.name),
          useValue: mockSharedCollectionAddedNewsModel,
        },
        {
          provide: CountersService,
          useValue: mockCountersService,
        },
        {
          provide: JwtService,
          useValue: mockJwtService,
        },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
  });

  const validCreateInput = (overrides = {}) =>
    ({
      username: 'shahad1',
      email: 'shahad@test.com',
      password: 'hashed-password',
      phoneNumber: '+966500000000',
      birthdate: '2000-01-01',
      interests: ['Technology'],
      ...overrides,
    }) as any;

  const currentUser = {
    _id: new Types.ObjectId(validUserId),
    userID: 'user1',
    username: 'olduser',
    email: 'old@email.com',
    phoneNumber: '+966500000000',
    birthdate: new Date('2000-01-01'),
    interests: ['Technology'],
  };

  const updatedUser = {
    _id: new Types.ObjectId(validUserId),
    userID: 'user1',
    username: 'newuser',
    email: 'new@email.com',
    phoneNumber: '+966500000000',
    birthdate: new Date('2000-01-01'),
    interests: ['Technology'],
  };

  function mockLeanResolved(value: any) {
    return {
      lean: jest.fn().mockResolvedValue(value),
    };
  }

  function mockExecResolved(value: any) {
    return {
      exec: jest.fn().mockResolvedValue(value),
    };
  }

  describe('create', () => {
    it('should create a user with valid signup data', async () => {
      mockCountersService.next.mockResolvedValue(1);

      const createdUser = {
        userID: 'user1',
        username: 'shahad1',
        email: 'shahad@test.com',
        password: 'hashed-password',
        phoneNumber: '+966500000000',
        birthdate: new Date('2000-01-01'),
        interests: ['Technology'],
        hiddenArticles: [],
      };

      mockUserModel.create.mockResolvedValue(createdUser);

      const result = await service.create(validCreateInput());

      expect(mockCountersService.next).toHaveBeenCalledWith('usersIDs');

      expect(mockUserModel.create).toHaveBeenCalledWith(
        expect.objectContaining({
          userID: 'user1',
          username: 'shahad1',
          email: 'shahad@test.com',
          password: 'hashed-password',
          phoneNumber: '+966500000000',
          interests: ['Technology'],
          hiddenArticles: [],
        }),
      );

      expect(result).toEqual(createdUser);
    });

    it('should trim username, email, and phone before create', async () => {
      mockCountersService.next.mockResolvedValue(2);

      mockUserModel.create.mockResolvedValue({
        userID: 'user2',
      });

      await service.create(
        validCreateInput({
          username: '  shahad1  ',
          email: '  SHAHAD@Test.COM  ',
          phoneNumber: '  +966500000000  ',
        }),
      );

      expect(mockUserModel.create).toHaveBeenCalledWith(
        expect.objectContaining({
          username: 'shahad1',
          email: 'shahad@test.com',
          phoneNumber: '+966500000000',
        }),
      );
    });

    it('should reject invalid birthdate format', async () => {
      await expect(
        service.create(
          validCreateInput({
            birthdate: 'wrong-date',
          }),
        ),
      ).rejects.toThrow(BadRequestException);

      expect(mockUserModel.create).not.toHaveBeenCalled();
    });
  });

  describe('exists helpers used by signup', () => {
    it('should return true when email exists', async () => {
      mockUserModel.exists.mockResolvedValue({ _id: validUserId });

      const result = await service.existsEmail(' Test@Email.COM ');

      expect(mockUserModel.exists).toHaveBeenCalledWith({
        email: 'test@email.com',
      });

      expect(result).toBe(true);
    });

    it('should return false when email does not exist', async () => {
      mockUserModel.exists.mockResolvedValue(null);

      const result = await service.existsEmail('new@email.com');

      expect(result).toBe(false);
    });

    it('should return true when username exists', async () => {
      mockUserModel.exists.mockResolvedValue({ _id: validUserId });

      const result = await service.existsUsername(' roaa444 ');

      expect(mockUserModel.exists).toHaveBeenCalledWith({
        username: 'roaa444',
      });

      expect(result).toBe(true);
    });

    it('should return false when username does not exist', async () => {
      mockUserModel.exists.mockResolvedValue(null);

      const result = await service.existsUsername('newuser');

      expect(result).toBe(false);
    });

    it('should return true when phone exists', async () => {
      mockUserModel.exists.mockResolvedValue({ _id: validUserId });

      const result = await service.existsPhone(' +966500000000 ');

      expect(mockUserModel.exists).toHaveBeenCalledWith({
        phoneNumber: '+966500000000',
      });

      expect(result).toBe(true);
    });

    it('should return false when phone does not exist', async () => {
      mockUserModel.exists.mockResolvedValue(null);

      const result = await service.existsPhone('+966599999999');

      expect(result).toBe(false);
    });
  });

  describe('findByIdentifier', () => {
    it('should search by normalized email or trimmed username', async () => {
      const foundUser = {
        username: 'shahad1',
        email: 'shahad@test.com',
      };

      mockUserModel.findOne.mockReturnValue(foundUser);

      const result = await service.findByIdentifier(' SHAHAD@Test.COM ');

      expect(mockUserModel.findOne).toHaveBeenCalledWith({
        $or: [
          {
            email: 'shahad@test.com',
          },
          {
            username: 'SHAHAD@Test.COM',
          },
        ],
      });

      expect(result).toEqual(foundUser);
    });
  });

  describe('findByPhone / findById / updatePasswordById / saveFcmToken', () => {
    it('should find user by phone', async () => {
      const foundUser = {
        phoneNumber: '+966500000000',
      };

      mockUserModel.findOne.mockReturnValue(mockExecResolved(foundUser));

      const result = await service.findByPhone(' +966500000000 ');

      expect(mockUserModel.findOne).toHaveBeenCalledWith({
        phoneNumber: '+966500000000',
      });

      expect(result).toEqual(foundUser);
    });

    it('should find user by id', async () => {
      mockUserModel.findById.mockReturnValue(mockExecResolved(currentUser));

      const result = await service.findById(validUserId);

      expect(mockUserModel.findById).toHaveBeenCalledWith(validUserId);
      expect(result).toEqual(currentUser);
    });

    it('should update password by id', async () => {
      mockUserModel.updateOne.mockReturnValue(
        mockExecResolved({
          modifiedCount: 1,
        }),
      );

      const result = await service.updatePasswordById(
        validUserId,
        'new-hashed-password',
      );

      expect(mockUserModel.updateOne).toHaveBeenCalledWith(
        {
          _id: validUserId,
        },
        {
          $set: {
            password: 'new-hashed-password',
          },
        },
      );

      expect(result).toEqual({
        modifiedCount: 1,
      });
    });

    it('should save FCM token', async () => {
      mockUserModel.findByIdAndUpdate.mockResolvedValue(currentUser);

      const result = await service.saveFcmToken(validUserId, 'fcm-token');

      expect(mockUserModel.findByIdAndUpdate).toHaveBeenCalledWith(
        validUserId,
        {
          $set: {
            fcmToken: 'fcm-token',
          },
        },
      );

      expect(result).toEqual({
        message: 'FCM token saved',
      });
    });
  });

  describe('getProfileById', () => {
    it('should return profile by id', async () => {
      mockUserModel.findById.mockReturnValue(mockLeanResolved(currentUser));

      const result = await service.getProfileById(validUserId);

      expect(mockUserModel.findById).toHaveBeenCalledWith(validUserId);

      expect(result).toEqual({
        id: currentUser._id.toString(),
        userID: 'user1',
        username: 'olduser',
        email: 'old@email.com',
        phoneNumber: '+966500000000',
        birthdate: '2000-01-01',
        interests: ['Technology'],
      });
    });

    it('should reject missing user id', async () => {
      await expect(service.getProfileById('')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should reject when user not found', async () => {
      mockUserModel.findById.mockReturnValue(mockLeanResolved(null));

      await expect(service.getProfileById(validUserId)).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('updateProfileById uniqueness validation', () => {
    it('should update profile successfully', async () => {
      mockUserModel.findById.mockReturnValue(mockLeanResolved(currentUser));

      mockUserModel.findOne.mockReturnValue(mockLeanResolved(null));

      mockUserModel.findByIdAndUpdate.mockReturnValue(
        mockLeanResolved(updatedUser),
      );

      const result = await service.updateProfileById(validUserId, {
        username: 'newuser',
        email: 'new@email.com',
      } as any);

      expect(mockUserModel.findByIdAndUpdate).toHaveBeenCalledWith(
        validUserId,
        {
          $set: {
            username: 'newuser',
            email: 'new@email.com',
          },
        },
        {
          new: true,
        },
      );

      expect(result).toEqual({
        message: 'profile updated',
        user: {
          id: updatedUser._id.toString(),
          userID: 'user1',
          username: 'newuser',
          email: 'new@email.com',
          phoneNumber: '+966500000000',
          birthdate: '2000-01-01',
          interests: ['Technology'],
        },
      });
    });

    it('should reject duplicate username before update', async () => {
      mockUserModel.findById.mockReturnValue(mockLeanResolved(currentUser));

      mockUserModel.findOne.mockReturnValue(
        mockLeanResolved({
          username: 'roaa444',
        }),
      );

      await expect(
        service.updateProfileById(validUserId, {
          username: 'roaa444',
        } as any),
      ).rejects.toThrow(ConflictException);

      await expect(
        service.updateProfileById(validUserId, {
          username: 'roaa444',
        } as any),
      ).rejects.toThrow('Username already exists');
    });

    it('should reject duplicate email before update', async () => {
      mockUserModel.findById.mockReturnValue(mockLeanResolved(currentUser));

      mockUserModel.findOne.mockReturnValue(
        mockLeanResolved({
          email: 'used@email.com',
        }),
      );

      await expect(
        service.updateProfileById(validUserId, {
          email: 'used@email.com',
        } as any),
      ).rejects.toThrow(ConflictException);

      await expect(
        service.updateProfileById(validUserId, {
          email: 'used@email.com',
        } as any),
      ).rejects.toThrow('Email already exists');
    });

    it('should reject duplicate phone before update', async () => {
      mockUserModel.findById.mockReturnValue(mockLeanResolved(currentUser));

      mockUserModel.findOne.mockReturnValue(
        mockLeanResolved({
          phoneNumber: '+966599999999',
        }),
      );

      await expect(
        service.updateProfileById(validUserId, {
          phoneNumber: '+966599999999',
          phoneChangeVerificationToken: 'token',
        } as any),
      ).rejects.toThrow(ConflictException);

      await expect(
        service.updateProfileById(validUserId, {
          phoneNumber: '+966599999999',
          phoneChangeVerificationToken: 'token',
        } as any),
      ).rejects.toThrow('Phone already exists');
    });

    it('should reject phone update without verification token', async () => {
      mockUserModel.findById.mockReturnValue(mockLeanResolved(currentUser));

      mockUserModel.findOne.mockReturnValue(mockLeanResolved(null));

      await expect(
        service.updateProfileById(validUserId, {
          phoneNumber: '+966599999999',
        } as any),
      ).rejects.toThrow(BadRequestException);

      await expect(
        service.updateProfileById(validUserId, {
          phoneNumber: '+966599999999',
        } as any),
      ).rejects.toThrow('Phone change verification token is required');
    });

    it('should reject invalid phone verification token', async () => {
      mockUserModel.findById.mockReturnValue(mockLeanResolved(currentUser));

      mockUserModel.findOne.mockReturnValue(mockLeanResolved(null));

      mockJwtService.verifyAsync.mockRejectedValue(new Error('invalid token'));

      await expect(
        service.updateProfileById(validUserId, {
          phoneNumber: '+966599999999',
          phoneChangeVerificationToken: 'bad-token',
        } as any),
      ).rejects.toThrow(BadRequestException);

      await expect(
        service.updateProfileById(validUserId, {
          phoneNumber: '+966599999999',
          phoneChangeVerificationToken: 'bad-token',
        } as any),
      ).rejects.toThrow('Invalid or expired phone change verification token');
    });

    it('should reject phone token with wrong type', async () => {
      mockUserModel.findById.mockReturnValue(mockLeanResolved(currentUser));

      mockUserModel.findOne.mockReturnValue(mockLeanResolved(null));

      mockJwtService.verifyAsync.mockResolvedValue({
        type: 'RESET_PASSWORD',
        sub: validUserId,
        phoneNumber: '+966599999999',
      });

      await expect(
        service.updateProfileById(validUserId, {
          phoneNumber: '+966599999999',
          phoneChangeVerificationToken: 'token',
        } as any),
      ).rejects.toThrow('Invalid phone change verification token type');
    });

    it('should reject phone token that belongs to another user', async () => {
      mockUserModel.findById.mockReturnValue(mockLeanResolved(currentUser));

      mockUserModel.findOne.mockReturnValue(mockLeanResolved(null));

      mockJwtService.verifyAsync.mockResolvedValue({
        type: 'PHONE_CHANGE',
        sub: 'another-user-id',
        phoneNumber: '+966599999999',
      });

      await expect(
        service.updateProfileById(validUserId, {
          phoneNumber: '+966599999999',
          phoneChangeVerificationToken: 'token',
        } as any),
      ).rejects.toThrow('Phone change token does not belong to this user');
    });

    it('should reject phone token that does not match requested phone', async () => {
      mockUserModel.findById.mockReturnValue(mockLeanResolved(currentUser));

      mockUserModel.findOne.mockReturnValue(mockLeanResolved(null));

      mockJwtService.verifyAsync.mockResolvedValue({
        type: 'PHONE_CHANGE',
        sub: validUserId,
        phoneNumber: '+966511111111',
      });

      await expect(
        service.updateProfileById(validUserId, {
          phoneNumber: '+966599999999',
          phoneChangeVerificationToken: 'token',
        } as any),
      ).rejects.toThrow('Phone change token does not match requested phone');
    });

    it('should update phone when token is valid', async () => {
      const phoneUpdatedUser = {
        ...updatedUser,
        phoneNumber: '+966599999999',
      };

      mockUserModel.findById.mockReturnValue(mockLeanResolved(currentUser));

      mockUserModel.findOne.mockReturnValue(mockLeanResolved(null));

      mockJwtService.verifyAsync.mockResolvedValue({
        type: 'PHONE_CHANGE',
        sub: validUserId,
        phoneNumber: '+966599999999',
      });

      mockUserModel.findByIdAndUpdate.mockReturnValue(
        mockLeanResolved(phoneUpdatedUser),
      );

      const result = await service.updateProfileById(validUserId, {
        phoneNumber: '+966599999999',
        phoneChangeVerificationToken: 'token',
      } as any);

      expect(result.user.phoneNumber).toBe('+966599999999');
    });

    it('should handle Mongo duplicate username error during update', async () => {
      mockUserModel.findById.mockReturnValue(mockLeanResolved(currentUser));

      mockUserModel.findOne.mockReturnValue(mockLeanResolved(null));

      mockUserModel.findByIdAndUpdate.mockReturnValue({
        lean: jest.fn().mockRejectedValue({
          code: 11000,
          codeName: 'DuplicateKey',
          keyPattern: {
            username: 1,
          },
          keyValue: {
            username: 'roaa444',
          },
        }),
      });

      await expect(
        service.updateProfileById(validUserId, {
          username: 'roaa444',
        } as any),
      ).rejects.toThrow(ConflictException);

      await expect(
        service.updateProfileById(validUserId, {
          username: 'roaa444',
        } as any),
      ).rejects.toThrow('Username already exists');
    });

    it('should handle Mongo duplicate email error during update', async () => {
      mockUserModel.findById.mockReturnValue(mockLeanResolved(currentUser));

      mockUserModel.findOne.mockReturnValue(mockLeanResolved(null));

      mockUserModel.findByIdAndUpdate.mockReturnValue({
        lean: jest.fn().mockRejectedValue({
          code: 11000,
          codeName: 'DuplicateKey',
          keyPattern: {
            email: 1,
          },
          keyValue: {
            email: 'used@email.com',
          },
        }),
      });

      await expect(
        service.updateProfileById(validUserId, {
          email: 'used@email.com',
        } as any),
      ).rejects.toThrow(ConflictException);

      await expect(
        service.updateProfileById(validUserId, {
          email: 'used@email.com',
        } as any),
      ).rejects.toThrow('Email already exists');
    });

    it('should handle Mongo duplicate phone error during update', async () => {
      mockUserModel.findById.mockReturnValue(mockLeanResolved(currentUser));

      mockUserModel.findOne.mockReturnValue(mockLeanResolved(null));

      mockJwtService.verifyAsync.mockResolvedValue({
        type: 'PHONE_CHANGE',
        sub: validUserId,
        phoneNumber: '+966599999999',
      });

      mockUserModel.findByIdAndUpdate.mockReturnValue({
        lean: jest.fn().mockRejectedValue({
          code: 11000,
          codeName: 'DuplicateKey',
          keyPattern: {
            phoneNumber: 1,
          },
          keyValue: {
            phoneNumber: '+966599999999',
          },
        }),
      });

      await expect(
        service.updateProfileById(validUserId, {
          phoneNumber: '+966599999999',
          phoneChangeVerificationToken: 'token',
        } as any),
      ).rejects.toThrow(ConflictException);

      await expect(
        service.updateProfileById(validUserId, {
          phoneNumber: '+966599999999',
          phoneChangeVerificationToken: 'token',
        } as any),
      ).rejects.toThrow('Phone already exists');
    });

    it('should throw internal server error for unknown update error', async () => {
      mockUserModel.findById.mockReturnValue(mockLeanResolved(currentUser));

      mockUserModel.findOne.mockReturnValue(mockLeanResolved(null));

      mockUserModel.findByIdAndUpdate.mockReturnValue({
        lean: jest.fn().mockRejectedValue(new Error('database down')),
      });

      await expect(
        service.updateProfileById(validUserId, {
          username: 'newuser',
        } as any),
      ).rejects.toThrow(InternalServerErrorException);

      await expect(
        service.updateProfileById(validUserId, {
          username: 'newuser',
        } as any),
      ).rejects.toThrow('Failed to update profile');
    });
  });

  describe('interests', () => {
    it('should add interests', async () => {
      mockUserModel.findByIdAndUpdate.mockReturnValue(
        mockLeanResolved({
          interests: ['Technology', 'Sports'],
        }),
      );

      const result = await service.addInterests(validUserId, ['Sports'] as any);

      expect(result).toEqual({
        message: 'interest(s) added',
        interests: ['Technology', 'Sports'],
      });
    });

    it('should remove interest', async () => {
      mockUserModel.findByIdAndUpdate.mockReturnValue(
        mockLeanResolved({
          interests: ['Technology'],
        }),
      );

      const result = await service.removeInterest(
        validUserId,
        'Sports' as any,
      );

      expect(result).toEqual({
        message: 'interest removed',
        interests: ['Technology'],
      });
    });
  });
});