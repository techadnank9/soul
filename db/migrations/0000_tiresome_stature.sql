CREATE TYPE "public"."actor_role" AS ENUM('student', 'system', 'counsellor', 'district_admin');--> statement-breakpoint
CREATE TYPE "public"."candidate_status" AS ENUM('pending', 'surfaced', 'confirmed', 'rejected');--> statement-breakpoint
CREATE TYPE "public"."consent_model" AS ENUM('school', 'parent', 'dual');--> statement-breakpoint
CREATE TYPE "public"."decision_status" AS ENUM('open', 'closed', 'abandoned');--> statement-breakpoint
CREATE TYPE "public"."felt_after" AS ENUM('lighter', 'same', 'worse');--> statement-breakpoint
CREATE TYPE "public"."generation_purpose" AS ENUM('safety', 'beat_one', 'mirror', 'tagger');--> statement-breakpoint
CREATE TYPE "public"."input_mode" AS ENUM('voice', 'typed');--> statement-breakpoint
CREATE TYPE "public"."job_status" AS ENUM('pending', 'running', 'done', 'failed', 'cancelled');--> statement-breakpoint
CREATE TYPE "public"."risk_level" AS ENUM('none', 'low', 'medium', 'high');--> statement-breakpoint
CREATE TYPE "public"."safety_status" AS ENUM('open', 'acknowledged', 'closed');--> statement-breakpoint
CREATE TABLE "audit_log" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"actor_id" uuid,
	"actor_role" "actor_role" NOT NULL,
	"action" text NOT NULL,
	"subject_student_id" uuid,
	"subject_type" text NOT NULL,
	"subject_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "confirmed_patterns" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"student_id" uuid NOT NULL,
	"school_id" uuid NOT NULL,
	"district_id" uuid NOT NULL,
	"theme" text NOT NULL,
	"supporting_entry_ids" uuid[] NOT NULL,
	"confirmed_at" timestamp with time zone DEFAULT now() NOT NULL,
	"reminder_armed" boolean DEFAULT false NOT NULL,
	"removed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "decisions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"entry_id" uuid NOT NULL,
	"student_id" uuid NOT NULL,
	"school_id" uuid NOT NULL,
	"district_id" uuid NOT NULL,
	"offered_text" text,
	"chosen_text" text NOT NULL,
	"horizon" timestamp with time zone NOT NULL,
	"status" "decision_status" DEFAULT 'open' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "districts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"consent_model" "consent_model" DEFAULT 'school' NOT NULL,
	"retention_days" integer NOT NULL,
	"escalation_policy" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "entries" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"student_id" uuid NOT NULL,
	"school_id" uuid NOT NULL,
	"district_id" uuid NOT NULL,
	"text" text NOT NULL,
	"input_mode" "input_mode" NOT NULL,
	"transcript_confirmed" boolean DEFAULT false NOT NULL,
	"duration_ms" integer,
	"local_hour" smallint,
	"processed" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "entry_embeddings" (
	"entry_id" uuid PRIMARY KEY NOT NULL,
	"student_id" uuid NOT NULL,
	"school_id" uuid NOT NULL,
	"district_id" uuid NOT NULL,
	"embedding" vector(1536) NOT NULL,
	"model_version" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "generations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"entry_id" uuid,
	"student_id" uuid NOT NULL,
	"school_id" uuid NOT NULL,
	"district_id" uuid NOT NULL,
	"purpose" "generation_purpose" NOT NULL,
	"prompt_version" text NOT NULL,
	"model_version" text NOT NULL,
	"provider" text NOT NULL,
	"latency_ms" integer,
	"input_tokens" integer,
	"output_tokens" integer,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "jobs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"type" text NOT NULL,
	"payload" text NOT NULL,
	"student_id" uuid,
	"school_id" uuid,
	"district_id" uuid,
	"run_at" timestamp with time zone DEFAULT now() NOT NULL,
	"attempts" integer DEFAULT 0 NOT NULL,
	"last_error" text,
	"status" "job_status" DEFAULT 'pending' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "kept_lines" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"entry_id" uuid NOT NULL,
	"student_id" uuid NOT NULL,
	"school_id" uuid NOT NULL,
	"district_id" uuid NOT NULL,
	"text" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "outcomes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"decision_id" uuid NOT NULL,
	"student_id" uuid NOT NULL,
	"school_id" uuid NOT NULL,
	"district_id" uuid NOT NULL,
	"what_happened" text,
	"felt" "felt_after",
	"responded_at" timestamp with time zone,
	"ignored_count" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "pattern_candidates" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"student_id" uuid NOT NULL,
	"school_id" uuid NOT NULL,
	"district_id" uuid NOT NULL,
	"theme" text NOT NULL,
	"supporting_entry_ids" uuid[] NOT NULL,
	"proposed_at" timestamp with time zone DEFAULT now() NOT NULL,
	"surfaced_at" timestamp with time zone,
	"status" "candidate_status" DEFAULT 'pending' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "pattern_rejections" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"student_id" uuid NOT NULL,
	"school_id" uuid NOT NULL,
	"district_id" uuid NOT NULL,
	"theme" text NOT NULL,
	"rejected_at" timestamp with time zone DEFAULT now() NOT NULL,
	"reason" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "prompts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"purpose" "generation_purpose" NOT NULL,
	"version" text NOT NULL,
	"text" text NOT NULL,
	"active" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "safety_flags" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"entry_id" uuid NOT NULL,
	"student_id" uuid NOT NULL,
	"school_id" uuid NOT NULL,
	"district_id" uuid NOT NULL,
	"risk_level" "risk_level" NOT NULL,
	"categories" text[] DEFAULT '{}'::text[] NOT NULL,
	"classifier_version" text NOT NULL,
	"action_taken" text NOT NULL,
	"resources_shown" boolean DEFAULT false NOT NULL,
	"status" "safety_status" DEFAULT 'open' NOT NULL,
	"reviewed_by" uuid,
	"reviewed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "schools" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"district_id" uuid NOT NULL,
	"name" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "students" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"district_id" uuid NOT NULL,
	"external_ref" text NOT NULL,
	"year_group" smallint,
	"consent_recorded_at" timestamp with time zone,
	"consent_version" text,
	"notify_opt_in" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "tags" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"entry_id" uuid NOT NULL,
	"student_id" uuid NOT NULL,
	"school_id" uuid NOT NULL,
	"district_id" uuid NOT NULL,
	"trigger" text,
	"feeling" text,
	"coping" text,
	"domain" text,
	"confidence" real NOT NULL,
	"tagger_version" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "audit_log" ADD CONSTRAINT "audit_log_subject_student_id_students_id_fk" FOREIGN KEY ("subject_student_id") REFERENCES "public"."students"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "confirmed_patterns" ADD CONSTRAINT "confirmed_patterns_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "confirmed_patterns" ADD CONSTRAINT "confirmed_patterns_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "confirmed_patterns" ADD CONSTRAINT "confirmed_patterns_district_id_districts_id_fk" FOREIGN KEY ("district_id") REFERENCES "public"."districts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "decisions" ADD CONSTRAINT "decisions_entry_id_entries_id_fk" FOREIGN KEY ("entry_id") REFERENCES "public"."entries"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "decisions" ADD CONSTRAINT "decisions_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "decisions" ADD CONSTRAINT "decisions_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "decisions" ADD CONSTRAINT "decisions_district_id_districts_id_fk" FOREIGN KEY ("district_id") REFERENCES "public"."districts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "entries" ADD CONSTRAINT "entries_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "entries" ADD CONSTRAINT "entries_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "entries" ADD CONSTRAINT "entries_district_id_districts_id_fk" FOREIGN KEY ("district_id") REFERENCES "public"."districts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "entry_embeddings" ADD CONSTRAINT "entry_embeddings_entry_id_entries_id_fk" FOREIGN KEY ("entry_id") REFERENCES "public"."entries"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "entry_embeddings" ADD CONSTRAINT "entry_embeddings_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "entry_embeddings" ADD CONSTRAINT "entry_embeddings_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "entry_embeddings" ADD CONSTRAINT "entry_embeddings_district_id_districts_id_fk" FOREIGN KEY ("district_id") REFERENCES "public"."districts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "generations" ADD CONSTRAINT "generations_entry_id_entries_id_fk" FOREIGN KEY ("entry_id") REFERENCES "public"."entries"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "generations" ADD CONSTRAINT "generations_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "generations" ADD CONSTRAINT "generations_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "generations" ADD CONSTRAINT "generations_district_id_districts_id_fk" FOREIGN KEY ("district_id") REFERENCES "public"."districts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "jobs" ADD CONSTRAINT "jobs_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "jobs" ADD CONSTRAINT "jobs_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "jobs" ADD CONSTRAINT "jobs_district_id_districts_id_fk" FOREIGN KEY ("district_id") REFERENCES "public"."districts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "kept_lines" ADD CONSTRAINT "kept_lines_entry_id_entries_id_fk" FOREIGN KEY ("entry_id") REFERENCES "public"."entries"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "kept_lines" ADD CONSTRAINT "kept_lines_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "kept_lines" ADD CONSTRAINT "kept_lines_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "kept_lines" ADD CONSTRAINT "kept_lines_district_id_districts_id_fk" FOREIGN KEY ("district_id") REFERENCES "public"."districts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "outcomes" ADD CONSTRAINT "outcomes_decision_id_decisions_id_fk" FOREIGN KEY ("decision_id") REFERENCES "public"."decisions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "outcomes" ADD CONSTRAINT "outcomes_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "outcomes" ADD CONSTRAINT "outcomes_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "outcomes" ADD CONSTRAINT "outcomes_district_id_districts_id_fk" FOREIGN KEY ("district_id") REFERENCES "public"."districts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "pattern_candidates" ADD CONSTRAINT "pattern_candidates_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "pattern_candidates" ADD CONSTRAINT "pattern_candidates_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "pattern_candidates" ADD CONSTRAINT "pattern_candidates_district_id_districts_id_fk" FOREIGN KEY ("district_id") REFERENCES "public"."districts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "pattern_rejections" ADD CONSTRAINT "pattern_rejections_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "pattern_rejections" ADD CONSTRAINT "pattern_rejections_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "pattern_rejections" ADD CONSTRAINT "pattern_rejections_district_id_districts_id_fk" FOREIGN KEY ("district_id") REFERENCES "public"."districts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "safety_flags" ADD CONSTRAINT "safety_flags_entry_id_entries_id_fk" FOREIGN KEY ("entry_id") REFERENCES "public"."entries"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "safety_flags" ADD CONSTRAINT "safety_flags_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "safety_flags" ADD CONSTRAINT "safety_flags_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "safety_flags" ADD CONSTRAINT "safety_flags_district_id_districts_id_fk" FOREIGN KEY ("district_id") REFERENCES "public"."districts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "schools" ADD CONSTRAINT "schools_district_id_districts_id_fk" FOREIGN KEY ("district_id") REFERENCES "public"."districts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "students" ADD CONSTRAINT "students_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "students" ADD CONSTRAINT "students_district_id_districts_id_fk" FOREIGN KEY ("district_id") REFERENCES "public"."districts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "tags" ADD CONSTRAINT "tags_entry_id_entries_id_fk" FOREIGN KEY ("entry_id") REFERENCES "public"."entries"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "tags" ADD CONSTRAINT "tags_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "tags" ADD CONSTRAINT "tags_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "tags" ADD CONSTRAINT "tags_district_id_districts_id_fk" FOREIGN KEY ("district_id") REFERENCES "public"."districts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "audit_log_subject_student_created_idx" ON "audit_log" USING btree ("subject_student_id","created_at" DESC NULLS LAST);--> statement-breakpoint
CREATE INDEX "confirmed_patterns_student_idx" ON "confirmed_patterns" USING btree ("student_id");--> statement-breakpoint
CREATE INDEX "decisions_student_status_idx" ON "decisions" USING btree ("student_id","status");--> statement-breakpoint
CREATE INDEX "entries_student_created_idx" ON "entries" USING btree ("student_id","created_at" DESC NULLS LAST);--> statement-breakpoint
CREATE INDEX "entry_embeddings_hnsw_idx" ON "entry_embeddings" USING hnsw ("embedding" vector_cosine_ops);--> statement-breakpoint
CREATE INDEX "entry_embeddings_student_idx" ON "entry_embeddings" USING btree ("student_id");--> statement-breakpoint
CREATE INDEX "generations_purpose_created_idx" ON "generations" USING btree ("purpose","created_at" DESC NULLS LAST);--> statement-breakpoint
CREATE INDEX "jobs_status_run_at_idx" ON "jobs" USING btree ("status","run_at");--> statement-breakpoint
CREATE INDEX "kept_lines_student_created_idx" ON "kept_lines" USING btree ("student_id","created_at" DESC NULLS LAST);--> statement-breakpoint
CREATE INDEX "outcomes_decision_idx" ON "outcomes" USING btree ("decision_id");--> statement-breakpoint
CREATE INDEX "pattern_candidates_student_status_idx" ON "pattern_candidates" USING btree ("student_id","status");--> statement-breakpoint
CREATE INDEX "pattern_rejections_student_theme_idx" ON "pattern_rejections" USING btree ("student_id","theme");--> statement-breakpoint
CREATE UNIQUE INDEX "prompts_purpose_version_idx" ON "prompts" USING btree ("purpose","version");--> statement-breakpoint
CREATE UNIQUE INDEX "prompts_active_idx" ON "prompts" USING btree ("purpose") WHERE "prompts"."active";--> statement-breakpoint
CREATE UNIQUE INDEX "safety_flags_entry_idx" ON "safety_flags" USING btree ("entry_id");--> statement-breakpoint
CREATE INDEX "safety_flags_status_created_idx" ON "safety_flags" USING btree ("status","created_at" DESC NULLS LAST);--> statement-breakpoint
CREATE INDEX "schools_district_idx" ON "schools" USING btree ("district_id");--> statement-breakpoint
CREATE UNIQUE INDEX "students_school_external_ref_idx" ON "students" USING btree ("school_id","external_ref");--> statement-breakpoint
CREATE INDEX "tags_student_feeling_idx" ON "tags" USING btree ("student_id","feeling");--> statement-breakpoint
CREATE INDEX "tags_student_trigger_idx" ON "tags" USING btree ("student_id","trigger");--> statement-breakpoint
CREATE INDEX "tags_entry_idx" ON "tags" USING btree ("entry_id");