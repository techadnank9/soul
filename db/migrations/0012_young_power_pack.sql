ALTER TYPE "public"."generation_purpose" ADD VALUE 'people';--> statement-breakpoint
ALTER TYPE "public"."generation_purpose" ADD VALUE 'person_profile';--> statement-breakpoint
CREATE TABLE "entry_people" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"entry_id" uuid NOT NULL,
	"person_id" uuid NOT NULL,
	"student_id" uuid NOT NULL,
	"school_id" uuid NOT NULL,
	"district_id" uuid NOT NULL,
	"said" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "people" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"student_id" uuid NOT NULL,
	"school_id" uuid NOT NULL,
	"district_id" uuid NOT NULL,
	"name" text NOT NULL,
	"relation" text,
	"profile" text,
	"reach" text,
	"name_is_theirs" boolean DEFAULT false NOT NULL,
	"relation_is_theirs" boolean DEFAULT false NOT NULL,
	"reach_is_theirs" boolean DEFAULT false NOT NULL,
	"mentions" integer DEFAULT 0 NOT NULL,
	"first_seen_at" timestamp with time zone,
	"last_seen_at" timestamp with time zone,
	"prompt_version" text,
	"model_version" text,
	"profiled_mentions" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "entry_people" ADD CONSTRAINT "entry_people_entry_id_entries_id_fk" FOREIGN KEY ("entry_id") REFERENCES "public"."entries"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "entry_people" ADD CONSTRAINT "entry_people_person_id_people_id_fk" FOREIGN KEY ("person_id") REFERENCES "public"."people"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "entry_people" ADD CONSTRAINT "entry_people_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "entry_people" ADD CONSTRAINT "entry_people_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "entry_people" ADD CONSTRAINT "entry_people_district_id_districts_id_fk" FOREIGN KEY ("district_id") REFERENCES "public"."districts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "people" ADD CONSTRAINT "people_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "people" ADD CONSTRAINT "people_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "people" ADD CONSTRAINT "people_district_id_districts_id_fk" FOREIGN KEY ("district_id") REFERENCES "public"."districts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "entry_people_entry_person_idx" ON "entry_people" USING btree ("entry_id","person_id");--> statement-breakpoint
CREATE INDEX "entry_people_person_idx" ON "entry_people" USING btree ("person_id");--> statement-breakpoint
CREATE UNIQUE INDEX "people_student_name_idx" ON "people" USING btree ("student_id","name");--> statement-breakpoint
CREATE INDEX "people_student_seen_idx" ON "people" USING btree ("student_id","last_seen_at" DESC NULLS LAST);