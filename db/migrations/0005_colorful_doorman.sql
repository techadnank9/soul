-- The gender values became male and female rather than boy and girl.
--
-- The two old values are mapped rather than dropped, because unlike the age
-- bands this one is a rename and not a reshape. A student who answered boy
-- means the same thing they meant before.
ALTER TABLE "students" ALTER COLUMN "gender" SET DATA TYPE text;--> statement-breakpoint
UPDATE "students" SET "gender" = 'male' WHERE "gender" = 'boy';--> statement-breakpoint
UPDATE "students" SET "gender" = 'female' WHERE "gender" = 'girl';--> statement-breakpoint
DROP TYPE "public"."gender";--> statement-breakpoint
CREATE TYPE "public"."gender" AS ENUM('male', 'female', 'nonbinary', 'not_said');--> statement-breakpoint
ALTER TABLE "students" ALTER COLUMN "gender" SET DATA TYPE "public"."gender" USING "gender"::"public"."gender";
