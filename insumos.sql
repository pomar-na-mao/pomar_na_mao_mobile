-- =========================================================
-- Insumos de Pomar (inputs) e Enum de Tipos de Insumo (input_type)
-- Sistema: Pomar na Mão
-- =========================================================

begin;

-- 1. Criação do Enum de Tipos de Insumo (input_type)
-- Mapeia e divide as categorias técnicas de calda:
-- - A: INSECTICIDE (Inseticida), ACARICIDE (Acaricida)
-- - B: FUNGICIDE (Fungicida), BACTERICIDE (Bactericida), CUPRIC (Cúprico)
-- - C: BIOLOGICAL (Biológico / Microbiológico MIP)
-- - D: FOLIAR_FERTILIZER (Adubo Foliar), MICRONUTRIENT (Micronutriente), NUTRITION (Nutrição Geral)
-- - E: ADJUVANT (Adjuvante / Espalhante), OIL (Óleo Mineral / Vegetal)
-- - Outros manejos de pomar: HERBICIDE (Herbicida), GROWTH_REGULATOR (Regulador de Crescimento)
do $$
begin
  create type public.input_type as enum (
    'INSECTICIDE',
    'ACARICIDE',
    'FUNGICIDE',
    'BACTERICIDE',
    'CUPRIC',
    'BIOLOGICAL',
    'FOLIAR_FERTILIZER',
    'MICRONUTRIENT',
    'NUTRITION',
    'ADJUVANT',
    'OIL',
    'HERBICIDE',
    'GROWTH_REGULATOR'
  );
exception
  when duplicate_object then null;
end
$$;

-- 2. Tabela de Insumos (inputs)
-- Apenas 'name' e 'type' são obrigatórios. Todos os demais dados cadastrais são opcionais (nullable).
create table if not exists public.inputs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type public.input_type not null,
  active_ingredient text,
  formulation text,
  concentration text,
  chemical_group text,
  manufacturer text,
  mapa_registration text,
  expiration_date date,
  registered_for_crop boolean default true,
  target_1 text,
  target_2 text,
  safety_interval_days integer,
  label_dose text,
  dose_unit text,
  observations text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint uq_inputs_name unique (name)
);

-- 3. Índices de Busca e Performance
create index if not exists idx_inputs_type on public.inputs (type);
create index if not exists idx_inputs_name on public.inputs (name);
create index if not exists idx_inputs_active_ingredient on public.inputs (active_ingredient);

-- 4. Trigger de Atualização Automática de updated_at
create or replace function public.handle_inputs_updated_at()
returns trigger
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_inputs_updated_at on public.inputs;
create trigger trg_inputs_updated_at
  before update on public.inputs
  for each row execute procedure public.handle_inputs_updated_at();

-- 5. Row Level Security (RLS) e Políticas de Acesso
alter table public.inputs enable row level security;

drop policy if exists "Anonymous users can read inputs" on public.inputs;
create policy "Anonymous users can read inputs" on public.inputs
  for select to anon using (true);

drop policy if exists "Authenticated users can read inputs" on public.inputs;
create policy "Authenticated users can read inputs" on public.inputs
  for select to authenticated using (true);

drop policy if exists "Authenticated users can insert inputs" on public.inputs;
create policy "Authenticated users can insert inputs" on public.inputs
  for insert to authenticated with check (true);

drop policy if exists "Authenticated users can update inputs" on public.inputs;
create policy "Authenticated users can update inputs" on public.inputs
  for update to authenticated using (true) with check (true);

drop policy if exists "Authenticated users can delete inputs" on public.inputs;
create policy "Authenticated users can delete inputs" on public.inputs
  for delete to authenticated using (true);

-- 6. Funções RPC para Listar e Adicionar Valores ao Enum input_type Dinamicamente
create or replace function public.get_input_type_enum_values()
returns table(value text)
language sql
security definer
stable
as $$
  select enumlabel::text
  from pg_enum
  where enumtypid = 'public.input_type'::regtype
  order by enumsortorder;
$$;

revoke all on function public.get_input_type_enum_values() from public;
grant execute on function public.get_input_type_enum_values() to anon, authenticated;

create or replace function public.add_input_type_enum_value(new_value text)
returns text
language plpgsql
security definer
as $$
declare
  v_formatted text;
begin
  v_formatted := upper(trim(new_value));
  if v_formatted is null or v_formatted = '' then
    raise exception 'Nome do tipo não pode ser vazio.';
  end if;

  if not exists (
    select 1
    from pg_enum
    where enumtypid = 'public.input_type'::regtype
      and enumlabel = v_formatted
  ) then
    execute format('alter type public.input_type add value %L', v_formatted);
  end if;

  return v_formatted;
end;
$$;

revoke all on function public.add_input_type_enum_value(text) from public;
grant execute on function public.add_input_type_enum_value(text) to authenticated;

-- 7. Carga Inicial de Exemplos Reais de Insumos (Opcional / Idempotente)
insert into public.inputs (
  name,
  type,
  active_ingredient,
  formulation,
  concentration,
  chemical_group,
  manufacturer,
  registered_for_crop,
  target_1,
  target_2,
  safety_interval_days,
  label_dose,
  dose_unit,
  observations
)
values
  (
    'Sivanto Prime 200 SL',
    'INSECTICIDE',
    'Flupiradifurona',
    'SL',
    '200 g/L',
    'Butenolida',
    'Bayer CropScience',
    true,
    'Psilídeo (Diaphorina citri)',
    'Pulgões e cigarrinhas',
    7,
    '50 - 100 mL/100L',
    'mL/100L',
    'Ação sistêmica acrópeta. Boa seletividade para polinizadores quando respeitadas as recomendações.'
  ),
  (
    'Sanmite',
    'ACARICIDE',
    'Piridabem',
    'WP',
    '200 g/kg',
    'Piridazinona',
    'Ihara',
    true,
    'Ácaro-da-leprose (Brevipalpus yothersi)',
    'Ácaro-da-falsa-ferrugem',
    14,
    '40 - 50 g/100L',
    'g/100L',
    'Acaricida de choque com ação de contato, ovicida e larvicida. Exige boa cobertura de calda.'
  ),
  (
    'Nativo',
    'FUNGICIDE',
    'Tebuconazol + Trifloxistrobina',
    'SC',
    '200 g/L + 100 g/L',
    'Triazol + Estrobilurina',
    'Bayer CropScience',
    true,
    'Podridão floral (Colletotrichum acutatum)',
    'Pinta preta / Sarna',
    20,
    '30 - 50 mL/100L',
    'mL/100L',
    'Ação preventiva e curativa inicial. Excelente fixação na cera cuticular.'
  ),
  (
    'Difere',
    'CUPRIC',
    'Oxicloreto de Cobre',
    'SC',
    '350 g/L de Cu metálico',
    'Inorgânico cúprico',
    'Oxiquímica',
    true,
    'Cancro Cítrico (Xanthomonas citri)',
    'Pinta preta',
    0,
    '100 - 200 mL/100L',
    'mL/100L',
    'Ação de contato protetora bactericida/fungicida. Evitar aplicações em dias de calor extremo para não causar fitoqueima.'
  ),
  (
    'Boveril WP',
    'BIOLOGICAL',
    'Beauveria bassiana (cepa IBCB 66)',
    'WP',
    '1.0 x 10^9 conídios/g',
    'Biológico / Fúngico',
    'Koppert',
    true,
    'Mosca-branca (Bemisia tabaci)',
    'Psilídeo / Tripes',
    0,
    '0.5 - 1.0 kg/ha',
    'kg/ha',
    'Incompatível com fungicidas químicos na mesma calda. Aplicar ao entardecer com UR > 60%.'
  ),
  (
    'YaraVita B+Zn+Mn',
    'MICRONUTRIENT',
    'Boro (B) + Zinco (Zn) + Manganês (Mn)',
    'SL',
    'Quelatizado / Solúvel',
    'Fertilizante Foliar',
    'Yara',
    true,
    'Pegamento floral e brotação',
    'Indução vegetativa',
    0,
    '100 - 200 mL/100L',
    'mL/100L',
    'Nutrição foliar para fluxo vegetativo e pré-florada. Boa compatibilidade de calda.'
  ),
  (
    'Iharol',
    'OIL',
    'Óleo Mineral Parafínico',
    'EC',
    '800 g/L',
    'Hidrocarboneto alifático',
    'Ihara',
    true,
    'Cochonilhas e asfixia de ovos de ácaros',
    'Melhoria de molhamento e redução de evaporação',
    0,
    '0.25% - 0.5% v/v',
    'mL/100L',
    'Atenção: Incompatível com Enxofre. Respeitar intervalo mínimo de 25 a 30 dias entre aplicações.'
  )
on conflict do nothing;

commit;
