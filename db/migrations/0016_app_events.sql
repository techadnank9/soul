CREATE TABLE "app_events" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"student_id" uuid NOT NULL,
	"school_id" uuid NOT NULL,
	"district_id" uuid NOT NULL,
	"name" text NOT NULL,
	"detail" jsonb,
	"app_version" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "app_events" ADD CONSTRAINT "app_events_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app_events" ADD CONSTRAINT "app_events_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app_events" ADD CONSTRAINT "app_events_district_id_districts_id_fk" FOREIGN KEY ("district_id") REFERENCES "public"."districts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "app_events_created_idx" ON "app_events" USING btree ("created_at" DESC NULLS LAST);--> statement-breakpoint
CREATE INDEX "app_events_student_created_idx" ON "app_events" USING btree ("student_id","created_at" DESC NULLS LAST);