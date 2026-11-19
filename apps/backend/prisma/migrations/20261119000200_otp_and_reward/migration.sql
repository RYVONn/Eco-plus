-- CreateEnum
CREATE TYPE "RewardChoice" AS ENUM ('points', 'cash');

-- AlterTable
ALTER TABLE "pickup_requests" ADD COLUMN "reward" "RewardChoice" NOT NULL DEFAULT 'points';

-- AlterTable
ALTER TABLE "weighing_records" ADD COLUMN "payout" DECIMAL(12,2);

-- CreateTable
CREATE TABLE "otp_codes" (
    "id" SERIAL NOT NULL,
    "phone" TEXT NOT NULL,
    "codeHash" TEXT NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "consumedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "otp_codes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "otp_codes_phone_createdAt_idx" ON "otp_codes"("phone", "createdAt");
