/*
Judul           : Tabel Mikro Penduduk dengan NIK Mengandung 6 Digit Kembar Berturut-turut
Tujuan          : Identifikasi dan listing individu dengan NIK anomali (6 digit berulang)
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
        MAX(CASE WHEN data_key = 'nik_dtsen' THEN `comment` END) AS rm_nik_dtsen,
        MAX(CASE WHEN data_key = 'tgl_lahir' THEN `comment` END) AS rm_tgl_lahir,
        MAX(CASE WHEN data_key = 'bln_lahir_value' THEN `comment` END) AS rm_bln_lahir_value,
        MAX(CASE WHEN data_key = 'thn_lahir' THEN `comment` END) AS rm_thn_lahir
    FROM tgr_fd68e454.base_table_remark
    WHERE data_key IN ('nik_dtsen', 'tgl_lahir', 'bln_lahir_value', 'thn_lahir')
    GROUP BY assignment_id, index1
)
/* ================================================================================= */

SELECT 
    bta.level_1_full_code,
    bta.level_2_full_code,
    bta.level_3_full_code,
    bta.level_4_full_code,
    bta.level_5_full_code,
    bta.level_6_full_code,
    rt.nama_kk,
    dn.nik_dtsen,
    dn.tgl_lahir,
    dn.bln_lahir_value,
    dn.bln_lahir_label,
    dn.thn_lahir,
    concat(
        -- CASE WHEN rm.rm_no_urut_kk IS NOT NULL THEN concat('no_urut_kk: ', rm.rm_no_urut_kk, '; ') ELSE '' END,
        CASE WHEN rm.rm_nik_dtsen IS NOT NULL THEN concat('nik_dtsen: ', rm.rm_nik_dtsen, '; ') ELSE '' END,
        CASE WHEN rm.rm_tgl_lahir IS NOT NULL THEN concat('tgl_lahir: ', rm.rm_tgl_lahir, '; ') ELSE '' END,
        CASE WHEN rm.rm_bln_lahir_value IS NOT NULL THEN concat('bln_lahir_value: ', rm.rm_bln_lahir_value, '; ') ELSE '' END,
        CASE WHEN rm.rm_thn_lahir IS NOT NULL THEN concat('thn_lahir: ', rm.rm_thn_lahir, '; ') ELSE '' END
    ) AS daftar_remark,
    CONCAT('https://fasih-sm.bps.go.id/app/assignment/fd68e454-ba45-4b85-8205-f3bf777ded24/', dn.assignment_id) AS link_fasih_sm
FROM tgr_fd68e454.nested_dtsen dn
CROSS JOIN param_wilayah pw
INNER JOIN tgr_fd68e454.base_table_assignment bta 
  ON dn.assignment_id = bta.assignment_id  
  AND dn.assignment_date_modified = bta.date_modified
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
  AND COALESCE(rt.jenis_prelist, '') <> 'dummy'
  AND dn.nik_dtsen IS NOT NULL
  AND CAST(dn.nik_dtsen AS VARCHAR) NOT IN ('7777', '8888', '9999')
  AND (
        rt.jenis_prelist = 'keluarga'
        OR (rt.jenis_prelist IS NULL AND rt.is_new_value = 1)
      )
  AND CAST(rt.ada_keluarga_value AS INT) IN (1, 2)
  AND CAST(dn.keberadaan_dtsen_value AS INT) IN (1, 3, 4, 5)
  
  -- ==========================================
  -- FILTER NIK KEMBAR 6 ANGKA BERURUTAN
  -- ==========================================
  AND CAST(dn.nik_dtsen AS VARCHAR) REGEXP '000000|111111|222222|333333|444444|555555|666666|777777|888888|999999'
  
  -- Exclude penduduk lahir Oktober 2000 dan 11 November 2011
  AND CASE
        WHEN (CAST(TRIM(dn.bln_lahir_value) AS INT) = 10 AND CAST(TRIM(dn.thn_lahir) AS INT) = 2000)
          OR (CAST(TRIM(dn.tgl_lahir) AS INT) = 11 AND CAST(TRIM(dn.bln_lahir_value) AS INT) = 11 AND CAST(TRIM(dn.thn_lahir) AS INT) = 2011)
        THEN 1 ELSE 0
      END = 0
  
  -- Exclude remark nik_dtsen (variabel penduduk -> assignment_id + index1)
  AND NOT EXISTS (
      SELECT 1
      FROM tgr_fd68e454.base_table_remark x
      WHERE x.assignment_id = dn.assignment_id
        AND x.index1 = dn.index1
        AND x.data_key IN ('nik_dtsen','bln_lahir_value','tgl_lahir','thn_lahir')
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
    bta.level_5_full_code,
    bta.level_6_full_code;
