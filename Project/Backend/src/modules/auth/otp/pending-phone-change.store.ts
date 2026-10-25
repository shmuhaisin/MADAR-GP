import { Injectable } from '@nestjs/common';

type PendingRecord = {
  userId: string;
  phoneNumber: string;
  expiresAt: number;
};

type VerifiedRecord = {
  userId: string;
  phoneNumber: string;
  verificationToken: string;
  expiresAt: number;
};

@Injectable()
export class PendingPhoneChangeStore {
  // key = `${userId}:${phoneNumber}`
  private pendingMap = new Map<string, PendingRecord>();

  // key = verificationToken
  private verifiedMap = new Map<string, VerifiedRecord>();

  private pendingKey(userId: string, phoneNumber: string) {
    return `${userId}:${phoneNumber}`;
  }

  savePending(userId: string, phoneNumber: string, ttlSeconds = 300) {
    const key = this.pendingKey(userId, phoneNumber);
    this.pendingMap.set(key, {
      userId,
      phoneNumber,
      expiresAt: Date.now() + ttlSeconds * 1000,
    });
  }

  consumePending(userId: string, phoneNumber: string): boolean {
    const key = this.pendingKey(userId, phoneNumber);
    const rec = this.pendingMap.get(key);
    if (!rec) return false;

    if (Date.now() > rec.expiresAt) {
      this.pendingMap.delete(key);
      return false;
    }

    this.pendingMap.delete(key);
    return true;
  }

  saveVerifiedToken(params: {
    userId: string;
    phoneNumber: string;
    verificationToken: string;
    ttlSeconds?: number;
  }) {
    const ttlSeconds = params.ttlSeconds ?? 600; // 10 min
    this.verifiedMap.set(params.verificationToken, {
      userId: params.userId,
      phoneNumber: params.phoneNumber,
      verificationToken: params.verificationToken,
      expiresAt: Date.now() + ttlSeconds * 1000,
    });
  }

  consumeVerifiedToken(
    verificationToken: string,
    expectedUserId: string,
    expectedPhoneNumber: string,
  ): boolean {
    const rec = this.verifiedMap.get(verificationToken);
    if (!rec) return false;

    if (Date.now() > rec.expiresAt) {
      this.verifiedMap.delete(verificationToken);
      return false;
    }

    const match =
      rec.userId === expectedUserId && rec.phoneNumber === expectedPhoneNumber;

    if (!match) return false;

    this.verifiedMap.delete(verificationToken);
    return true;
  }
}