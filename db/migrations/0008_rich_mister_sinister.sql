ALTER TABLE "cue_cards" ALTER COLUMN "options" DROP NOT NULL;--> statement-breakpoint
ALTER TABLE "cue_cards" ADD COLUMN "answered_yes" boolean;