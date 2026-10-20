/*
Judul           : Tabel Mikro NIK Penduduk dengan 2 Digit Pertama Tidak Cocok dengan Kode Provinsi di Indonesia
Tujuan          : Identifikasi dan listing individu yang NIK-nya tidak sesuai dengan kode provinsi di Indonesia
Kategori        : Mikro (Listing)
Database/dialek : Fasih Data
Tanggal         : 2026-10-02
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
remark_member AS (
    SELECT assignment_id, index1,
        MAX(CASE WHEN data_key = 'nik_dtsen' THEN `comment` END) AS rm_nik_dtsen
    FROM tgr_fd68e454.base_table_remark
    WHERE data_key IN ('nik_dtsen')
    GROUP BY assignment_id, index1
)
/* ================================================================================= */

SELECT 
    bta.level_1_full_code,
    bta.level_2_full_code,
    bta.level_3_full_code,
    bta.level_4_full_code,
    rt.nama_kk,
    dn.no_urut_kk,
    dn.nik_dtsen,
    dn.nama_dtsen,
    concat(
       CASE WHEN rm.rm_nik_dtsen IS NOT NULL THEN concat('nik_dtsen: ', rm.rm_nik_dtsen, '; ') ELSE '' END
    ) AS daftar_remark,
    CONCAT('https://fasih-sm.bps.go.id/app/assignment/fd68e454-ba45-4b85-8205-f3bf777ded24/', dn.assignment_id) AS link_fasih_sm
FROM tgr_fd68e454.nested_dtsen dn
CROSS JOIN param_wilayah pw
INNER JOIN tgr_fd68e454.base_table_assignment bta 
  ON dn.assignment_id = bta.assignment_id  
  AND dn.assignment_date_modified = bta.assignment_date_modified
INNER JOIN tgr_fd68e454.root_table rt 
  ON dn.assignment_id = rt.assignment_id 
  AND dn.assignment_date_modified = rt.assignment_date_modified
LEFT JOIN remark_member rm
    ON rm.assignment_id = dn.assignment_id
    AND rm.index1 = dn.index1
WHERE 
  bta.is_active = 1 
  AND bta.assignment_status_id = 2
  AND bta.assignment_status_alias <> 'DRAFT'
  -- AND bta.assignment_status_alias <> 'DRAFT'
  AND COALESCE(rt.jenis_prelist,'') <> 'dummy'
  AND dn.nik_dtsen IS NOT NULL
  AND CAST(dn.nik_dtsen AS VARCHAR) NOT IN ('7777', '8888', '9999')
  AND LEFT(CAST(dn.nik_dtsen AS VARCHAR), 2) NOT IN (
        '11','12','13','14','15','16','17','18','19','21',
        '31','32','33','34','35','36',
        '51','52','53',
        '61','62','63','64','65',
        '71','72','73','74','75','76',
        '81','82',
        '91','92','93','94','95','96','97'
      ) -- Filter NIK tidak sesuai kode provinsi di indonesia
  AND (
        rt.jenis_prelist = 'keluarga'
        OR (rt.jenis_prelist IS NULL AND rt.is_new_value = 1)
      )
  AND CAST(rt.ada_keluarga_value AS INT) IN (1, 2)
  AND CAST(dn.keberadaan_dtsen_value AS INT) IN (1, 3, 4, 5)
  AND NOT EXISTS (
      SELECT 1
      FROM tgr_fd68e454.base_table_remark x
      WHERE x.assignment_id = dn.assignment_id
        AND x.index1 = dn.index1
        AND x.data_key IN ('nik_dtsen')
        AND (lower(trim(x.comment)) LIKE '#dc%00'
             OR lower(trim(x.comment)) LIKE '#0')
  )
  -- ==========================================
  -- LOGIKA FILTER WILAYAH
  -- ==========================================
  AND (
    (pw.filter_provinsi <> '' AND bta.level_1_full_code = pw.filter_provinsi)
    OR
    (pw.filter_kabupaten <> '' AND bta.level_2_full_code REGEXP pw.filter_kabupaten)
    OR
    (pw.filter_provinsi = '' AND pw.filter_kabupaten = '')
  )
ORDER BY 
    bta.level_1_full_code,
    bta.level_2_full_code,
    bta.level_3_full_code,
    bta.level_4_full_code,
    dn.assignment_id,
    dn.index1;
