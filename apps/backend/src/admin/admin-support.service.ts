import { Injectable, NotFoundException } from '@nestjs/common';
import type { AuthUser } from '../auth/auth-user.js';
import { type Pagination, toPage } from '../common/pagination.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { ContactDto } from './admin-support.schemas.js';

@Injectable()
export class AdminSupportService {
  constructor(private readonly prisma: PrismaService) {}

  /** Support mode is read-only. Opening it is written to the audit log first, then the person is described. */
  async start(admin: AuthUser, userId: number) {
    const target = await this.prisma.user.findUnique({ where: { id: userId }, select: { id: true, name: true, role: true } });
    if (!target) throw new NotFoundException('User not found.');
    await this.prisma.auditLog.create({ data: { actorId: admin.id, action: 'support_mode_started', targetUserId: target.id } });
    return target;
  }

  async audit({ limit, cursor }: Pagination) {
    const rows = await this.prisma.auditLog.findMany({
      include: { actor: { select: { id: true, name: true } }, target: { select: { id: true, name: true, role: true } } },
      orderBy: { id: 'desc' },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });
    return toPage(rows, limit);
  }

  async saveContact(dto: ContactDto) {
    await this.prisma.contactMessage.create({ data: dto });
    return { ok: true };
  }

  async contactMessages({ limit, cursor }: Pagination) {
    const rows = await this.prisma.contactMessage.findMany({
      orderBy: { id: 'desc' },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });
    return toPage(rows, limit);
  }
}
