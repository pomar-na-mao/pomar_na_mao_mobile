-- Evidencia somente: definicao legada obtida por MCP em 2026-09-18.
-- NAO EXECUTAR como migration. A funcao existente deve ser preservada.
CREATE OR REPLACE FUNCTION public.sync_manual_inspection(p_payload jsonb)
 RETURNS TABLE(field_operation_id uuid, created_occurrences_count integer, updated_occurrences_count integer, removed_occurrences_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_operation_type_id uuid;
  v_field_operation_id uuid;
  v_zone_id uuid;
  v_occurrence_type_id uuid;
  v_started_at timestamptz;
  v_finished_at timestamptz;
  v_device_id text;
  v_plant jsonb;
  v_change jsonb;
  v_created_count integer := 0;
  v_updated_count integer := 0;
  v_removed_count integer := 0;
  v_existing_occurrence_id uuid;
begin
  v_zone_id := nullif(p_payload->>'zoneId', '')::uuid;
  v_occurrence_type_id := nullif(p_payload->>'occurrenceTypeId', '')::uuid;
  v_started_at := nullif(p_payload->>'startedAt', '')::timestamptz;
  v_finished_at := nullif(p_payload->>'finishedAt', '')::timestamptz;
  v_device_id := p_payload->>'deviceId';

  select id into v_operation_type_id
  from public.operation_types
  where code = 'manual_inspection';

  if v_operation_type_id is null then
    raise exception 'operation_types.code manual_inspection não encontrado';
  end if;

  insert into public.field_operations (
    operation_type_id, zone_id, target_occurrence_type_id, source, title,
    started_at, finished_at, device_id, local_id, sync_status, synced_at
  )
  values (
    v_operation_type_id, v_zone_id, v_occurrence_type_id, 'inspection', 'Inspeção manual',
    coalesce(v_started_at, now()), v_finished_at, v_device_id,
    p_payload->>'localInspectionId', 'synced', now()
  )
  returning id into v_field_operation_id;

  for v_plant in select * from jsonb_array_elements(coalesce(p_payload->'plantsChanged', '[]'::jsonb))
  loop
    insert into public.plant_operation_history (
      plant_id, field_operation_id, operation_type_id, match_source, status, notes, sync_status, synced_at
    )
    values (
      (v_plant->>'plantId')::uuid, v_field_operation_id, v_operation_type_id,
      'manual_added', 'confirmed', 'Planta alterada durante inspeção manual', 'synced', now()
    )
    on conflict on constraint uq_plant_operation do nothing;

    for v_change in select * from jsonb_array_elements(coalesce(v_plant->'changes', '[]'::jsonb))
    loop
      v_existing_occurrence_id := null;

      select po.id into v_existing_occurrence_id
      from public.plant_occurrences po
      where po.plant_id = (v_plant->>'plantId')::uuid
        and po.occurrence_type_id = (v_change->>'occurrenceTypeId')::uuid
        and po.status = 'open'
      order by po.observed_at desc
      limit 1;

      if v_change->>'changeType' = 'add_occurrence' then
        if v_existing_occurrence_id is null then
          insert into public.plant_occurrences (
            plant_id, occurrence_type_id, field_operation_id, observed_at, severity,
            status, notes, annotation_latitude, annotation_longitude, gps_accuracy_m,
            assigned_distance_meters, assignment_method, assignment_status,
            local_id, device_id, sync_status, synced_at
          )
          values (
            (v_plant->>'plantId')::uuid,
            (v_change->>'occurrenceTypeId')::uuid,
            v_field_operation_id,
            coalesce(nullif(v_change->>'changedAt', '')::timestamptz, now()),
            nullif(v_change->>'severity', ''),
            'open',
            nullif(v_change->>'notes', ''),
            nullif(v_change->>'latitude', '')::double precision,
            nullif(v_change->>'longitude', '')::double precision,
            nullif(v_change->>'gpsAccuracyM', '')::numeric,
            nullif(v_change->>'distanceToPlantMeters', '')::numeric,
            'manual',
            'confirmed',
            v_change->>'localChangeId',
            v_device_id,
            'synced',
            now()
          );
          v_created_count := v_created_count + 1;
        else
          update public.plant_occurrences po
          set
            severity = coalesce(nullif(v_change->>'severity', ''), po.severity),
            notes = coalesce(nullif(v_change->>'notes', ''), po.notes),
            field_operation_id = v_field_operation_id,
            updated_at = now(),
            sync_status = 'synced',
            synced_at = now()
          where po.id = v_existing_occurrence_id;
          v_updated_count := v_updated_count + 1;
        end if;
      elsif v_change->>'changeType' = 'remove_occurrence' then
        if v_existing_occurrence_id is not null then
          update public.plant_occurrences po
          set
            status = 'removed',
            resolved_at = coalesce(nullif(v_change->>'changedAt', '')::timestamptz, now()),
            field_operation_id = v_field_operation_id,
            notes = coalesce(nullif(v_change->>'notes', ''), po.notes),
            updated_at = now(),
            sync_status = 'synced',
            synced_at = now()
          where po.id = v_existing_occurrence_id;
          v_removed_count := v_removed_count + 1;
        end if;
      end if;
    end loop;
  end loop;

  return query select v_field_operation_id, v_created_count, v_updated_count, v_removed_count;
end;
$function$
