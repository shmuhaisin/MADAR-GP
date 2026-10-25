import { BadRequestException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Test, TestingModule } from '@nestjs/testing';
import * as bcrypt from 'bcrypt';

import { AuthService } from './auth.service';
import { UsersService } from '../users/users.service';
import { TwilioService } from '../../integrations/twilio/twilio.service';
import { PendingSignupStore } from './otp/pending-signup.store';
import { PendingResetStore } from './otp/pending-reset.store';
import { PendingPhoneChangeStore } from './otp/pending-phone-change.store';

jest.mock('bcrypt', () => ({
  hash: jest.fn(),
  compare: jest.fn(),
}));

describe('AuthService - Signup Unit Tests', () => {
  let service: AuthService;

  const mockJwtService = {
    signAsync: jest.fn(),
    verifyAsync: jest.fn(),
  };

  const mockUsersService = {
    existsEmail: jest.fn(),
    existsUsername: jest.fn(),
    existsPhone: jest.fn(),
    create: jest.fn(),

    // These are needed because AuthService constructor uses full UsersService,
    // even though signup tests may not call all of them.
    findByIdentifier: jest.fn(),
    findByPhone: jest.fn(),
    findById: jest.fn(),
    updatePasswordById: jest.fn(),
  };

  const mockTwilioService = {
    sendOtpSms: jest.fn(),
    verifyOtp: jest.fn(),
  };

  const mockPendingSignupStore = {
    save: jest.fn(),
    consume: jest.fn(),
  };

  const mockPendingResetStore = {
    save: jest.fn(),
    consume: jest.fn(),
  };

  const mockPendingPhoneChangeStore = {
    savePending: jest.fn(),
    consumePending: jest.fn(),
    saveVerifiedToken: jest.fn(),
  };

  const signupDto = {
    username: 'shahad1',
    email: 'shahad@test.com',
    password: 'Test@123',
    phoneNumber: '+966500000000',
    birthdate: '2000-01-01',
    interests: ['Technology'],
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        {
          provide: JwtService,
          useValue: mockJwtService,
        },
        {
          provide: UsersService,
          useValue: mockUsersService,
        },
        {
          provide: TwilioService,
          useValue: mockTwilioService,
        },
        {
          provide: PendingSignupStore,
          useValue: mockPendingSignupStore,
        },
        {
          provide: PendingResetStore,
          useValue: mockPendingResetStore,
        },
        {
          provide: PendingPhoneChangeStore,
          useValue: mockPendingPhoneChangeStore,
        },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
  });

  describe('requestSignupOtp', () => {
    it('should send OTP when signup data is unique', async () => {
      mockUsersService.existsEmail.mockResolvedValue(false);
      mockUsersService.existsUsername.mockResolvedValue(false);
      mockUsersService.existsPhone.mockResolvedValue(false);
      mockTwilioService.sendOtpSms.mockResolvedValue(undefined);

      const result = await service.requestSignupOtp(signupDto as any);

      expect(mockUsersService.existsEmail).toHaveBeenCalledWith(
        'shahad@test.com',
      );

      expect(mockUsersService.existsUsername).toHaveBeenCalledWith('shahad1');

      expect(mockUsersService.existsPhone).toHaveBeenCalledWith(
        '+966500000000',
      );

      expect(mockPendingSignupStore.save).toHaveBeenCalledWith(
        '+966500000000',
        signupDto,
        300,
      );

      expect(mockTwilioService.sendOtpSms).toHaveBeenCalledWith(
        '+966500000000',
      );

      expect(result).toEqual({
        message: 'OTP sent',
      });
    });

    it('should reject signup OTP request when email already exists', async () => {
      mockUsersService.existsEmail.mockResolvedValue(true);
      mockUsersService.existsUsername.mockResolvedValue(false);
      mockUsersService.existsPhone.mockResolvedValue(false);

      await expect(
        service.requestSignupOtp(signupDto as any),
      ).rejects.toThrow(BadRequestException);

      await expect(
        service.requestSignupOtp(signupDto as any),
      ).rejects.toThrow('Email already exists');

      expect(mockPendingSignupStore.save).not.toHaveBeenCalled();
      expect(mockTwilioService.sendOtpSms).not.toHaveBeenCalled();
    });

    it('should reject signup OTP request when username already exists', async () => {
      mockUsersService.existsEmail.mockResolvedValue(false);
      mockUsersService.existsUsername.mockResolvedValue(true);
      mockUsersService.existsPhone.mockResolvedValue(false);

      await expect(
        service.requestSignupOtp(signupDto as any),
      ).rejects.toThrow(BadRequestException);

      await expect(
        service.requestSignupOtp(signupDto as any),
      ).rejects.toThrow('Username already exists');

      expect(mockPendingSignupStore.save).not.toHaveBeenCalled();
      expect(mockTwilioService.sendOtpSms).not.toHaveBeenCalled();
    });

    it('should reject signup OTP request when phone already exists', async () => {
      mockUsersService.existsEmail.mockResolvedValue(false);
      mockUsersService.existsUsername.mockResolvedValue(false);
      mockUsersService.existsPhone.mockResolvedValue(true);

      await expect(
        service.requestSignupOtp(signupDto as any),
      ).rejects.toThrow(BadRequestException);

      await expect(
        service.requestSignupOtp(signupDto as any),
      ).rejects.toThrow('Phone already exists');

      expect(mockPendingSignupStore.save).not.toHaveBeenCalled();
      expect(mockTwilioService.sendOtpSms).not.toHaveBeenCalled();
    });

    it('should check email before username and phone', async () => {
      mockUsersService.existsEmail.mockResolvedValue(true);

      await expect(
        service.requestSignupOtp(signupDto as any),
      ).rejects.toThrow('Email already exists');

      expect(mockUsersService.existsEmail).toHaveBeenCalled();
      expect(mockUsersService.existsUsername).not.toHaveBeenCalled();
      expect(mockUsersService.existsPhone).not.toHaveBeenCalled();
    });

    it('should check username before phone', async () => {
      mockUsersService.existsEmail.mockResolvedValue(false);
      mockUsersService.existsUsername.mockResolvedValue(true);

      await expect(
        service.requestSignupOtp(signupDto as any),
      ).rejects.toThrow('Username already exists');

      expect(mockUsersService.existsEmail).toHaveBeenCalled();
      expect(mockUsersService.existsUsername).toHaveBeenCalled();
      expect(mockUsersService.existsPhone).not.toHaveBeenCalled();
    });
  });

  describe('verifySignupOtp', () => {
    it('should reject signup verification when OTP is invalid', async () => {
      mockTwilioService.verifyOtp.mockResolvedValue({
        status: 'pending',
      });

      await expect(
        service.verifySignupOtp('+966500000000', '000000'),
      ).rejects.toThrow(BadRequestException);

      await expect(
        service.verifySignupOtp('+966500000000', '000000'),
      ).rejects.toThrow('Invalid or expired OTP');

      expect(mockPendingSignupStore.consume).not.toHaveBeenCalled();
      expect(mockUsersService.create).not.toHaveBeenCalled();
      expect(mockJwtService.signAsync).not.toHaveBeenCalled();
    });

    it('should reject signup verification when pending signup is missing or expired', async () => {
      mockTwilioService.verifyOtp.mockResolvedValue({
        status: 'approved',
      });

      mockPendingSignupStore.consume.mockReturnValue(null);

      await expect(
        service.verifySignupOtp('+966500000000', '123456'),
      ).rejects.toThrow(BadRequestException);

      await expect(
        service.verifySignupOtp('+966500000000', '123456'),
      ).rejects.toThrow(
        'No pending signup for this phone (expired or not requested)',
      );

      expect(mockPendingSignupStore.consume).toHaveBeenCalledWith(
        '+966500000000',
      );

      expect(mockUsersService.create).not.toHaveBeenCalled();
      expect(mockJwtService.signAsync).not.toHaveBeenCalled();
    });

    it('should create user and return token when OTP is approved', async () => {
      mockTwilioService.verifyOtp.mockResolvedValue({
        status: 'approved',
      });

      mockPendingSignupStore.consume.mockReturnValue(signupDto);

      (bcrypt.hash as jest.Mock).mockResolvedValue('hashed-password');

      const createdUser = {
        _id: {
          toString: () => 'user-object-id-123',
        },
        userID: 'user1',
        username: 'shahad1',
        email: 'shahad@test.com',
        phoneNumber: '+966500000000',
        birthdate: new Date('2000-01-01'),
        interests: ['Technology'],
      };

      mockUsersService.create.mockResolvedValue(createdUser);
      mockJwtService.signAsync.mockResolvedValue('fake-jwt-token');

      const result = await service.verifySignupOtp(
        '+966500000000',
        '123456',
      );

      expect(mockTwilioService.verifyOtp).toHaveBeenCalledWith(
        '+966500000000',
        '123456',
      );

      expect(mockPendingSignupStore.consume).toHaveBeenCalledWith(
        '+966500000000',
      );

      expect(bcrypt.hash).toHaveBeenCalledWith('Test@123', 10);

      expect(mockUsersService.create).toHaveBeenCalledWith({
        username: 'shahad1',
        email: 'shahad@test.com',
        password: 'hashed-password',
        phoneNumber: '+966500000000',
        birthdate: '2000-01-01',
        interests: ['Technology'],
      });

      expect(mockJwtService.signAsync).toHaveBeenCalledWith({
        sub: 'user-object-id-123',
        userId: 'user-object-id-123',
        userID: 'user1',
        username: 'shahad1',
        email: 'shahad@test.com',
      });

      expect(result).toEqual({
        message: 'signup complete',
        token: 'fake-jwt-token',
        user: {
          id: 'user-object-id-123',
          userID: 'user1',
          username: 'shahad1',
          email: 'shahad@test.com',
          phoneNumber: '+966500000000',
          birthdate: new Date('2000-01-01'),
          interests: ['Technology'],
        },
      });
    });

    it('should not create user if OTP provider returns rejected status', async () => {
      mockTwilioService.verifyOtp.mockResolvedValue({
        status: 'rejected',
      });

      await expect(
        service.verifySignupOtp('+966500000000', '111111'),
      ).rejects.toThrow('Invalid or expired OTP');

      expect(mockPendingSignupStore.consume).not.toHaveBeenCalled();
      expect(bcrypt.hash).not.toHaveBeenCalled();
      expect(mockUsersService.create).not.toHaveBeenCalled();
      expect(mockJwtService.signAsync).not.toHaveBeenCalled();
    });

    it('should not create user if OTP provider returns expired status', async () => {
      mockTwilioService.verifyOtp.mockResolvedValue({
        status: 'expired',
      });

      await expect(
        service.verifySignupOtp('+966500000000', '222222'),
      ).rejects.toThrow('Invalid or expired OTP');

      expect(mockPendingSignupStore.consume).not.toHaveBeenCalled();
      expect(bcrypt.hash).not.toHaveBeenCalled();
      expect(mockUsersService.create).not.toHaveBeenCalled();
      expect(mockJwtService.signAsync).not.toHaveBeenCalled();
    });
  });
});