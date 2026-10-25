import { Injectable } from '@nestjs/common';
import { RequestSignupOtpDto } from './dto/request-signup-otp.dto';

type Record = {
  payload: RequestSignupOtpDto;
  expiresAt: number;
};

@Injectable()
export class PendingSignupStore {
  private map = new Map<string, Record>(); // key = phoneNumber

  save(phoneNumber: string, payload: RequestSignupOtpDto, ttlSeconds = 300) {
    this.map.set(phoneNumber, {
      payload,
      expiresAt: Date.now() + ttlSeconds * 1000,
    });
  }

  consume(phoneNumber: string): RequestSignupOtpDto | null {
    const rec = this.map.get(phoneNumber);
    if (!rec) return null;

    if (Date.now() > rec.expiresAt) {
      this.map.delete(phoneNumber);
      return null;
    }

    this.map.delete(phoneNumber);
    return rec.payload;
  }

  peek(phoneNumber: string): RequestSignupOtpDto | null {
    const rec = this.map.get(phoneNumber);
    if (!rec) return null;
    if (Date.now() > rec.expiresAt) {
      this.map.delete(phoneNumber);
      return null;
    }
    return rec.payload;
  }
}
