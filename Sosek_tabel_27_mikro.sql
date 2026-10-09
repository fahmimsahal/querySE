/*
Judul : Tabel 27. Tabel Frekuensi Penduduk Menurut Jenis Kelamin (Versi Mikro - Jenis Kelamin Missing Value)
Tujuan : Menampilkan baris detail penduduk dengan jenis kelamin bernilai missing value / tidak valid
Kategori : Mikro (Row-Level)
Database/dialek : Fasih Data
Pembuat : Ratih
Tanggal : 2026-10-06
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
)
/* ================================================================================= */

select
    b.level_1_full_code as kode_provinsi,
    b.level_1_name as nama_provinsi,
    b.level_2_full_code as kode_kabkot,
    b.level_2_name as nama_kabkot,
    d.assignment_id,
    d.nama_dtsen,
    d.jk_dtsen_value
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
    )
  and b.is_active = 1
  and b.assignment_status_id = 2
  and (b.assignment_status_alias = 'APPROVED BY Admin Kabupaten' OR b.assignment_status_alias = 'APPROVED BY Pengawas')
  and coalesce(r.jenis_prelist, '') <> 'dummy'
  and d.keberadaan_dtsen_value in (1, 5) -- keberadaan ditemukan + baru
  -- Kondisi filter khusus jenis kelamin yang bernilai missing value (NULL atau bukan 1 dan 2)
  and (
        d.jk_dtsen_value is null
        or cast(d.jk_dtsen_value as int) not in (1, 2)
    )
order by
    b.level_1_full_code asc,
    b.level_2_full_code asc;