import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(cfg: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: cfg.get<string>('JWT_SECRET') ?? 'dev-secret',
    });
    console.log('JWT_SECRET length =', (cfg.get('JWT_SECRET') ?? 'dev-secret').length);

  }

  async validate(payload: any) {
  return {
    userId: payload.userId ?? payload.sub,  
    email: payload.email,
    username: payload.username,
    userID: payload.userID,
  };
}

}
