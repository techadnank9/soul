ALTER TABLE "tags" ADD COLUMN IF NOT EXISTS "meaning" text;--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "tags_student_meaning_idx" ON "tags" ("student_id","meaning");
