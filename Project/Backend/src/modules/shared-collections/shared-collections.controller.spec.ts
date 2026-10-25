import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { SharedCollectionsController } from './shared-collections.controller';
import { SharedCollectionsCoreService } from './services/shared-collections-core.service';
import { SharedCollectionArticlesService } from './services/shared-collection-articles.service';
import { SharedCollectionReportsService } from './services/shared-collection-reports.service';
import { SharedCollectionJoinRequestsService } from './services/shared-collection-join-requests.service';
import { SharedCollectionMembersService } from './services/shared-collection-members.service';

// ─── Mock Services ────────────────────────────────────────────────────────────

const mockCoreService = {
  createCollection: jest.fn().mockResolvedValue({
    message: 'تم إنشاء المجموعة المشتركة',
    collection: {
      id: 'col-001',
      collectionName: 'AI News Collection',
      collectionDescription: 'A collection for the latest AI news',
      numOfViewers: 0,
      ownerUsername: 'rand_test',
    },
  }),
};

const mockArticlesService = {};
const mockReportsService = {};
const mockJoinRequestsService = {};
const mockMembersService = {};

// ─── Valid & Invalid Data ─────────────────────────────────────────────────────

const validBody = {
  collectionName: 'AI News Collection',
  collectionDescription: 'A collection for the latest AI news',
};

const NAME_OVER_40 = 'A'.repeat(41);
const DESC_OVER_90 = 'A'.repeat(91);

// ─── Test Suite ───────────────────────────────────────────────────────────────

describe('SharedCollectionsController - POST /shared-collections/createCollection', () => {
  let app: INestApplication;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [SharedCollectionsController],
      providers: [
        { provide: SharedCollectionsCoreService, useValue: mockCoreService },
        { provide: SharedCollectionArticlesService, useValue: mockArticlesService },
        { provide: SharedCollectionReportsService, useValue: mockReportsService },
        { provide: SharedCollectionJoinRequestsService, useValue: mockJoinRequestsService },
        { provide: SharedCollectionMembersService, useValue: mockMembersService },
      ],
    })
      .overrideGuard(require('../auth/jwt-auth.guard').JwtAuthGuard)
      .useValue({ canActivate: () => true })
      .compile();

    app = module.createNestApplication();

    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
      }),
    );

    await app.init();

    jest.clearAllMocks();
  });

  afterEach(async () => {
    await app.close();
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Scenario 1 - Valid data, service is called
  // ───────────────────────────────────────────────────────────────────────────

  it('should return 201 and call the service when all fields are valid', async () => {
    await request(app.getHttpServer())
      .post('/shared-collections/createCollection')
      .send(validBody)
      .expect(201);

    expect(mockCoreService.createCollection).toHaveBeenCalledTimes(1);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TC04 - Validation failures
  // ───────────────────────────────────────────────────────────────────────────

  describe('TC04 - Validation Failures', () => {

    // Scenario 2 - collectionName is empty
    it('should return 400 and not call the service when collectionName is empty', async () => {
      await request(app.getHttpServer())
        .post('/shared-collections/createCollection')
        .send({ ...validBody, collectionName: '' })
        .expect(400);

      expect(mockCoreService.createCollection).not.toHaveBeenCalled();
    });

    // Scenario 3 - collectionDescription is empty
    it('should return 400 and not call the service when collectionDescription is empty', async () => {
      await request(app.getHttpServer())
        .post('/shared-collections/createCollection')
        .send({ ...validBody, collectionDescription: '' })
        .expect(400);

      expect(mockCoreService.createCollection).not.toHaveBeenCalled();
    });

    // Scenario 4 - both fields are empty
    it('should return 400 and not call the service when both fields are empty', async () => {
      await request(app.getHttpServer())
        .post('/shared-collections/createCollection')
        .send({ collectionName: '', collectionDescription: '' })
        .expect(400);

      expect(mockCoreService.createCollection).not.toHaveBeenCalled();
    });

    // Scenario 5 - collectionName exceeds 40 characters
    it('should return 400 and not call the service when collectionName exceeds 40 characters', async () => {
      await request(app.getHttpServer())
        .post('/shared-collections/createCollection')
        .send({ ...validBody, collectionName: NAME_OVER_40 })
        .expect(400);

      expect(mockCoreService.createCollection).not.toHaveBeenCalled();
    });

    // Scenario 6 - collectionDescription exceeds 90 characters
    it('should return 400 and not call the service when collectionDescription exceeds 90 characters', async () => {
      await request(app.getHttpServer())
        .post('/shared-collections/createCollection')
        .send({ ...validBody, collectionDescription: DESC_OVER_90 })
        .expect(400);

      expect(mockCoreService.createCollection).not.toHaveBeenCalled();
    });

    // Scenario 7 - both fields exceed their limits
    it('should return 400 and not call the service when both fields exceed their limits', async () => {
      await request(app.getHttpServer())
        .post('/shared-collections/createCollection')
        .send({ collectionName: NAME_OVER_40, collectionDescription: DESC_OVER_90 })
        .expect(400);

      expect(mockCoreService.createCollection).not.toHaveBeenCalled();
    });
  });
});