-- AlterTable
ALTER TABLE "otp_codes" ADD COLUMN "failedAt" TIMESTAMP(3);

-- CreateIndex
CREATE INDEX "otp_codes_createdAt_idx" ON "otp_codes"("createdAt");
