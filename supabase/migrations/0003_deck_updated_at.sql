-- Entrega 4/5 (correções): mantém decks.updated_at em dia.

create or replace function set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists decks_set_updated_at on decks;
create trigger decks_set_updated_at
  before update on decks
  for each row execute function set_updated_at();

-- Mexer nas cartas do deck também "toca" o deck (respeita RLS: só o dono).
create or replace function touch_deck_from_cards() returns trigger
language plpgsql as $$
begin
  update decks set updated_at = now()
   where id = coalesce(new.deck_id, old.deck_id);
  return null;
end $$;

drop trigger if exists deck_cards_touch on deck_cards;
create trigger deck_cards_touch
  after insert or update or delete on deck_cards
  for each row execute function touch_deck_from_cards();
