/*
Judul : Tabel 13. Penduduk Menurut Bulan Lahir (Versi Mikro - Di Luar Rentang)
Tujuan : Menampilkan baris detail penduduk dengan nilai bulan lahir di luar rentang yang valid
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
    d.bln_lahir_value
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
  AND b.is_active = 1
  and b.assignment_status_id = 2
  and (b.assignment_status_alias = 'APPROVED BY Admin Kabupaten' OR b.assignment_status_alias = 'APPROVED BY Pengawas')
  and coalesce(r.jenis_prelist, '') <> 'dummy'
  and (
            r.jenis_prelist = 'keluarga'
        or (
                    r.jenis_prelist is null
                    and cast(r.is_new_value as int) = 1
                )
    )
  and d.keberadaan_dtsen_value in (1, 5) -- keberadaan ditemukan + baru
  -- Kondisi filter untuk bulan lahir di luar rentang valid (1-12 dan 98) atau bernilai kosong/null
  and (
        cast(d.bln_lahir_value as int) not in (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 98)
        or d.bln_lahir_value is null
    )
order by
    b.level_1_full_code asc,
    b.level_2_full_code asc,
    d.assignment_id;