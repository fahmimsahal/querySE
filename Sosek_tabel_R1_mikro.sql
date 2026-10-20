/*
Judul           : R.1 Mikro Keluarga dengan Duplikat Nomor KK
Tujuan          : Listing keluarga yang nomor KK-nya duplikat (dicek nasional, nomor dummy 7777/8888/9999 dikecualikan). Nomor KK diambil dari no_kk, jika kosong diambil dari dtsen_no_kk
Kategori        : Mikro 
Database/dialek : Fasih Data
Pembuat         : Najwa Azrai
Tanggal         : 2026-10-02
Catatan         : Hitungan duplikasi (jml_dup) dihitung secara nasional SEBELUM filter wilayah, sama seperti tabel agregat R.1.
                  Filter wilayah hanya membatasi baris yang ditampilkan.
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
),
/* ================================================================================= */
kk_base AS (
  SELECT
    b.level_1_full_code,
    b.level_2_full_code,
    b.level_3_full_code,
    b.level_4_full_code,
    b.level_5_full_code,
    b.level_6_full_code,
    r.assignment_id,
    r.no_kk,
    r.dtsen_no_kk,
    COALESCE(NULLIF(TRIM(r.no_kk), ''), NULLIF(TRIM(r.dtsen_no_kk), '')) AS no_kk_final
  FROM tgr_fd68e454.root_table r
  INNER JOIN tgr_fd68e454.base_table_assignment b
    ON r.assignment_id = b.assignment_id
    AND r.assignment_date_modified = b.date_modified
  WHERE
    b.is_active = 1
    AND b.assignment_status_id = 2
    AND b.assignment_status_alias <> 'DRAFT'
    AND COALESCE(r.jenis_prelist, '') <> 'dummy'
    AND (
          r.jenis_prelist = 'keluarga'
          OR (r.jenis_prelist IS NULL AND r.is_new_value = 1)
        )
    AND CAST(r.ada_keluarga_value AS INT) IN (1, 2)
),
fam AS (
  SELECT
    k.level_1_full_code,
    k.level_2_full_code,
    k.level_3_full_code,
    k.level_4_full_code,
    k.level_5_full_code,
    k.level_6_full_code,
    k.assignment_id,
    k.no_kk,
    k.dtsen_no_kk,
    k.no_kk_final,
    COUNT(1) OVER (PARTITION BY k.no_kk_final) AS jml_dup
  FROM kk_base k
  WHERE
    k.no_kk_final IS NOT NULL
    AND k.no_kk_final NOT IN ('7777', '8888', '9999')
)

SELECT
    f.level_1_full_code,
    f.level_2_full_code,
    f.level_3_full_code,
    f.level_4_full_code,
    f.level_5_full_code,
    f.level_6_full_code,
    f.assignment_id,
    f.no_kk,
    f.dtsen_no_kk,
    f.no_kk_final,
    f.jml_dup AS jumlah_duplikasi_kk,
    CONCAT('https://fasih-sm.bps.go.id/app/assignment/fd68e454-ba45-4b85-8205-f3bf777ded24/', f.assignment_id) AS link_fasih_sm
FROM fam f
CROSS JOIN param_wilayah pw
WHERE
  f.jml_dup > 1
  -- ==========================================
  -- LOGIKA FILTER WILAYAH
  -- ==========================================
  AND (
    (pw.filter_provinsi <> '' AND f.level_1_full_code REGEXP pw.filter_provinsi)
    OR
    (pw.filter_kabupaten <> '' AND f.level_2_full_code REGEXP pw.filter_kabupaten)
    OR
    (pw.filter_provinsi = '' AND pw.filter_kabupaten = '')
  )
ORDER BY
    f.level_1_full_code,
    f.level_2_full_code,
    f.no_kk_final,
    f.level_3_full_code,
    f.level_4_full_code,
    f.level_5_full_code,
    f.level_6_full_code;
