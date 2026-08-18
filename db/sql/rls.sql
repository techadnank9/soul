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
    'districts','schools','students','entries','kept_lines','tags',
    'entry_embeddings','decisions','outcomes','pattern_candidates',
    'confirmed_patterns','pattern_rejections','safety_flags','generations',
    'prompts','jobs','audit_log'
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
    'entries','kept_lines','tags','entry_embeddings','decisions','outcomes',
    'pattern_candidates','confirmed_patterns','pattern_rejections',
    'safety_flags','generations'
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

-- prompts and audit_log carry no policy for soul_student on purpose.
-- Row level security with no matching policy denies every row. Prompt text is
-- read by the service role inside the gateway, and nobody reads the audit log
-- from the request path.

revoke select, insert, update on table prompts from soul_student;
revoke select, insert, update on table audit_log from soul_student;
grant insert on table audit_log to soul_student;

drop policy if exists audit_log_append on audit_log;
create policy audit_log_append on audit_log for insert to soul_student
  with check (true);
