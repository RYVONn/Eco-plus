import { Injectable } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { StatsQueryDto } from './admin-stats.schemas.js';

@Injectable()
export class AdminStatsService {
  constructor(private readonly prisma: PrismaService) {}

  async stats({ days }: StatsQueryDto) {
    const since = new Date();
    since.setUTCHours(0, 0, 0, 0);
    since.setUTCDate(since.getUTCDate() - (days - 1));

    const created = await this.prisma.$queryRaw<{ day: string; n: number }[]>(Prisma.sql`
      SELECT to_char(date_trunc('day', "createdAt"), 'YYYY-MM-DD') AS day, count(*)::int AS n
      FROM shipments WHERE "createdAt" >= ${since} GROUP BY 1`);
    const weighed = await this.prisma.$queryRaw<{ day: string; kg: string; accepted: number; rejected: number }[]>(Prisma.sql`
      SELECT to_char(date_trunc('day', "weighedAt"), 'YYYY-MM-DD') AS day,
             coalesce(sum("actualWeightKg") FILTER (WHERE accepted), 0)::text AS kg,
             count(*) FILTER (WHERE accepted)::int AS accepted,
             count(*) FILTER (WHERE NOT accepted)::int AS rejected
      FROM weighing_records WHERE "weighedAt" >= ${since} GROUP BY 1`);

    const createdBy = new Map(created.map((r) => [r.day, r.n]));
    const weighedBy = new Map(weighed.map((r) => [r.day, r]));
    const series = Array.from({ length: days }, (_, i) => {
      const d = new Date(since);
      d.setUTCDate(since.getUTCDate() + i);
      const day = d.toISOString().slice(0, 10);
      const w = weighedBy.get(day);
      return { day, shipments: createdBy.get(day) ?? 0, kg: Number(w?.kg ?? 0), accepted: w?.accepted ?? 0, rejected: w?.rejected ?? 0 };
    });

    const accepted = series.reduce((s, r) => s + r.accepted, 0);
    const rejected = series.reduce((s, r) => s + r.rejected, 0);
    return {
      days,
      totalKg: series.reduce((s, r) => s + r.kg, 0),
      totalShipments: series.reduce((s, r) => s + r.shipments, 0),
      rejectionRate: accepted + rejected === 0 ? 0 : Number((rejected / (accepted + rejected)).toFixed(3)),
      series,
    };
  }

  /** Where shipments are, for the map: open ones first, capped so the page stays light. */
  async points() {
    const rows = await this.prisma.shipment.findMany({
      select: { id: true, gpsLat: true, gpsLng: true, status: true, sourceType: true },
      orderBy: { id: 'desc' },
      take: 500,
    });
    return { items: rows };
  }

  /** Kilograms recycled and a rough CO2 estimate. The factor is a placeholder until a real source is chosen. */
  async impact() {
    const grouped = await this.prisma.weighingRecord.groupBy({
      by: ['materialTypeId'],
      where: { accepted: true },
      _sum: { actualWeightKg: true },
    });
    const materials = await this.prisma.materialType.findMany({ select: { id: true, name: true } });
    const nameById = new Map(materials.map((m) => [m.id, m.name]));
    const byMaterial = grouped.map((g) => ({
      materialTypeId: g.materialTypeId,
      material: g.materialTypeId === null ? 'Unknown' : (nameById.get(g.materialTypeId) ?? 'Unknown'),
      kg: Number(g._sum.actualWeightKg ?? 0),
    }));
    const totalKg = byMaterial.reduce((s, r) => s + r.kg, 0);
    const co2KgPerKg = 1.5;
    return { totalKg, co2KgPerKg, co2SavedKg: Number((totalKg * co2KgPerKg).toFixed(1)), byMaterial };
  }

  /** Things an admin should look at: shipments that are not moving. */
  async alerts() {
    const day = 24 * 60 * 60 * 1000;
    const now = Date.now();
    const [notAssigned, notCollected, rejectedToday] = await Promise.all([
      this.prisma.shipment.count({ where: { status: 'created', createdAt: { lt: new Date(now - day) } } }),
      this.prisma.shipment.count({ where: { status: 'assigned', updatedAt: { lt: new Date(now - 2 * day) } } }),
      this.prisma.weighingRecord.count({ where: { accepted: false, weighedAt: { gte: new Date(now - day) } } }),
    ]);
    const items = [
      { type: 'not_assigned', severity: 'warn', count: notAssigned },
      { type: 'not_collected', severity: 'bad', count: notCollected },
      { type: 'rejected_today', severity: 'info', count: rejectedToday },
    ].filter((a) => a.count > 0);
    return { items };
  }
}
