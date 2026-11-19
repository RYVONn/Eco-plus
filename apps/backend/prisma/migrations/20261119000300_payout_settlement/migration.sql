-- AlterTable
ALTER TABLE "weighing_records" ADD COLUMN "paidAt" TIMESTAMP(3),
ADD COLUMN "paidById" INTEGER;

-- CreateIndex
CREATE INDEX "weighing_records_paidAt_idx" ON "weighing_records"("paidAt");
