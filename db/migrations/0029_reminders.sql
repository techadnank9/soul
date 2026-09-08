ALTER TYPE "public"."generation_purpose" ADD VALUE IF NOT EXISTS 'reminders';--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "reminders" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
  "student_id" uuid NOT NULL REFERENCES "students"("id"),
  "school_id" uuid NOT NULL REFERENCES "schools"("id"),
  "district_id" uuid NOT NULL REFERENCES "districts"("id"),
  "entry_id" uuid NOT NULL REFERENCES "entries"("id") ON DELETE CASCADE,
  "due_at" timestamp with time zone NOT NULL,
  "said" text NOT NULL,
  "cancelled_at" timestamp with time zone,
  "scheduled_at" timestamp with time zone,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE INDEX IF NOT EXISTS "reminders_due_idx" ON "reminders" ("student_id","due_at");
