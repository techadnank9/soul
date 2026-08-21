-- The age bands changed shape, from four school age bands to six that reach
-- adulthood. There is no mapping from the old values to the new ones, because
-- 17_18 straddles two of them, so this migration drops what was there. It is
-- safe only because no student has ever answered the question outside this
-- machine. If that stops being true, write the mapping before running it.
ALTER TABLE "students" ALTER COLUMN "age_band" SET DATA TYPE text;--> statement-breakpoint
DROP TYPE "public"."age_band";--> statement-breakpoint
CREATE TYPE "public"."age_band" AS ENUM('under_13', '13_17', '18_24', '25_34', '35_49', '50_plus');--> statement-breakpoint
ALTER TABLE "students" ALTER COLUMN "age_band" SET DATA TYPE "public"."age_band" USING "age_band"::"public"."age_band";