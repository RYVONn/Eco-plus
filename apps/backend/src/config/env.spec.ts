import { validateEnv } from './env.js';

const valid = {
  DATABASE_URL: 'postgresql://user@localhost:5432/db',
  JWT_ACCESS_SECRET: 'x'.repeat(32),
};

describe('validateEnv', () => {
  it('accepts a minimal valid environment and fills defaults', () => {
    const env = validateEnv(valid);
    expect(env.PORT).toBe(3000);
    expect(env.NODE_ENV).toBe('development');
    expect(env.SWAGGER_ENABLED).toBe(false);
    expect(env.REFRESH_TTL_DAYS).toBe(30);
  });

  it('converts numbers and the swagger flag from strings', () => {
    const env = validateEnv({ ...valid, PORT: '8080', SWAGGER_ENABLED: 'true' });
    expect(env.PORT).toBe(8080);
    expect(env.SWAGGER_ENABLED).toBe(true);
  });

  it('has safe defaults for the proxy and the phone code limits', () => {
    const env = validateEnv(valid);
    expect(env.TRUST_PROXY).toBe(0);
    expect(env.OTP_IP_HOURLY_LIMIT).toBe(30);
    expect(env.OTP_DAILY_LIMIT).toBe(1000);
    expect(env.JWT_ACCESS_SECRET_PREVIOUS).toBeUndefined();
  });

  it('treats an empty previous secret as not set and refuses a short one', () => {
    expect(validateEnv({ ...valid, JWT_ACCESS_SECRET_PREVIOUS: '' }).JWT_ACCESS_SECRET_PREVIOUS).toBeUndefined();
    expect(() => validateEnv({ ...valid, JWT_ACCESS_SECRET_PREVIOUS: 'short' })).toThrow(/JWT_ACCESS_SECRET_PREVIOUS/);
  });

  it('fails fast and lists every problem', () => {
    expect(() => validateEnv({ JWT_ACCESS_SECRET: 'short' })).toThrow(/DATABASE_URL[\s\S]*JWT_ACCESS_SECRET/);
  });
});
