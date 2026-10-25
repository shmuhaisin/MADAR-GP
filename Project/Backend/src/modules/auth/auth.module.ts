import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigModule, ConfigService } from '@nestjs/config';

import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtStrategy } from './jwt.strategy';
import { UsersModule } from '../users/users.module';
import { TwilioModule } from '../../integrations/twilio/twilio.module';
import { PendingSignupStore } from './otp/pending-signup.store';
import { PendingResetStore } from './otp/pending-reset.store';
import { PendingPhoneChangeStore } from './otp/pending-phone-change.store';

@Module({
  imports: [
    ConfigModule,
    PassportModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (cfg: ConfigService) => ({
        secret: cfg.get<string>('JWT_SECRET') ?? 'dev-secret',
        signOptions: { expiresIn: '30d' },
      }),
    }),
    TwilioModule,
    UsersModule,
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    JwtStrategy,
    PendingSignupStore,
    PendingResetStore,
    PendingPhoneChangeStore,
  ],
  exports: [JwtModule],
})
export class AuthModule {}