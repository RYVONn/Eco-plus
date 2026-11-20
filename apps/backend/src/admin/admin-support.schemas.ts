import { z } from 'zod';

export const startSupportSchema = z.object({ userId: z.number().int().positive() });
export type StartSupportDto = z.infer<typeof startSupportSchema>;

export const contactSchema = z.object({
  name: z.string().trim().min(1).max(100),
  contact: z.string().trim().min(3).max(120),
  message: z.string().trim().min(5).max(2000),
});
export type ContactDto = z.infer<typeof contactSchema>;
