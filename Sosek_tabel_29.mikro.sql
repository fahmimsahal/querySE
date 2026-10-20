/*
Judul : Tabel 29. Frekuensi Profesi Pekerjaan Utama (Versi Mikro - Detail Penduduk per Kode Profesi)
Tujuan : Menampilkan baris detail penduduk dengan kode profesi pekerjaan utama tertentu (141, 179, 040, 178, 020, 028, 177, 046) untuk keperluan penelusuran/verifikasi
Kategori : Mikro
Database/dialek : Fasih Data
Tanggal : 2026-10-15
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
    b.level_1_full_code,
    b.level_1_name,
    b.level_2_full_code,
    b.level_2_name,
    v.assignment_id,
    v.index1,
    dn.nama_dtsen,
    dn.umur_ak,
    dn.keberadaan_dtsen_value,
    dn.keberadaan_dtsen_label,
    CAST(CAST(v.profesi_value AS INT) AS VARCHAR) AS kode_profesi,
    v.profesi_label,
    CONCAT('https://fasih-sm.bps.go.id/app/assignment/fd68e454-ba45-4b85-8205-f3bf777ded24/', v.assignment_id) AS link_fasih_sm,
    NOW() AS running_time
FROM tgr_fd68e454.nested_dtsen_var v
         INNER JOIN tgr_fd68e454.nested_dtsen dn
                    ON v.assignment_id = dn.assignment_id
                        AND v.assignment_date_modified = dn.assignment_date_modified
                        AND v.index1 = dn.index1
         INNER JOIN tgr_fd68e454.base_table_assignment b
                    ON v.assignment_id = b.assignment_id
                        AND v.assignment_date_modified = b.date_modified
         INNER JOIN tgr_fd68e454.root_table r
                    ON v.assignment_id = r.assignment_id
                        AND v.assignment_date_modified = r.assignment_date_modified
         CROSS JOIN param_wilayah pw
WHERE (
        (pw.filter_provinsi <> '' AND b.level_1_full_code = pw.filter_provinsi)
        OR
        (pw.filter_kabupaten <> '' AND b.level_2_full_code REGEXP pw.filter_kabupaten)
        OR
        (pw.filter_provinsi = '' AND pw.filter_kabupaten = '')
    )
  AND b.is_active = 1
  AND b.assignment_status_id = 2
  AND b.assignment_status_alias <> 'DRAFT'
  AND COALESCE(r.jenis_prelist, '') <> 'dummy'
  AND dn.keberadaan_dtsen_value IN (1,3,4,5) 
  AND dn.umur_ak>10
  AND v.profesi_value IN ('181','180','040','178','020','028','177','046','064')
  AND NOT EXISTS (
        SELECT 1
        FROM tgr_fd68e454.base_table_remark x
        WHERE x.assignment_id = v.assignment_id
          AND x.index1 = v.index1
          AND x.data_key IN ('profesi_value')
          AND (LOWER(TRIM(x.comment)) LIKE '#dc%00' OR LOWER(TRIM(x.comment)) LIKE '#0'  )
    )
ORDER BY
    b.level_1_full_code,
    b.level_2_full_code,
    CAST(v.profesi_value AS INT),
    v.assignment_id;
