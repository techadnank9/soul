ALTER TYPE "public"."generation_purpose" ADD VALUE 'voice_tone';--> statement-breakpoint
CREATE TABLE "voice_tones" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"entry_id" uuid,
	"student_id" uuid NOT NULL,
	"school_id" uuid NOT NULL,
	"district_id" uuid NOT NULL,
	"emotion" text NOT NULL,
	"intensity" real NOT NULL,
	"intent" text NOT NULL,
	"sounded" text NOT NULL,
	"confidence" real NOT NULL,
	"words_per_minute" smallint,
	"pauses" smallint,
	"longest_pause_ms" integer,
	"hesitations" smallint,
	"audio_events" text[] DEFAULT '{}' NOT NULL,
	"language_code" text,
	"language_probability" real,
	"mean_logprob" real,
	"duration_ms" integer,
	"model_version" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "voice_tones" ADD CONSTRAINT "voice_tones_entry_id_entries_id_fk" FOREIGN KEY ("entry_id") REFERENCES "public"."entries"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "voice_tones" ADD CONSTRAINT "voice_tones_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "voice_tones" ADD CONSTRAINT "voice_tones_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "voice_tones" ADD CONSTRAINT "voice_tones_district_id_districts_id_fk" FOREIGN KEY ("district_id") REFERENCES "public"."districts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "voice_tones_entry_idx" ON "voice_tones" USING btree ("entry_id");--> statement-breakpoint
CREATE INDEX "voice_tones_student_created_idx" ON "voice_tones" USING btree ("student_id","created_at" DESC NULLS LAST);--> statement-breakpoint
CREATE INDEX "voice_tones_student_emotion_idx" ON "voice_tones" USING btree ("student_id","emotion");