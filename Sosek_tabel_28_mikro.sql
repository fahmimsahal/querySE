/*
Judul : Tabel 28. Jumlah Penduduk Menurut Status Hubungan KK dan Pasangan serta Jenis Kelamin (Versi Mikro - Anomali Jenis Kelamin KK & Pasangan)
Tujuan : Menampilkan baris detail keluarga dengan anomali jenis kelamin KK dan pasangan yang sama (Laki-laki dengan Laki-laki atau Perempuan dengan Perempuan)
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
    kk.assignment_id,
    kk.nama_dtsen as nama_kepala_keluarga,
    cast(kk.jk_dtsen_value as int) as jk_kepala_keluarga_value,
    ps.nama_dtsen as nama_pasangan,
    cast(ps.jk_dtsen_value as int) as jk_pasangan_value,
    case
        when cast(kk.jk_dtsen_value as int) = 1 and cast(ps.jk_dtsen_value as int) = 1 then 'KK Laki-laki & Pasangan Laki-laki'
        when cast(kk.jk_dtsen_value as int) = 2 and cast(ps.jk_dtsen_value as int) = 2 then 'KK Perempuan & Pasangan Perempuan'
        end as jenis_anomali
from tgr_fd68e454.nested_dtsen kk
         inner join tgr_fd68e454.base_table_assignment b
                    on kk.assignment_id = b.assignment_id
                        and kk.assignment_date_modified = b.date_modified
         inner join tgr_fd68e454.root_table r
                    on kk.assignment_id = r.assignment_id
                        and kk.assignment_date_modified = r.assignment_date_modified
         inner join tgr_fd68e454.nested_dtsen ps
                    on kk.assignment_id = ps.assignment_id
                        and kk.assignment_date_modified = ps.assignment_date_modified
                        and cast(ps.hubungan_value as int) = 2
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
  and cast(kk.hubungan_value as int) = 1
  and kk.keberadaan_dtsen_value in (1, 5) -- keberadaan ditemukan + baru
  and ps.keberadaan_dtsen_value in (1, 5) -- keberadaan ditemukan + baru
  -- Kondisi filter khusus anomali: (KK Laki-laki & Pasangan Laki-laki) ATAU (KK Perempuan & Pasangan Perempuan)
  and (
        (cast(kk.jk_dtsen_value as int) = 1 and cast(ps.jk_dtsen_value as int) = 1)
        or
        (cast(kk.jk_dtsen_value as int) = 2 and cast(ps.jk_dtsen_value as int) = 2)
    )
order by
    b.level_1_full_code asc,
    b.level_2_full_code asc;