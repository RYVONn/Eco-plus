import { z } from 'zod';

export const createRequestSchema = z.object({
  scanId: z.number().int().positive(),
  // Only businesses can pick cash; for citizens it is ignored and points are used.
  reward: z.enum(['points', 'cash']).optional(),
});

export type CreateRequestDto = z.infer<typeof createRequestSchema>;
