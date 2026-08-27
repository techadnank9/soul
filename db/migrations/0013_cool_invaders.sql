CREATE TABLE "legacy_feedback" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"source" text NOT NULL,
	"submitted_on" date,
	"guest_email" text,
	"rating" smallint,
	"ease" text,
	"recommend" text,
	"use_frequency" text,
	"personal_or_generic" text,
	"what_confused_them" text,
	"would_use_again" text,
	"free_text" text,
	"duplicate" text,
	"raw" jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "legacy_users" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"source" text NOT NULL,
	"name" text,
	"email" text NOT NULL,
	"phone" text,
	"age" smallint,
	"gender" text,
	"plan" text,
	"profile_complete" boolean,
	"sessions" integer,
	"joined_on" date,
	"raw" jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE INDEX "legacy_feedback_email_idx" ON "legacy_feedback" USING btree ("guest_email");--> statement-breakpoint
CREATE INDEX "legacy_feedback_submitted_idx" ON "legacy_feedback" USING btree ("submitted_on" DESC NULLS LAST);--> statement-breakpoint
CREATE UNIQUE INDEX "legacy_users_email_idx" ON "legacy_users" USING btree ("email");