/*
Judul : Tabel 19. Jumlah Penduduk Menurut Umur Tunggal
Tujuan : -
Kategori : Agregat
Database/dialek : Fasih Data
Tanggal : 2026-09-13
*/

WITH param_wilayah AS (
  /* =================================================================================
     BLOK PENGATURAN WILAYAH (Ubah nilai di dalam tanda kutip tunggal di bawah ini)
     ================================================================================= */
  SELECT 
    -- 1. Jika tugasnya 1 Provinsi FULL: Ketik kode provinsinya (contoh: '32'). 
    -- Jika ingin menggunakan filter kabupaten, biarkan ini kosong ''.
    '' AS filter_provinsi, 
    
    -- 2. Jika tugasnya beberapa Kabupaten SAJA: Ketik kodenya dan pisahkan dengan tanda pipa | (contoh: '3201|3202|3205').
    -- Jika sudah mengisi filter provinsi di atas, biarkan ini kosong ''.
    '' AS filter_kabupaten
),
/* ================================================================================= */

-- Seluruh penduduk yang memenuhi syarat (tanpa filter umur & remark), dipakai untuk daftar wilayah
populasi AS (
  select
    b.level_1_full_code,
    b.level_2_full_code,
    d.assignment_id,
    d.index1,
    d.umur_ak
  from tgr_fd68e454.nested_dtsen d
  inner join tgr_fd68e454.base_table_assignment b
    on d.assignment_id = b.assignment_id
    and d.assignment_date_modified = b.date_modified
  inner join tgr_fd68e454.root_table r
    on d.assignment_id = r.assignment_id
    and d.assignment_date_modified = r.assignment_date_modified
  CROSS JOIN param_wilayah pw
  WHERE (
      (pw.filter_provinsi <> '' AND b.level_1_full_code = pw.filter_provinsi)
      OR
      (pw.filter_kabupaten <> '' AND b.level_2_full_code REGEXP pw.filter_kabupaten)
      OR
      (pw.filter_provinsi = '' AND pw.filter_kabupaten = '')
    ) AND b.is_active = 1
  -- AND b.level_1_full_code IN ('51', '34') -- Filter Provinsi
    and b.assignment_status_id = 2
    AND (b.assignment_status_alias) <> 'DRAFT'
    -- and (b.assignment_status_alias <> 'DRAFT')
    and coalesce(r.jenis_prelist, '') <> 'dummy'
    and (
        r.jenis_prelist = 'keluarga'
        or (
            r.jenis_prelist is null
            and r.is_new_value = 1
        )
    )
    and d.keberadaan_dtsen_value in (1,3,4,5) -- keberadaan ditemukan + baru
),

wilayah AS (
  select distinct level_1_full_code, level_2_full_code
  from populasi
),

kategori AS (
  select 'umur_ak <> 0-95' AS umur_tunggal, 1 AS urutan
  union all
  select 'null' AS umur_tunggal, 2 AS urutan
),

-- Hitung hanya umur kosong atau di luar 0-95, dan yang BELUM diberi remark
hitung AS (
  select
    p.level_1_full_code,
    p.level_2_full_code,
    case
      when p.umur_ak is null then 'null'
      else 'umur_ak <> 0-95'
    end as umur_tunggal,
    count(1) as jumlah_penduduk
  from populasi p
  where (p.umur_ak is null
         or cast(p.umur_ak as int) not between 0 and 95)
    AND NOT EXISTS (
        SELECT 1
        FROM tgr_fd68e454.base_table_remark x
        WHERE x.assignment_id = p.assignment_id
          AND x.index1 = p.index1
          AND x.data_key IN ('umur_ak')
          AND (lower(trim(x.comment)) LIKE '#dc%00' OR lower(trim(x.comment)) LIKE '#0' )
    )
  group by
    p.level_1_full_code,
    p.level_2_full_code,
    case
      when p.umur_ak is null then 'null'
      else 'umur_ak <> 0-95'
    end
)

select
  w.level_1_full_code,
  w.level_2_full_code,
  k.umur_tunggal,
  coalesce(h.jumlah_penduduk, 0) as jumlah_penduduk
from wilayah w
cross join kategori k
left join hitung h
  on h.level_1_full_code = w.level_1_full_code
  and h.level_2_full_code = w.level_2_full_code
  and h.umur_tunggal = k.umur_tunggal
order by
  w.level_1_full_code,
  w.level_2_full_code,
  k.urutan;
