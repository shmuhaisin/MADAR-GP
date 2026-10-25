import { Injectable } from '@nestjs/common';

type Record = {
  phoneNumber: string;
  expiresAt: number;
};

@Injectable()
export class PendingResetStore {
  private map = new Map<string, Record>(); // key = phoneNumber

  save(phoneNumber: string, ttlSeconds = 300) {
    this.map.set(phoneNumber, {
      phoneNumber,
      expiresAt: Date.now() + ttlSeconds * 1000,
    });
  }

  consume(phoneNumber: string): boolean {
    const rec = this.map.get(phoneNumber);
    if (!rec) return false;

    if (Date.now() > rec.expiresAt) {
      this.map.delete(phoneNumber);
      return false;
    }

    this.map.delete(phoneNumber);
    return true;
  }
}
