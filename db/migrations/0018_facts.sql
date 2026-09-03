ALTER TYPE "public"."generation_purpose" ADD VALUE 'facts';--> statement-breakpoint
ALTER TYPE "public"."generation_purpose" ADD VALUE 'embedding';--> statement-breakpoint
CREATE TABLE "facts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"student_id" uuid NOT NULL,
	"school_id" uuid NOT NULL,
	"district_id" uuid NOT NULL,
	"subject" text NOT NULL,
	"predicate" text NOT NULL,
	"object" text NOT NULL,
	"sentence" text NOT NULL,
	"entry_ids" uuid[] NOT NULL,
	"valid_from" timestamp with time zone NOT NULL,
	"valid_to" timestamp with time zone,
	"learned_at" timestamp with time zone DEFAULT now() NOT NULL,
	"retired_at" timestamp with time zone,
	"confidence" real NOT NULL,
	"tier" integer DEFAULT 0 NOT NULL,
	"embedding" vector(1536),
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "facts" ADD CONSTRAINT "facts_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "facts" ADD CONSTRAINT "facts_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "facts" ADD CONSTRAINT "facts_district_id_districts_id_fk" FOREIGN KEY ("district_id") REFERENCES "public"."districts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "facts_student_open_idx" ON "facts" USING btree ("student_id","valid_to","retired_at");--> statement-breakpoint
CREATE INDEX "facts_student_subject_idx" ON "facts" USING btree ("student_id","subject","predicate");--> statement-breakpoint
CREATE INDEX "facts_hnsw_idx" ON "facts" USING hnsw ("embedding" vector_cosine_ops);