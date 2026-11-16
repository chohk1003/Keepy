-- =====================================================================
-- Keepy MP3 — Supabase 테이블 · 보안 규칙 · 충돌 처리
--
-- Supabase 대시보드 > SQL Editor > New query 에 이 파일 전체를 붙여 넣고 Run.
-- 여러 번 실행해도 안전하다 (있으면 건너뛰거나 다시 만든다).
-- =====================================================================

-- 1) 할 일 테이블 ------------------------------------------------------
--    한 줄 = 사용자 한 명의 할 일 하나. 할 일 내용은 앱의 Task.toJson() 그대로 data 에 담는다.
create table if not exists public.keepy_tasks (
  user_id    uuid    not null default auth.uid() references auth.users (id) on delete cascade,
  id         text    not null,                 -- 앱에서 만든 할 일 id
  data       jsonb,                            -- 제목·완료·기한·태그·순서 등 (Task.toJson)
  deleted    boolean not null default false,   -- 삭제 표시 (다른 기기에서도 지우기 위해 줄은 남김)
  updated_at bigint  not null,                 -- 기기에서 마지막으로 고친 시각(밀리초) → 충돌 시 큰 쪽이 이김
  synced_at  bigint  not null default 0,       -- 서버가 받은 시각(밀리초) → '새로 온 것만' 받는 기준
  primary key (user_id, id)
);

create index if not exists keepy_tasks_user_synced on public.keepy_tasks (user_id, synced_at);

comment on table public.keepy_tasks is 'Keepy 할 일 동기화 (MP3)';

-- 2) 행 단위 보안 (RLS): 로그인한 사용자는 자기 줄만 보고 쓴다 --------------
alter table public.keepy_tasks enable row level security;

drop policy if exists "keepy_tasks_select_own" on public.keepy_tasks;
create policy "keepy_tasks_select_own" on public.keepy_tasks
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists "keepy_tasks_insert_own" on public.keepy_tasks;
create policy "keepy_tasks_insert_own" on public.keepy_tasks
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "keepy_tasks_update_own" on public.keepy_tasks;
create policy "keepy_tasks_update_own" on public.keepy_tasks
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 실제 삭제(DELETE)는 허용하지 않는다. 앱은 deleted = true 로 표시만 한다.

grant select, insert, update on public.keepy_tasks to authenticated;

-- 3) 충돌 처리: 마지막 수정 우선 (Last-Write-Wins) -------------------------
--    더 오래된 updated_at 으로 덮어쓰려는 요청은 조용히 무시한다.
--    → 오프라인이던 기기가 늦게 올려도 더 최신 내용을 덮지 못한다.
create or replace function public.keepy_tasks_lww()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' and new.updated_at < old.updated_at then
    return null;  -- 이 줄은 바꾸지 않음
  end if;
  new.synced_at := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  return new;
end;
$$;

drop trigger if exists keepy_tasks_lww on public.keepy_tasks;
create trigger keepy_tasks_lww
  before insert or update on public.keepy_tasks
  for each row execute function public.keepy_tasks_lww();

-- 확인용 (선택): 내가 올린 할 일 보기 — Table Editor 에서 keepy_tasks 를 열어도 된다.
-- select id, data->>'title' as title, deleted, updated_at, synced_at
--   from public.keepy_tasks order by synced_at desc;
