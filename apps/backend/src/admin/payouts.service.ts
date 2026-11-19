import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import type { Prisma } from '../generated/prisma/client.js';
import type { AuthUser } from '../auth/auth-user.js';
import { type Pagination, toPage } from '../common/pagination.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { PrismaService } from '../prisma/prisma.service.js';

const view = {
  id: true,
  shipmentId: true,
  actualWeightKg: true,
  payout: true,
  paidAt: true,
  weighedAt: true,
  materialType: { select: { name: true } },
  shipment: {
    select: {
      qrCode: true,
      request: {
        select: { scan: { select: { user: { select: { id: true, name: true, businessProfile: { select: { businessName: true } } } } } } },
      },
    },
  },
} satisfies Prisma.WeighingRecordSelect;

@Injectable()
export class PayoutsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  /** Cash owed to business sellers, newest first, with the total of the whole filter (not just the page). */
  async list(status: 'unpaid' | 'paid', { limit, cursor }: Pagination) {
    const where = { payout: { not: null }, paidAt: status === 'paid' ? { not: null } : null } satisfies Prisma.WeighingRecordWhereInput;
    const [rows, total] = await Promise.all([
      this.prisma.weighingRecord.findMany({
        where,
        select: view,
        orderBy: { id: 'desc' },
        take: limit + 1,
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      }),
      this.prisma.weighingRecord.aggregate({ where, _sum: { payout: true } }),
    ]);
    return { ...toPage(rows, limit), totalEgp: total._sum.payout?.toString() ?? '0' };
  }

  /**
   * Marks one payout as handed over. The claim is a single conditional update, so two admins
   * clicking at once cannot both win; the loser gets 409. The action is audited and the business is told.
   */
  async pay(admin: AuthUser, weighingId: number) {
    return this.prisma.$transaction(async (tx) => {
      const claimed = await tx.weighingRecord.updateMany({
        where: { id: weighingId, payout: { not: null }, paidAt: null },
        data: { paidAt: new Date(), paidById: admin.id },
      });
      if (claimed.count === 0) {
        const existing = await tx.weighingRecord.findUnique({ where: { id: weighingId }, select: { payout: true } });
        if (!existing || existing.payout === null) throw new NotFoundException('No cash payout for this weighing.');
        throw new ConflictException({ code: 'already_paid', message: 'This payout was already paid.' });
      }

      const paid = await tx.weighingRecord.findUniqueOrThrow({ where: { id: weighingId }, select: view });
      const customerId = paid.shipment.request.scan.user.id;
      const amount = paid.payout!.toString();
      await tx.auditLog.create({
        data: { actorId: admin.id, action: 'payout_paid', targetUserId: customerId, details: { weighingId, amountEgp: amount } },
      });
      await this.notifications.notify(customerId, 'Payout paid', `Your cash payout of ${amount} EGP for bag ${paid.shipment.qrCode} was paid.`, tx);
      return paid;
    });
  }

  /** The business's own statement: what it was paid and what is still due. */
  async statement(userId: number, { limit, cursor }: Pagination) {
    const where = { payout: { not: null }, shipment: { request: { scan: { userId } } } } satisfies Prisma.WeighingRecordWhereInput;
    const [rows, due, paid] = await Promise.all([
      this.prisma.weighingRecord.findMany({
        where,
        select: view,
        orderBy: { id: 'desc' },
        take: limit + 1,
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      }),
      this.prisma.weighingRecord.aggregate({ where: { ...where, paidAt: null }, _sum: { payout: true } }),
      this.prisma.weighingRecord.aggregate({ where: { ...where, paidAt: { not: null } }, _sum: { payout: true } }),
    ]);
    return {
      ...toPage(rows, limit),
      dueEgp: due._sum.payout?.toString() ?? '0',
      paidEgp: paid._sum.payout?.toString() ?? '0',
    };
  }
}
