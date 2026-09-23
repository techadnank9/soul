ALTER TABLE "confirmed_patterns" ADD COLUMN IF NOT EXISTS "wording" text;--> statement-breakpoint
ALTER TABLE "confirmed_patterns" ADD COLUMN IF NOT EXISTS "standing" text;
