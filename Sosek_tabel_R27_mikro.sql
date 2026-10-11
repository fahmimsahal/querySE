/*
Judul : R.27 Versi Mikro - Seluruh baris assignment yang mengandung NIK duplikat nasional per Kabupaten
Tujuan : Menampilkan semua baris anggota penduduk dalam assignment yang memiliki NIK duplikat nasional
Kategori : Mikro (Row-Level)
Database/dialek : Fasih Data
Pembuat : Ratih
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
           AND (b.assignment_status_alias = 'APPROVED BY Admin Kabupaten' OR b.assignment_status_alias = 'APPROVED BY Pengawas')
           AND COALESCE(r.jenis_prelist, '') <> 'dummy'
           AND (
                     r.jenis_prelist = 'keluarga'
                 OR (r.jenis_prelist IS NULL AND r.is_new_value = 1)
             )
           AND CAST(r.ada_keluarga_value AS INT) IN (1,2)
           AND CAST(d.keberadaan_dtsen_value AS INT) IN (1, 5)
           AND d.nik_dtsen IS NOT NULL
           AND d.nik_dtsen NOT IN ('7777', '8888', '9999')
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
     )

/* 3. HASIL AKHIR: Tampilkan SEMUA baris penduduk dari assignment yang terdeteksi mengandung NIK duplikat */
SELECT
    w.level_1_full_code,
    w.level_2_full_code,
    d.assignment_id,
    d.nik_dtsen AS nik,
    fn.jml_dup AS jumlah_duplikasi_nasional
FROM tgr_fd68e454.nested_dtsen d
         INNER JOIN tgr_fd68e454.base_table_assignment b
                    ON d.assignment_id = b.assignment_id
                        AND d.assignment_date_modified = b.date_modified
         INNER JOIN wilayah w
                    ON b.level_1_full_code = w.level_1_full_code
                        AND b.level_2_full_code = w.level_2_full_code
         INNER JOIN assignment_bermasalah ab
                    ON d.assignment_id = ab.assignment_id
         INNER JOIN filtered_nik fn
                    ON d.nik_dtsen = fn.nik
WHERE
        b.is_active = 1
  AND b.assignment_status_id = 2
  AND (b.assignment_status_alias = 'APPROVED BY Admin Kabupaten' OR b.assignment_status_alias = 'APPROVED BY Pengawas')
ORDER BY
    w.level_1_full_code,
    w.level_2_full_code,
    nik,
    d.assignment_id;