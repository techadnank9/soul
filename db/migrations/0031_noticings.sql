ALTER TYPE "public"."generation_purpose" ADD VALUE IF NOT EXISTS 'noticings';--> statement-breakpoint
DO $$ BEGIN
  CREATE TYPE "public"."noticing_lean" AS ENUM('good', 'bad', 'open');
EXCEPTION WHEN duplicate_object THEN null; END $$;--> statement-breakpoint
DO $$ BEGIN
  CREATE TYPE "public"."noticing_status" AS ENUM('open', 'confirmed', 'rejected', 'unsure', 'superseded');
EXCEPTION WHEN duplicate_object THEN null; END $$;--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "noticings" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
  "student_id" uuid NOT NULL REFERENCES "students"("id"),
  "school_id" uuid NOT NULL REFERENCES "schools"("id"),
  "district_id" uuid NOT NULL REFERENCES "districts"("id"),
  "line" text NOT NULL,
  "lean" "noticing_lean" NOT NULL,
  "evidence_entry_ids" uuid[] NOT NULL,
  "status" "noticing_status" DEFAULT 'open' NOT NULL,
  "answered_at" timestamp with time zone,
  "prompt_version" text NOT NULL,
  "model_version" text NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL
);--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "noticings_student_status_idx" ON "noticings" ("student_id","status","created_at" DESC);
