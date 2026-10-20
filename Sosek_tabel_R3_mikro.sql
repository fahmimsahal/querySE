/*
Judul           : R.3 Keluarga dengan 2 Digit Pertama Nomor KK Bukan Kode Provinsi (KK 16 digit)
Tujuan          : Listing individu dengan nomor KK 16 digit yang kode provinsinya (2 digit pertama) tidak valid
Kategori        : Mikro (Listing)
Database/dialek : Fasih Data
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
),
remark_root AS (
    SELECT assignment_id,
        MAX(CASE WHEN data_key = 'nama_kk' THEN `comment` END) AS rm_nama_kk,
        MAX(CASE WHEN data_key = 'no_kk' THEN `comment` END) AS rm_no_kk
    FROM tgr_fd68e454.base_table_remark
    WHERE data_key IN ('nama_kk', 'no_kk')
    GROUP BY assignment_id
)
/* ================================================================================= */

SELECT
    b.level_1_full_code,
    b.level_2_full_code,
    b.level_3_full_code,
    b.level_4_full_code,
    b.level_5_full_code,
    b.level_6_full_code,
    r.no_kk,
    r.nama_kk,
    SUBSTR(r.no_kk, 1, 2) AS kode_prov_kk,
    concat(
        CASE WHEN rr.rm_nama_kk IS NOT NULL THEN concat('nama_kk: ', rr.rm_nama_kk, '; ') ELSE '' END,
        CASE WHEN rr.rm_no_kk IS NOT NULL THEN concat('no_kk: ', rr.rm_no_kk, '; ') ELSE '' END
    ) AS daftar_remark,
    CONCAT('https://fasih-sm.bps.go.id/app/assignment/fd68e454-ba45-4b85-8205-f3bf777ded24/', r.assignment_id) AS link_fasih_sm
FROM tgr_fd68e454.root_table r
CROSS JOIN param_wilayah pw
INNER JOIN tgr_fd68e454.base_table_assignment b
  ON r.assignment_id = b.assignment_id
  AND r.assignment_date_modified = b.date_modified
LEFT JOIN remark_root rr
    ON rr.assignment_id = r.assignment_id
WHERE
  b.is_active = 1
  AND b.assignment_status_id = 2
  AND b.assignment_status_alias <> 'DRAFT'
  -- AND b.assignment_status_alias <> 'DRAFT'
  AND COALESCE(r.jenis_prelist,'') <> 'dummy'
  AND (
        r.jenis_prelist = 'keluarga'
        OR (r.jenis_prelist IS NULL AND r.is_new_value = 1)
      )
  AND CAST(r.ada_keluarga_value AS INT) IN (1, 2)
  AND CHAR_LENGTH(r.no_kk) = 16
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
  -- Exclude data dengan remark #DC_00 pada variabel anomali
  AND NOT EXISTS (
      SELECT 1
      FROM tgr_fd68e454.base_table_remark x
      WHERE x.assignment_id = r.assignment_id
        AND x.data_key IN ('no_kk')
        AND (lower(trim(x.comment)) LIKE '#dc%00' OR lower(trim(x.comment)) LIKE '#0')
  )
ORDER BY
    r.level_1_full_code,
    r.level_2_full_code,
    r.level_3_full_code,
    r.level_4_full_code,
    r.level_5_full_code,
    r.level_6_full_code;
