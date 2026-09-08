CREATE TABLE IF NOT EXISTS "feedback" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
  "student_id" uuid NOT NULL REFERENCES "students"("id"),
  "school_id" uuid NOT NULL REFERENCES "schools"("id"),
  "district_id" uuid NOT NULL REFERENCES "districts"("id"),
  "text" text NOT NULL,
  "surface" text,
  "app_version" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE INDEX IF NOT EXISTS "feedback_created_idx" ON "feedback" ("created_at" DESC);
CREATE INDEX IF NOT EXISTS "feedback_student_created_idx" ON "feedback" ("student_id","created_at" DESC);
