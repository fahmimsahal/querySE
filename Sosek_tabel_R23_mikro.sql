/*
Judul           : R.23 Mikro Keluarga yang Tinggal di Apartemen pada Wilayah Perdesaan
Tujuan          : Listing keluarga yang tinggal di apartemen (b4r1a = 4) pada wilayah perdesaan (b1r3e = 2)
Kategori        : Mikro (Listing)
Database/dialek : Fasih Data
Pembuat         : Najwa Azrai
Tanggal         : 2026-10-02
Catatan         : jns_bangunan_value = 4 berarti apartemen (b4r1a). klas_desa = 'perdesaan' berarti perdesaan (b1r3e = 2).
                  Di sampel klas_desa berisi teks 'Perkotaan', jadi pastikan teks perdesaan persisnya 'Perdesaan'.
                  Level wilayah 3-6 diambil dari base_table_assignment (b); sesuaikan jika kolomnya ada di tabel lain.
*/

WITH param_wilayah AS (
  /* =================================================================================
     BLOK PENGATURAN WILAYAH (Ubah nilai di dalam tanda kutip tunggal di bawah ini)
     ================================================================================= */
  SELECT
    -- 1. Provinsi (satu atau beberapa): ketik kodenya, pisahkan dengan tanda pipa | (contoh: '32' atau '32|33|35').
    -- Jika ingin menggunakan filter kabupaten, biarkan ini kosong ''.
    '' AS filter_provinsi,

    -- 2. Jika tugasnya beberapa Kabupaten SAJA: Ketik kodenya dan pisahkan dengan tanda pipa | (contoh: '3201|3202|3205').
    -- Jika sudah mengisi filter provinsi di atas, biarkan ini kosong ''.
    '' AS filter_kabupaten
)
/* ================================================================================= */

SELECT
    b.level_1_full_code,
    b.level_2_full_code,
    b.level_3_full_code,
    b.level_4_full_code,
    b.level_5_full_code,
    b.level_6_full_code,
    r.assignment_id,
    r.jns_bangunan_value,
    r.jns_bangunan_label,
    r.klas_desa,
    CONCAT('https://fasih-sm.bps.go.id/app/assignment/fd68e454-ba45-4b85-8205-f3bf777ded24/', r.assignment_id) AS link_fasih_sm
FROM tgr_fd68e454.root_table r
CROSS JOIN param_wilayah pw
INNER JOIN tgr_fd68e454.base_table_assignment b
  ON r.assignment_id = b.assignment_id
  AND r.assignment_date_modified = b.date_modified
WHERE
  b.is_active = 1
  AND b.assignment_status_id = 2
  AND b.assignment_status_alias IN ('APPROVED BY Pengawas','APPROVED BY Admin Kabupaten')
  AND COALESCE(r.jenis_prelist, '') <> 'dummy'
  AND (
        r.jenis_prelist = 'keluarga'
        OR (r.jenis_prelist IS NULL AND r.is_new_value = 1)
      )
  AND CAST(r.ada_keluarga_value AS INT) = 1
  AND CAST(r.jns_bangunan_value AS INT) = 4
  AND LOWER(TRIM(r.klas_desa)) = 'perdesaan'
  -- ==========================================
  -- LOGIKA FILTER WILAYAH
  -- ==========================================
  AND (
    (pw.filter_provinsi <> '' AND b.level_1_full_code REGEXP pw.filter_provinsi)
    OR
    (pw.filter_kabupaten <> '' AND b.level_2_full_code REGEXP pw.filter_kabupaten)
    OR
    (pw.filter_provinsi = '' AND pw.filter_kabupaten = '')
  )
ORDER BY
    b.level_1_full_code,
    b.level_2_full_code,
    b.level_3_full_code,
    b.level_4_full_code,
    b.level_5_full_code,
    b.level_6_full_code;