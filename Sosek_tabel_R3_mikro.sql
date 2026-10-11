/*
Judul           : R.3 Mikro Penduduk dengan 2 Digit Pertama Nomor KK Bukan Kode Provinsi (KK 16 digit)
Tujuan          : Listing individu dengan nomor KK 16 digit yang kode provinsinya (2 digit pertama) tidak valid
Kategori        : Mikro (Listing)
Database/dialek : Fasih Data
Pembuat         : Najwa Azrai
Tanggal         : 2026-10-02
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
    d.level_1_full_code,
    d.level_2_full_code,
    d.level_3_full_code,
    d.level_4_full_code,
    d.level_5_full_code,
    d.level_6_full_code,
    d.assignment_id,
    d.no_urut_kk,
    d.nik_dtsen,
    r.no_kk,
    SUBSTR(r.no_kk, 1, 2) AS kode_prov_kk,
    CONCAT('https://fasih-sm.bps.go.id/app/assignment/fd68e454-ba45-4b85-8205-f3bf777ded24/', d.assignment_id) AS link_fasih_sm
FROM tgr_fd68e454.nested_dtsen d
CROSS JOIN param_wilayah pw
INNER JOIN tgr_fd68e454.base_table_assignment b
  ON d.assignment_id = b.assignment_id
  AND d.assignment_date_modified = b.date_modified
INNER JOIN tgr_fd68e454.root_table r
  ON d.assignment_id = r.assignment_id
  AND d.assignment_date_modified = r.assignment_date_modified
WHERE
  b.is_active = 1
  AND b.assignment_status_id = 2
  AND b.assignment_status_alias IN ('APPROVED BY Pengawas','APPROVED BY Admin Kabupaten')
  AND COALESCE(r.jenis_prelist,'') <> 'dummy'
  AND (
        r.jenis_prelist = 'keluarga'
        OR (r.jenis_prelist IS NULL AND r.is_new_value = 1)
      )
  AND CAST(r.ada_keluarga_value AS INT) IN (1, 2)
  AND CAST(d.keberadaan_dtsen_value AS INT) IN (1, 5)
  AND LENGTH(r.no_kk) = 16
  AND SUBSTR(r.no_kk, 1, 2) NOT IN (
        '11','12','13','14','15','16','17','18','19',
        '21',
        '31','32','33','34','35','36',
        '51','52','53',
        '61','62','63','64','65',
        '71','72','73','74','75','76',
        '81','82',
        '91','92','93','94','95','96'
      )
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
    d.level_1_full_code,
    d.level_2_full_code,
    d.level_3_full_code,
    d.level_4_full_code,
    d.level_5_full_code,
    d.level_6_full_code;