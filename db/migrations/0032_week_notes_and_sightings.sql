ALTER TYPE "public"."generation_purpose" ADD VALUE IF NOT EXISTS 'week_notes';--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "week_notes" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
  "student_id" uuid NOT NULL REFERENCES "students"("id"),
  "school_id" uuid NOT NULL REFERENCES "schools"("id"),
  "district_id" uuid NOT NULL REFERENCES "districts"("id"),
  "week_start" date NOT NULL,
  "lines" text[] NOT NULL,
  "moments" integer NOT NULL,
  "prompt_version" text NOT NULL,
  "model_version" text NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL
);--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "week_notes_student_week_idx" ON "week_notes" ("student_id","week_start");--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "section_sightings" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
  "student_id" uuid NOT NULL REFERENCES "students"("id"),
  "school_id" uuid NOT NULL REFERENCES "schools"("id"),
  "district_id" uuid NOT NULL REFERENCES "districts"("id"),
  "section" text NOT NULL,
  "entry_id" uuid NOT NULL REFERENCES "entries"("id") ON DELETE CASCADE,
  "prompt_version" text NOT NULL,
  "model_version" text NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL
);--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "section_sightings_section_entry_idx" ON "section_sightings" ("section","entry_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "section_sightings_student_idx" ON "section_sightings" ("student_id","section","created_at" DESC);
