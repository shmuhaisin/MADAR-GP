import { Injectable } from '@nestjs/common';
import { Twilio } from 'twilio';

@Injectable()
export class TwilioService {
  private client: Twilio;

  constructor() {
    const sid = process.env.TWILIO_ACCOUNT_SID;
    const token = process.env.TWILIO_AUTH_TOKEN;

    if (!sid || !token) {
      throw new Error('Missing TWILIO_ACCOUNT_SID / TWILIO_AUTH_TOKEN in .env');
    }

    this.client = new Twilio(sid, token);
  }

  async sendOtpSms(phone: string) {
    const serviceSid = process.env.TWILIO_VERIFY_SERVICE_SID;
    if (!serviceSid) throw new Error('Missing TWILIO_VERIFY_SERVICE_SID in .env');

    return this.client.verify.v2
      .services(serviceSid)
      .verifications.create({ to: phone, channel: 'sms' });
  }

  async verifyOtp(phone: string, code: string) {
    const serviceSid = process.env.TWILIO_VERIFY_SERVICE_SID;
    if (!serviceSid) throw new Error('Missing TWILIO_VERIFY_SERVICE_SID in .env');

    return this.client.verify.v2
      .services(serviceSid)
      .verificationChecks.create({ to: phone, code });
  }
}
