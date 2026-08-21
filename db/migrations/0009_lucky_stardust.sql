ALTER TYPE "public"."generation_purpose" ADD VALUE 'pattern_verdict';--> statement-breakpoint
CREATE TYPE "public"."theme_verdict" AS ENUM('good', 'bad');--> statement-breakpoint
CREATE TYPE "public"."verdict_source" AS ENUM('outcomes', 'model');--> statement-breakpoint
CREATE TABLE "pattern_verdicts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"student_id" uuid NOT NULL,
	"school_id" uuid NOT NULL,
	"district_id" uuid NOT NULL,
	"theme" text NOT NULL,
	"verdict" "theme_verdict" NOT NULL,
	"source" "verdict_source" NOT NULL,
	"line" text NOT NULL,
	"supporting" integer NOT NULL,
	"prompt_version" text NOT NULL,
	"model_version" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "pattern_verdicts" ADD CONSTRAINT "pattern_verdicts_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "pattern_verdicts" ADD CONSTRAINT "pattern_verdicts_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "pattern_verdicts" ADD CONSTRAINT "pattern_verdicts_district_id_districts_id_fk" FOREIGN KEY ("district_id") REFERENCES "public"."districts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "pattern_verdicts_student_theme_idx" ON "pattern_verdicts" USING btree ("student_id","theme","created_at" DESC NULLS LAST);
