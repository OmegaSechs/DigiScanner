-- Entrega 1: esquema base. Carta (código) separada de impressão (arte/versão).

create table sets (
  code text primary key,            -- ex: BT1, ST1, EX2
  name text not null
);

create table cards (
  code         text primary key,    -- ex: BT1-010 (regras e texto são iguais em todas as versões)
  name         text not null,
  type         text not null,       -- Digimon | Option | Tamer | Digi-Egg
  color        text,
  color2       text,
  level        smallint,
  play_cost    smallint,
  dp           integer,
  form         text,
  attribute    text,
  digi_types   text[] not null default '{}',
  stage        text,
  main_effect  text,
  source_effect text,
  alt_effect   text,
  evolutions   jsonb not null default '[]',  -- [{cost, color, level}]
  max_copies   smallint not null default 4,  -- exceções (50, 1, 0) entram via tabela de regras
  banned       boolean not null default false,
  raw          jsonb,
  updated_at   timestamptz not null default now()
);
create index cards_name_idx  on cards using gin (to_tsvector('simple', name));
create index cards_filter_idx on cards (type, color, level);

create table prints (
  id          text primary key,      -- BT1-010 ou BT1-010_P1, _P2...
  card_code   text not null references cards(code) on delete cascade,
  set_code    text references sets(code),
  rarity      text,
  artist      text,
  image_url   text,
  is_alternate boolean not null default false
);
create index prints_card_idx on prints (card_code);

-- Dados do usuário
create table collections (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name       text not null,
  created_at timestamptz not null default now()
);

create table collection_items (
  collection_id uuid not null references collections(id) on delete cascade,
  print_id      text not null references prints(id),
  quantity      integer not null default 1 check (quantity > 0),
  condition     text,
  language      text default 'EN',
  primary key (collection_id, print_id, language)
);

create table decks (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name       text not null,
  notes      text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table deck_cards (
  deck_id   uuid not null references decks(id) on delete cascade,
  card_code text not null references cards(code),
  quantity  integer not null check (quantity > 0),
  primary key (deck_id, card_code)
);

-- Segurança: catálogo público para leitura; dados do usuário só do dono.
alter table sets    enable row level security;
alter table cards   enable row level security;
alter table prints  enable row level security;
create policy "catalog read sets"   on sets   for select using (true);
create policy "catalog read cards"  on cards  for select using (true);
create policy "catalog read prints" on prints for select using (true);

alter table collections      enable row level security;
alter table collection_items enable row level security;
alter table decks            enable row level security;
alter table deck_cards       enable row level security;

create policy "own collections" on collections for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own collection items" on collection_items for all
  using (exists (select 1 from collections c where c.id = collection_id and c.user_id = auth.uid()))
  with check (exists (select 1 from collections c where c.id = collection_id and c.user_id = auth.uid()));
create policy "own decks" on decks for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own deck cards" on deck_cards for all
  using (exists (select 1 from decks d where d.id = deck_id and d.user_id = auth.uid()))
  with check (exists (select 1 from decks d where d.id = deck_id and d.user_id = auth.uid()));
