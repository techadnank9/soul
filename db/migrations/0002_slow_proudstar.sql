CREATE TYPE "public"."age_band" AS ENUM('under_13', '13_14', '15_16', '17_18');--> statement-breakpoint
CREATE TYPE "public"."gender" AS ENUM('girl', 'boy', 'nonbinary', 'not_said');--> statement-breakpoint
ALTER TABLE "students" ADD COLUMN "display_name" text;--> statement-breakpoint
ALTER TABLE "students" ADD COLUMN "age_band" "age_band";--> statement-breakpoint
ALTER TABLE "students" ADD COLUMN "gender" "gender";--> statement-breakpoint
ALTER TABLE "students" ADD COLUMN "region" text;--> statement-breakpoint
ALTER TABLE "students" ADD COLUMN "timezone" text;--> statement-breakpoint
ALTER TABLE "students" ADD COLUMN "profile_recorded_at" timestamp with time zone;