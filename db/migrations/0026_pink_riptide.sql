CREATE TABLE "phone_codes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"phone" text NOT NULL,
	"code_hash" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"attempts" integer DEFAULT 0 NOT NULL,
	"consumed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "students" ADD COLUMN "phone" text;--> statement-breakpoint
CREATE INDEX "phone_codes_phone_created_idx" ON "phone_codes" USING btree ("phone","created_at" DESC NULLS LAST);--> statement-breakpoint
CREATE UNIQUE INDEX "students_phone_idx" ON "students" USING btree ("phone");