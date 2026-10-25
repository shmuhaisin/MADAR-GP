import { Test, TestingModule } from '@nestjs/testing';
import { getModelToken } from '@nestjs/mongoose';
import { ConflictException } from '@nestjs/common';
import { Types } from 'mongoose';

import { SharedCollectionsCoreService } from './services/shared-collections-core.service';
import { SharedCollectionMembersService } from './services/shared-collection-members.service';
import { SharedCollection } from './schemas/shared-collection.schema';
import { SharedCollectionMember } from './schemas/shared-collection-member.schema';
import { SharedCollectionAddedNews } from './schemas/shared-collection-added-news.schema';
import { SharedCollectionJoinRequest } from './schemas/shared-collection-join-request.schema';
import { SharedCollectionView } from './schemas/shared-collection-view.schema';
import { SharedCollectionReportedNews } from './schemas/shared-collection-reported-news.schema';
import { User } from '../users/schemas/user.schema';
import { MemberRole } from '../enums/memberRole';
import { CreateSharedCollectionDto } from './dto/create-shared-collection.dto';

// ─── Mock Data ────────────────────────────────────────────────────────────────

const validOwnerId = new Types.ObjectId().toString();

const validDto: CreateSharedCollectionDto = {
  collectionName: 'AI News Collection',
  collectionDescription: 'A collection for the latest AI news',
};

const createdCollectionMock = {
  _id: new Types.ObjectId(),
  ownerId: new Types.ObjectId(validOwnerId),
  collectionName: validDto.collectionName,
  collectionDescription: validDto.collectionDescription,
  numOfViewers: 0,
};

const ownerUserMock = {
  _id: new Types.ObjectId(validOwnerId),
  username: 'rand_test',
};

// ─── Mock Models ──────────────────────────────────────────────────────────────

const mockCollectionModel = {
  create: jest.fn(),
};

const mockMemberModel = {
  create: jest.fn(),
};

const mockUserModel = {
  findById: jest.fn(),
};

// These mocks exist only to satisfy the module's dependency injection
const mockAddedNewsModel = { create: jest.fn() };
const mockJoinRequestModel = { create: jest.fn() };
const mockCollectionViewModel = { create: jest.fn() };
const mockReportedNewsModel = { create: jest.fn() };
const mockMembersService = {};

// ─── Test Suite ───────────────────────────────────────────────────────────────

describe('SharedCollectionsCoreService - createCollection', () => {
  let service: SharedCollectionsCoreService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SharedCollectionsCoreService,
        {
          provide: getModelToken(SharedCollection.name),
          useValue: mockCollectionModel,
        },
        {
          provide: getModelToken(SharedCollectionMember.name),
          useValue: mockMemberModel,
        },
        {
          provide: getModelToken(User.name),
          useValue: mockUserModel,
        },
        {
          provide: getModelToken(SharedCollectionAddedNews.name),
          useValue: mockAddedNewsModel,
        },
        {
          provide: getModelToken(SharedCollectionJoinRequest.name),
          useValue: mockJoinRequestModel,
        },
        {
          provide: getModelToken(SharedCollectionView.name),
          useValue: mockCollectionViewModel,
        },
        {
          provide: getModelToken(SharedCollectionReportedNews.name),
          useValue: mockReportedNewsModel,
        },
        {
          provide: SharedCollectionMembersService,
          useValue: mockMembersService,
        },
      ],
    }).compile();

    service = module.get<SharedCollectionsCoreService>(
      SharedCollectionsCoreService,
    );

    jest.clearAllMocks();
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TC03 - Successful Creation
  // ───────────────────────────────────────────────────────────────────────────

  describe('TC03 - Successful Creation', () => {

    beforeEach(() => {
      mockCollectionModel.create.mockResolvedValue(createdCollectionMock);
      mockMemberModel.create.mockResolvedValue({});
      mockUserModel.findById.mockReturnValue({
        select: jest.fn().mockReturnValue({
          lean: jest.fn().mockResolvedValue(ownerUserMock),
        }),
      });
    });

    // Scenario 1 - Full successful creation
    it('should call collectionModel.create with the correct data', async () => {
      await service.createCollection(validOwnerId, validDto);

      expect(mockCollectionModel.create).toHaveBeenCalledTimes(1);
      expect(mockCollectionModel.create).toHaveBeenCalledWith(
        expect.objectContaining({
          collectionName: validDto.collectionName,
          collectionDescription: validDto.collectionDescription,
          numOfViewers: 0,
        }),
      );
    });

    it('should call memberModel.create with role OWNER', async () => {
      await service.createCollection(validOwnerId, validDto);

      expect(mockMemberModel.create).toHaveBeenCalledTimes(1);
      expect(mockMemberModel.create).toHaveBeenCalledWith(
        expect.objectContaining({
          role: MemberRole.OWNER,
        }),
      );
    });

    it('should return the correct response shape with message and collection', async () => {
      const result = await service.createCollection(validOwnerId, validDto);

      expect(result).toHaveProperty('message');
      expect(result).toHaveProperty('collection');
      expect(result.collection).toHaveProperty('id');
      expect(result.collection).toHaveProperty('collectionName', validDto.collectionName);
      expect(result.collection).toHaveProperty('collectionDescription', validDto.collectionDescription);
      expect(result.collection).toHaveProperty('numOfViewers', 0);
    });

    // Scenario 2 - ownerUsername returned correctly
    it('should return the correct ownerUsername when the user exists', async () => {
      const result = await service.createCollection(validOwnerId, validDto);

      expect(result.collection.ownerUsername).toBe(ownerUserMock.username);
    });

    // Scenario 3 - ownerUsername returns null
    it('should return ownerUsername as null when the user is not found', async () => {
      mockUserModel.findById.mockReturnValue({
        select: jest.fn().mockReturnValue({
          lean: jest.fn().mockResolvedValue(null),
        }),
      });

      const result = await service.createCollection(validOwnerId, validDto);

      expect(result.collection.ownerUsername).toBeNull();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TC05 - Storage Failure
  // ───────────────────────────────────────────────────────────────────────────

  describe('TC05 - Storage Failure', () => {

    // Scenario 4 - invalid ownerId
    it('should throw an error when ownerId is not a valid ObjectId', async () => {
      await expect(
        service.createCollection('invalid-id', validDto),
      ).rejects.toThrow();
    });

    // Scenario 5 - collectionModel.create fails
    it('should propagate the error when collectionModel.create fails', async () => {
      const dbError = new Error('database write failed');
      mockCollectionModel.create.mockRejectedValue(dbError);

      await expect(
        service.createCollection(validOwnerId, validDto),
      ).rejects.toThrow('database write failed');

      // memberModel should never be called
      expect(mockMemberModel.create).not.toHaveBeenCalled();
    });

    // Scenario 6 - memberModel.create fails with code 11000
    it('should throw ConflictException when memberModel.create fails with code 11000', async () => {
      mockCollectionModel.create.mockResolvedValue(createdCollectionMock);

      const duplicateError = { code: 11000, message: 'duplicate key error' };
      mockMemberModel.create.mockRejectedValue(duplicateError);

      await expect(
        service.createCollection(validOwnerId, validDto),
      ).rejects.toThrow(ConflictException);
    });

    // Scenario 7 - memberModel.create fails with a generic error
    it('should propagate the error as-is when memberModel.create fails with a generic error', async () => {
      mockCollectionModel.create.mockResolvedValue(createdCollectionMock);

      const genericError = new Error('unexpected error');
      mockMemberModel.create.mockRejectedValue(genericError);

      await expect(
        service.createCollection(validOwnerId, validDto),
      ).rejects.toThrow('unexpected error');
    });
  });
});