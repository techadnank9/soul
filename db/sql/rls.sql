-- Row level security for every table.
--
-- Application code is not the only guard. The request path connects as
-- soul_student and sets app.student_id for the duration of the transaction.
-- Everything the student can reach is scoped by these policies.
--
-- This file is idempotent and is applied after every migration run.

create extension if not exists vector;

-- Roles ---------------------------------------------------------------------

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'soul_student') then
    create role soul_student nologin;
  end if;
end
$$;

do $$
begin
  execute format('grant soul_student to %I', current_user);
exception when others then
  null;
end
$$;

-- Session helper ------------------------------------------------------------

create or replace function app_current_student() returns uuid
language sql stable as $$
  select nullif(current_setting('app.student_id', true), '')::uuid
$$;

create or replace function app_current_school() returns uuid
language sql stable as $$
  select school_id from students where id = app_current_student()
$$;

create or replace function app_current_district() returns uuid
language sql stable as $$
  select district_id from students where id = app_current_student()
$$;

-- Enable and force row level security everywhere -----------------------------

do $$
declare t text;
begin
  foreach t in array array[
    'districts','schools','students','sessions','entries','kept_lines','tags',
    'voice_tones','baseline_answers',
    'entry_embeddings','decisions','outcomes','cue_cards','pattern_candidates',
    'confirmed_patterns','pattern_rejections','pattern_verdicts','safety_flags',
    'people','entry_people',
    'generations','prompts','jobs','audit_log','email_codes',
    'legacy_feedback','legacy_users'
  ]
  loop
    execute format('alter table %I enable row level security', t);
    execute format('alter table %I force row level security', t);
    execute format('grant select, insert, update on table %I to soul_student', t);
  end loop;
end
$$;

-- Student scoped tables ------------------------------------------------------

do $$
declare t text;
begin
  foreach t in array array[
    'entries','kept_lines','tags','voice_tones','entry_embeddings','decisions','outcomes',
    'baseline_answers','cue_cards',
    'pattern_candidates','confirmed_patterns','pattern_rejections',
    'pattern_verdicts','safety_flags','generations','people','entry_people'
  ]
  loop
    execute format('drop policy if exists %I on %I', t || '_student_scope', t);
    execute format(
      'create policy %I on %I to soul_student
         using (student_id = app_current_student())
         with check (student_id = app_current_student()
                     and school_id = app_current_school()
                     and district_id = app_current_district())',
      t || '_student_scope', t);
  end loop;
end
$$;

-- What a student may remove --------------------------------------------------

-- Delete was never granted, so nothing a student owns could be deleted by the
-- request path. The product promises the opposite: everything the app holds is
-- something they can remove, and the people tables made that promise concrete
-- the moment somebody wanted a person gone.
--
-- Granted on the student scoped tables only. prompts, jobs and audit_log are
-- deliberately absent: an audit row a student can delete is not an audit row.
do $$
declare t text;
begin
  foreach t in array array[
    'entries','kept_lines','tags','voice_tones','entry_embeddings','decisions','outcomes',
    'baseline_answers','cue_cards',
    'pattern_candidates','confirmed_patterns','pattern_rejections',
    'pattern_verdicts','people','entry_people'
  ]
  loop
    execute format('grant delete on table %I to soul_student', t);
  end loop;
end
$$;

-- The student row itself -----------------------------------------------------

drop policy if exists students_self on students;
create policy students_self on students to soul_student
  using (id = app_current_student())
  with check (id = app_current_student());

drop policy if exists schools_own on schools;
create policy schools_own on schools to soul_student
  using (id = app_current_school());

drop policy if exists districts_own on districts;
create policy districts_own on districts to soul_student
  using (id = app_current_district());

-- Jobs are queued by the student path but read only by the runner ------------

drop policy if exists jobs_student_scope on jobs;
create policy jobs_student_scope on jobs to soul_student
  using (student_id = app_current_student())
  with check (student_id = app_current_student());

-- prompts, sessions and audit_log carry no policy for soul_student on purpose.
-- Row level security with no matching policy denies every row. Prompt text is
-- read by the service role inside the gateway, and nobody reads the audit log
-- from the request path.
--
-- sessions is the strictest of the three. It is read once per request to work
-- out which student is asking, which happens before the role becomes
-- soul_student, so the student role never needs it. Leaving it readable would
-- put every device's token hash one missing where clause away from a student
-- who already has a token of their own.

-- The two legacy tables hold people from the previous website. They are not
-- students, nothing in the product is about them, and no request path has any
-- business reading them. Row level security is forced with no policy, which
-- denies every row, and the grants are revoked as well so the denial does not
-- depend on the policy list staying empty.
revoke all on table legacy_feedback from soul_student;
revoke all on table legacy_users from soul_student;

revoke select, insert, update on table prompts from soul_student;
revoke select, insert, update on table sessions from soul_student;
revoke select, insert, update on table audit_log from soul_student;
grant insert on table audit_log to soul_student;

drop policy if exists audit_log_append on audit_log;
create policy audit_log_append on audit_log for insert to soul_student
  with check (true);
