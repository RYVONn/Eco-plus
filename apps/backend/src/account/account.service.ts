import { randomBytes } from 'node:crypto';
import { ConflictException, Injectable } from '@nestjs/common';
import bcrypt from 'bcryptjs';
import { PrismaService } from '../prisma/prisma.service.js';
import { UploadsService } from '../uploads/uploads.service.js';

const BCRYPT_COST = 10;

@Injectable()
export class AccountService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly uploads: UploadsService,
  ) {}

  /**
   * Closes a customer account at their own request. Name, phone, email, address, locations,
   * photos, notifications and devices are erased and the login is disabled. Weighings, points and
   * shipments stay without a name or contact, because the factory's books depend on them.
   * Refused while a pickup is still in progress or cash is still owed to the account.
   */
  async deleteOwn(userId: number): Promise<void> {
    // The stored hash is of a random value nobody knows, so the password can never match again.
    const passwordHash = await bcrypt.hash(randomBytes(24).toString('base64url'), BCRYPT_COST);

    const photos = await this.prisma.$transaction(async (tx) => {
      const user = await tx.user.findUniqueOrThrow({ where: { id: userId }, select: { phone: true } });

      const inProgress = await tx.pickupRequest.count({
        where: {
          scan: { userId },
          OR: [{ status: { in: ['open', 'scheduled'] } }, { shipment: { status: { in: ['created', 'assigned', 'collected'] } } }],
        },
      });
      if (inProgress > 0) {
        throw new ConflictException({
          code: 'pickup_in_progress',
          message: 'Cancel or finish your open pickups before deleting your account.',
        });
      }

      const owed = await tx.weighingRecord.aggregate({
        where: { payout: { not: null }, paidAt: null, shipment: { request: { scan: { userId } } } },
        _sum: { payout: true },
      });
      if (owed._sum.payout?.gt(0)) {
        throw new ConflictException({
          code: 'payout_due',
          message: `You are still owed ${owed._sum.payout.toString()} EGP. Collect it before deleting your account.`,
        });
      }

      const scans = await tx.bagScan.findMany({ where: { userId, imageUrl: { not: null } }, select: { imageUrl: true } });

      await tx.user.update({
        where: { id: userId },
        data: { name: 'Deleted user', phone: null, email: null, passwordHash, isActive: false },
      });
      await tx.refreshToken.deleteMany({ where: { userId } });
      await tx.deviceToken.deleteMany({ where: { userId } });
      await tx.notification.deleteMany({ where: { userId } });
      if (user.phone) await tx.otpCode.deleteMany({ where: { phone: user.phone } });
      await tx.citizenProfile.updateMany({ where: { userId }, data: { address: null, lat: null, lng: null } });
      await tx.businessProfile.updateMany({
        where: { userId },
        data: { businessName: 'Deleted business', agreementRef: null, lat: null, lng: null },
      });
      await tx.bagScan.updateMany({ where: { userId }, data: { imageUrl: null, lat: null, lng: null } });
      await tx.auditLog.create({ data: { actorId: userId, action: 'account_deleted', targetUserId: userId } });

      return scans.flatMap((s) => (s.imageUrl ? [s.imageUrl] : []));
    });

    await this.uploads.removeMany(photos);
  }
}
