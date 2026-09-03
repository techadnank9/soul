CREATE TABLE "email_codes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"email" text NOT NULL,
	"code_hash" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"attempts" smallint DEFAULT 0 NOT NULL,
	"consumed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "students" ADD COLUMN "email" text;--> statement-breakpoint
CREATE INDEX "email_codes_email_created_idx" ON "email_codes" USING btree ("email","created_at" DESC NULLS LAST);--> statement-breakpoint
CREATE UNIQUE INDEX "students_email_idx" ON "students" USING btree ("email");