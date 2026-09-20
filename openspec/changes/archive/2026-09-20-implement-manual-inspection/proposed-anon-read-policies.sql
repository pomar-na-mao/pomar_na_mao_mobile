-- PROPOSTA PARA REVISAO: nao aplicada ao banco.
-- Permite leitura sem login de todo o catalogo e das ocorrencias.
-- As tabelas ja possuem RLS habilitado e GRANT SELECT para anon.
begin;

create policy "Anonymous users can read occurrence_types"
on public.occurrence_types
for select to anon
using (true);

create policy "Anonymous users can read plant_occurrences"
on public.plant_occurrences
for select to anon
using (true);

commit;
