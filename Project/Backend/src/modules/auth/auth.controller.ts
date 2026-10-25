import { Body, Controller, Post, Req, UseGuards } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';

import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';

import { RequestSignupOtpDto } from './otp/dto/request-signup-otp.dto';
import { VerifyOtpDto } from './otp/dto/verify-otp.dto';
import { RequestResetOtpDto } from './otp/dto/request-reset-otp.dto';
import { ConfirmResetDto } from './otp/dto/confirm-reset.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';

import { JwtAuthGuard } from './jwt-auth.guard';
import { RequestPhoneChangeOtpDto } from './otp/dto/request-phone-change-otp.dto';
import { VerifyPhoneChangeOtpDto } from './otp/dto/verify-phone-change-otp.dto';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('signin')
  signin(@Body() dto: LoginDto) {
    return this.authService.signin(dto);
  }

  // --------- SIGNUP OTP FLOW ----------
  @Post('signup/request-otp')
  requestSignupOtp(@Body() dto: RequestSignupOtpDto) {
    return this.authService.requestSignupOtp(dto);
  }

  @Post('signup/verify-otp')
  verifySignupOtp(@Body() dto: VerifyOtpDto) {
    return this.authService.verifySignupOtp(dto.phone, dto.code);
  }

  // --------- RESET PASSWORD OTP FLOW ----------
  @Post('password/request-otp')
  requestResetOtp(@Body() dto: RequestResetOtpDto) {
    return this.authService.requestResetOtp(dto.phoneNumber);
  }

  @Post('password/confirm')
  confirmReset(@Body() dto: ConfirmResetDto) {
    return this.authService.confirmReset(dto.phone, dto.code);
  }

  @Post('password/reset')
  resetPassword(@Body() dto: ResetPasswordDto) {
    return this.authService.resetPassword(dto.resetToken, dto.newPassword);
  }

  // --------- CHANGE PHONE OTP FLOW (AUTH REQUIRED) ----------
  @UseGuards(JwtAuthGuard)
  @Post('phone-change/request-otp')
  requestPhoneChangeOtp(@Req() req: Request, @Body() dto: RequestPhoneChangeOtpDto) {
    const userId = (req as any).user?.userId;
    return this.authService.requestPhoneChangeOtp(userId, dto.phoneNumber);
  }

  @UseGuards(JwtAuthGuard)
  @Post('phone-change/verify-otp')
  verifyPhoneChangeOtp(@Req() req: Request, @Body() dto: VerifyPhoneChangeOtpDto) {
    const userId = (req as any).user?.userId;
    return this.authService.verifyPhoneChangeOtp(userId, dto.phone, dto.code);
  }
}