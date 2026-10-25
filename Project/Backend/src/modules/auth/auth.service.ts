import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';

import { LoginDto } from './dto/login.dto';
import { UsersService } from '../users/users.service';

import { TwilioService } from '../../integrations/twilio/twilio.service';
import { RequestSignupOtpDto } from './otp/dto/request-signup-otp.dto';
import { PendingSignupStore } from './otp/pending-signup.store';
import { PendingResetStore } from './otp/pending-reset.store';
import { PendingPhoneChangeStore } from './otp/pending-phone-change.store';

@Injectable()
export class AuthService {
  constructor(
    private readonly jwt: JwtService,
    private readonly users: UsersService,
    private readonly twilio: TwilioService,
    private readonly pendingSignup: PendingSignupStore,
    private readonly pendingReset: PendingResetStore,
    private readonly pendingPhoneChange: PendingPhoneChangeStore,
  ) {}

  // ---------------- SIGNIN ----------------
  async signin(dto: LoginDto) {
    const { identifier, password } = dto;

    

    const user = await this.users.findByIdentifier(identifier);

    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const passwordMatches = await bcrypt.compare(password, user.password);

    if (!passwordMatches) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const token = await this.jwt.signAsync({
      sub: user._id.toString(),
      userId: user._id.toString(),
      userID: user.userID,
      username: user.username,
      email: user.email,
    });

    return {
      message: 'signin successful',
      token,
      user: {
        id: user._id.toString(),
        userID: user.userID,
        username: user.username,
        email: user.email,
        phoneNumber: user.phoneNumber,
        birthdate: user.birthdate,
        interests: user.interests,
      },
    };
  }

  // ---------------- SIGNUP OTP ----------------
  async requestSignupOtp(dto: RequestSignupOtpDto) {
    if (await this.users.existsEmail(dto.email)) {
      throw new BadRequestException('Email already exists');
    }

    if (await this.users.existsUsername(dto.username)) {
      throw new BadRequestException('Username already exists');
    }

    if (await this.users.existsPhone(dto.phoneNumber)) {
      throw new BadRequestException('Phone already exists');
    }

    this.pendingSignup.save(dto.phoneNumber, dto, 300);

    await this.twilio.sendOtpSms(dto.phoneNumber);

    return { message: 'OTP sent' };
  }

  async verifySignupOtp(phone: string, code: string) {
    const check = await this.twilio.verifyOtp(phone, code);

    if (check.status !== 'approved') {
      throw new BadRequestException('Invalid or expired OTP');
    }

    const payload = this.pendingSignup.consume(phone);

    if (!payload) {
      throw new BadRequestException(
        'No pending signup for this phone (expired or not requested)',
      );
    }

    const hashedPassword = await bcrypt.hash(payload.password, 10);

    const created = await this.users.create({
      username: payload.username,
      email: payload.email,
      password: hashedPassword,
      phoneNumber: payload.phoneNumber,
      birthdate: payload.birthdate,
      interests: payload.interests,
    });

    const token = await this.jwt.signAsync({
      sub: created._id.toString(),
      userId: created._id.toString(),
      userID: created.userID,
      username: created.username,
      email: created.email,
    });

    return {
      message: 'signup complete',
      token,
      user: {
        id: created._id.toString(),
        userID: created.userID,
        username: created.username,
        email: created.email,
        phoneNumber: created.phoneNumber,
        birthdate: created.birthdate,
        interests: created.interests,
      },
    };
  }

  // ---------------- RESET PASSWORD OTP ----------------
  async requestResetOtp(phoneNumber: string) {
    const user = await this.users.findByPhone(phoneNumber);

    if (!user) {
      throw new BadRequestException('No user with this phone');
    }

    this.pendingReset.save(phoneNumber, 300);

    await this.twilio.sendOtpSms(phoneNumber);

    return { message: 'OTP sent' };
  }

  async confirmReset(phone: string, code: string) {
    const check = await this.twilio.verifyOtp(phone, code);

    if (check.status !== 'approved') {
      throw new BadRequestException('Invalid or expired OTP');
    }

    const ok = this.pendingReset.consume(phone);

    if (!ok) {
      throw new BadRequestException(
        'No pending reset for this phone (expired or not requested)',
      );
    }

    const resetToken = await this.jwt.signAsync(
      {
        sub: phone,
        type: 'RESET_PASSWORD',
      },
      {
        expiresIn: '10m',
      },
    );

    return {
      message: 'OTP verified',
      resetToken,
    };
  }

  async resetPassword(resetToken: string, newPassword: string) {
    if (!resetToken?.trim()) {
      throw new BadRequestException('resetToken is required');
    }

    if (!newPassword?.trim()) {
      throw new BadRequestException('newPassword is required');
    }

    let payload: any;

    try {
      payload = await this.jwt.verifyAsync(resetToken);
    } catch {
      throw new BadRequestException('Invalid or expired reset token');
    }

    if (payload?.type !== 'RESET_PASSWORD') {
      throw new BadRequestException('Invalid reset token type');
    }

    const phone = payload?.sub;

    if (!phone) {
      throw new BadRequestException('Reset token missing phone');
    }

    const user = await this.users.findByPhone(phone);

    if (!user) {
      throw new BadRequestException('No user with this phone');
    }

    const hashedPassword = await bcrypt.hash(newPassword.trim(), 10);

    await this.users.updatePasswordById(user._id.toString(), hashedPassword);

    return { message: 'Password updated successfully' };
  }

  // ---------------- CHANGE PHONE OTP ----------------
  async requestPhoneChangeOtp(userId: string, phoneNumber: string) {
    if (!userId) {
      throw new UnauthorizedException('Missing user id in token');
    }

    const newPhone = phoneNumber?.trim();

    if (!newPhone) {
      throw new BadRequestException('phoneNumber is required');
    }

    const currentUser = await this.users.findById(userId);

    if (!currentUser) {
      throw new BadRequestException('User not found');
    }

    if ((currentUser.phoneNumber ?? '').trim() === newPhone) {
      throw new BadRequestException('New phone is same as current phone');
    }

    const existing = await this.users.findByPhone(newPhone);

    if (existing && existing._id.toString() !== userId) {
      throw new BadRequestException('Phone already exists');
    }

    this.pendingPhoneChange.savePending(userId, newPhone, 300);

    await this.twilio.sendOtpSms(newPhone);

    return { message: 'OTP sent' };
  }

  async verifyPhoneChangeOtp(userId: string, phone: string, code: string) {
    if (!userId) {
      throw new UnauthorizedException('Missing user id in token');
    }

    const targetPhone = phone?.trim();

    if (!targetPhone) {
      throw new BadRequestException('phone is required');
    }

    if (!code?.trim()) {
      throw new BadRequestException('code is required');
    }

    const check = await this.twilio.verifyOtp(targetPhone, code);

    if (check.status !== 'approved') {
      throw new BadRequestException('Invalid or expired OTP');
    }

    const hasPending = this.pendingPhoneChange.consumePending(
      userId,
      targetPhone,
    );

    if (!hasPending) {
      throw new BadRequestException(
        'No pending phone-change for this phone (expired or not requested)',
      );
    }

    const phoneChangeVerificationToken = await this.jwt.signAsync(
      {
        sub: userId,
        type: 'PHONE_CHANGE',
        phoneNumber: targetPhone,
      },
      {
        expiresIn: '10m',
      },
    );

    this.pendingPhoneChange.saveVerifiedToken({
      userId,
      phoneNumber: targetPhone,
      verificationToken: phoneChangeVerificationToken,
      ttlSeconds: 600,
    });

    return {
      message: 'OTP verified',
      phoneChangeVerificationToken,
    };
  }
}