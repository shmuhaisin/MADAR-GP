import { Injectable, OnModuleInit } from '@nestjs/common';
import * as admin from 'firebase-admin';
import { readFileSync } from 'fs';
import { join } from 'path';

@Injectable()
export class FirebaseService implements OnModuleInit {
  onModuleInit() {
    if (!admin.apps.length) {
     const serviceAccount = JSON.parse(
  readFileSync(join(process.cwd(), 'src/firebase-service-account.json'), 'utf8')
);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    }
  }

  async sendPushNotification(token: string, title: string, body: string, data?: Record<string, string>) {
    if (!token) return;
    try {
      await admin.messaging().send({
        token,
        notification: { title, body },
        data: data ?? {},
      });
    } catch (e) {
      console.error('FCM error:', e);
    }
  }
}