create function public.cn_arsip_karyawan_nonaktif(p_id text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.my_role() is distinct from 'manager' then
    raise exception 'Hanya Manager Pabrik yang dapat menjalankan tindakan ini.' using errcode = '42501';
  end if;

  update public.karyawan
  set data = data || jsonb_build_object('diarsipkan_pada', now())
  where id = p_id
    and data->'aktif' = 'false'::jsonb
    and data->>'diarsipkan_pada' is null;

  return found;
end;
$$;

revoke all on function public.cn_arsip_karyawan_nonaktif(text) from public, anon, authenticated;
grant execute on function public.cn_arsip_karyawan_nonaktif(text) to authenticated;
