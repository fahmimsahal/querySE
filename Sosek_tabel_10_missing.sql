/*
Judul : Tabel 10. Jumlah penduduk menurut keberadaan anggota keluarga (Versi Mikro - Missing Value)
Tujuan : Menampilkan baris detail penduduk yang memiliki status keberadaan anggota keluarga (keberadaan_dtsen_value) bernilai NULL / Missing Value
Kategori : Mikro (Row-Level)
Database/dialek : Fasih Data
Pembuat : Ratih
Tanggal : 2026-10-04
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

SELECT
    a.level_1_full_code,
    a.level_2_full_code,
    a.level_3_full_code,
    a.level_4_full_code,
    a.level_5_full_code,
    a.level_6_full_code,
    a.assignment_id,
    c.nik_dtsen,
    'Missing Value' AS keberadaan_dtsen_des,
    b.banr,
    b.no_banr
FROM tgr_fd68e454.base_table_assignment a
         JOIN tgr_fd68e454.root_table b
              ON a.assignment_id = b.assignment_id
         JOIN tgr_fd68e454.nested_dtsen c
              ON a.assignment_id = c.assignment_id
                  AND a.assignment_date_modified = c.assignment_date_modified
         CROSS JOIN param_wilayah pw
WHERE (
        (pw.filter_provinsi <> '' AND a.level_1_full_code = pw.filter_provinsi)
        OR
        (pw.filter_kabupaten <> '' AND a.level_2_full_code REGEXP pw.filter_kabupaten)
        OR
        (pw.filter_provinsi = '' AND pw.filter_kabupaten = '')
    )
  AND a.is_active = 1
  AND COALESCE(b.jenis_prelist, '') <> 'dummy'
  AND a.assignment_status_id = 2
  AND (a.assignment_status_alias = 'APPROVED BY Admin Kabupaten' OR a.assignment_status_alias = 'APPROVED BY Pengawas')
  AND (
            b.jenis_prelist = 'keluarga'
        OR (
                    b.jenis_prelist IS NULL
                    AND b.is_new_value = 1
                )
    )
  AND c.keberadaan_dtsen_value IS NULL -- Filter khusus data yang missing / NULL
ORDER BY
    a.level_1_full_code,
    a.level_2_full_code,
    a.level_3_full_code,
    a.level_4_full_code,
    a.level_5_full_code,
    a.level_6_full_code;