/*
Judul : R.27 Versi Mikro - Seluruh baris assignment yang mengandung NIK duplikat nasional per Kabupaten
Tujuan : Menampilkan semua baris anggota penduduk dalam assignment yang memiliki NIK duplikat nasional
Kategori : Mikro (Row-Level)
Database/dialek : Fasih Data
Tanggal : 2026-10-02
*/

WITH param_wilayah AS (
    /* =================================================================================
       BLOK PENGATURAN WILAYAH (Ubah nilai di dalam tanda kutip tunggal di bawah ini)
       ================================================================================= */
    SELECT
        -- Provinsi (satu atau beberapa): ketik kodenya, pisahkan dengan tanda pipa | (contoh: '32' atau '32|33|35').
        -- Kosongkan '' jika tidak dipakai.
        '31' AS filter_provinsi,

        -- Kabupaten (satu atau beberapa): ketik kodenya, pisahkan dengan tanda pipa | (contoh: '3201' atau '3201|3202|3205').
        -- Kosongkan '' jika tidak dipakai.
        '' AS filter_kabupaten
),
     wilayah AS (
         SELECT DISTINCT
             b.level_1_full_code,
             b.level_2_full_code
         FROM tgr_fd68e454.base_table_assignment b
                  CROSS JOIN param_wilayah p
         WHERE
                 b.is_active = 1
           AND (
                 (p.filter_provinsi = '' AND p.filter_kabupaten = '')
                 OR (p.filter_provinsi <> '' AND b.level_1_full_code REGEXP p.filter_provinsi)
                 OR (p.filter_kabupaten <> '' AND b.level_2_full_code REGEXP p.filter_kabupaten)
             )
     ),
-- 1. Identifikasi NIK yang mengalami duplikasi secara nasional
     nik_duplikat_nasional AS (
         SELECT
             d.nik_dtsen AS nik,
             COUNT(1) OVER (PARTITION BY d.nik_dtsen) AS jml_dup
         FROM tgr_fd68e454.nested_dtsen d
                  INNER JOIN tgr_fd68e454.base_table_assignment b
                             ON d.assignment_id = b.assignment_id
                                 AND d.assignment_date_modified = b.date_modified
                  INNER JOIN tgr_fd68e454.root_table r
                             ON d.assignment_id = r.assignment_id
                                 AND d.assignment_date_modified = r.assignment_date_modified
         WHERE
                 b.is_active = 1
           AND b.assignment_status_id = 2
           AND b.assignment_status_alias <> 'DRAFT'
        --    AND (b.assignment_status_alias <> 'DRAFT')
           AND COALESCE(r.jenis_prelist, '') <> 'dummy'
           AND (
                     r.jenis_prelist = 'keluarga'
                 OR (r.jenis_prelist IS NULL AND r.is_new_value = 1)
             )
           AND CAST(r.ada_keluarga_value AS INT) IN (1,2)
           AND CAST(d.keberadaan_dtsen_value AS INT) IN (1)
           AND d.nik_dtsen IS NOT NULL
           AND d.nik_dtsen NOT IN ('7777', '8888', '9999')
           -- Exclude data dengan remark #DC_00 pada variabel anomali
           AND NOT EXISTS (
               SELECT 1
               FROM tgr_fd68e454.base_table_remark x
               WHERE x.assignment_id = d.assignment_id
                 AND x.index1 = d.index1
                 AND x.data_key IN ('nik_dtsen')
                 AND (lower(trim(x.comment)) LIKE '#dc%00' OR lower(trim(x.comment)) LIKE '#0')
           )
     ),
     filtered_nik AS (
         SELECT DISTINCT nik, jml_dup
         FROM nik_duplikat_nasional
         WHERE jml_dup > 1
     ),
-- 2. Cari assignment_id mana saja yang memuat NIK duplikat tersebut
     assignment_bermasalah AS (
         SELECT DISTINCT d.assignment_id
         FROM tgr_fd68e454.nested_dtsen d
                  INNER JOIN filtered_nik fn ON d.nik_dtsen = fn.nik
     ),
remark_member AS (
    SELECT assignment_id, index1,
        MAX(CASE WHEN data_key = 'nik_dtsen' THEN `comment` END) AS rm_nik_dtsen
    FROM tgr_fd68e454.base_table_remark
    WHERE data_key IN ('nik_dtsen')
    GROUP BY assignment_id, index1
),
remark_root AS (
    SELECT assignment_id,
        MAX(CASE WHEN data_key = 'nama_kk' THEN `comment` END) AS rm_nama_kk,
        MAX(CASE WHEN data_key = 'no_kk' THEN `comment` END) AS rm_no_kk
    FROM tgr_fd68e454.base_table_remark
    WHERE data_key IN ('nama_kk', 'no_kk')
    GROUP BY assignment_id
)

/* 3. HASIL AKHIR: Tampilkan SEMUA baris penduduk dari assignment yang terdeteksi mengandung NIK duplikat */
SELECT
    b.level_1_full_code,
    b.level_2_full_code,
    b.level_3_full_code,
    b.level_4_full_code,
    b.level_5_full_code,
    b.level_6_full_code,
    r.no_kk,
    r.nama_kk,
    d.nik_dtsen AS nik,
    fn.jml_dup AS jumlah_duplikasi_nasional,
    concat(
        CASE WHEN rr.rm_nama_kk IS NOT NULL THEN concat('nama_kk: ', rr.rm_nama_kk, '; ') ELSE '' END,
        CASE WHEN rr.rm_no_kk IS NOT NULL THEN concat('no_kk: ', rr.rm_no_kk, '; ') ELSE '' END,
        CASE WHEN rm.rm_nik_dtsen IS NOT NULL THEN concat('nik_dtsen: ', rm.rm_nik_dtsen, '; ') ELSE '' END
    ) AS daftar_remark,
    CONCAT('https://fasih-sm.bps.go.id/app/assignment/fd68e454-ba45-4b85-8205-f3bf777ded24/', r.assignment_id) AS link_fasih_sm
FROM tgr_fd68e454.nested_dtsen d
         INNER JOIN tgr_fd68e454.base_table_assignment b
                    ON d.assignment_id = b.assignment_id
                        AND d.assignment_date_modified = b.date_modified
         INNER JOIN wilayah w
                    ON b.level_1_full_code = w.level_1_full_code
                        AND b.level_2_full_code = w.level_2_full_code
         INNER JOIN tgr_fd68e454.root_table r
                    ON d.assignment_id = r.assignment_id
                        AND d.assignment_date_modified = r.assignment_date_modified
         INNER JOIN assignment_bermasalah ab
                    ON d.assignment_id = ab.assignment_id
         INNER JOIN filtered_nik fn
                    ON d.nik_dtsen = fn.nik
         LEFT JOIN remark_member rm
             ON rm.assignment_id = d.assignment_id
             AND rm.index1 = d.index1
         LEFT JOIN remark_root rr
             ON rr.assignment_id = r.assignment_id
WHERE
        b.is_active = 1
  AND b.assignment_status_id = 2
  AND (b.assignment_status_alias <> 'DRAFT')
  -- Exclude data dengan remark #DC_00 pada variabel anomali
  AND NOT EXISTS (
      SELECT 1
      FROM tgr_fd68e454.base_table_remark x
      WHERE x.assignment_id = d.assignment_id
        AND x.index1 = d.index1
        AND x.data_key IN ('nik_dtsen')
        AND (lower(trim(x.comment)) LIKE '#dc%00' OR lower(trim(x.comment)) LIKE '#0')
  )
ORDER BY
    w.level_1_full_code,
    w.level_2_full_code,
    nik,
    d.assignment_id;
