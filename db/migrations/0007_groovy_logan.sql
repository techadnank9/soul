ALTER TYPE "public"."generation_purpose" ADD VALUE 'cue_cards';--> statement-breakpoint
CREATE TABLE "cue_cards" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"entry_id" uuid NOT NULL,
	"student_id" uuid NOT NULL,
	"school_id" uuid NOT NULL,
	"district_id" uuid NOT NULL,
	"about" text NOT NULL,
	"question" text NOT NULL,
	"options" text[] NOT NULL,
	"prompt_version" text NOT NULL,
	"model_version" text NOT NULL,
	"chosen_index" smallint,
	"detail" text,
	"decision_id" uuid,
	"answered_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "cue_cards" ADD CONSTRAINT "cue_cards_entry_id_entries_id_fk" FOREIGN KEY ("entry_id") REFERENCES "public"."entries"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cue_cards" ADD CONSTRAINT "cue_cards_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cue_cards" ADD CONSTRAINT "cue_cards_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cue_cards" ADD CONSTRAINT "cue_cards_district_id_districts_id_fk" FOREIGN KEY ("district_id") REFERENCES "public"."districts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cue_cards" ADD CONSTRAINT "cue_cards_decision_id_decisions_id_fk" FOREIGN KEY ("decision_id") REFERENCES "public"."decisions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "cue_cards_student_created_idx" ON "cue_cards" USING btree ("student_id","created_at" DESC NULLS LAST);--> statement-breakpoint
CREATE INDEX "cue_cards_entry_idx" ON "cue_cards" USING btree ("entry_id");