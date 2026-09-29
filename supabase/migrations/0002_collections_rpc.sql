-- Entrega 3: adicionar à coleção somando quantidade (atômico, respeita RLS).
create or replace function add_to_collection(
  p_collection uuid,
  p_print      text,
  p_quantity   int  default 1,
  p_language   text default 'EN',
  p_condition  text default null
) returns void
language sql
security invoker
as $$
  insert into collection_items (collection_id, print_id, quantity, language, condition)
  values (p_collection, p_print, greatest(p_quantity, 1), p_language, p_condition)
  on conflict (collection_id, print_id, language)
  do update set quantity = collection_items.quantity + excluded.quantity;
$$;

create index if not exists collections_user_idx on collections (user_id);
create index if not exists collection_items_print_idx on collection_items (print_id);
