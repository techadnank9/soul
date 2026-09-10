ALTER TABLE "students" ADD COLUMN "introduction_entry_id" uuid REFERENCES "entries"("id") ON DELETE SET NULL;
