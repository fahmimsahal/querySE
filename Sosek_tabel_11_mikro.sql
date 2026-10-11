/*
Judul           : Tabel 11. Jumlah Penduduk yang mempunyai No KK tidak 16 digit (MIKRO)
Tujuan          : Daftar penduduk dengan No KK tidak 16 digit
Kategori        : Mikro
Database/dialek : StarRocks (dialek MySQL-compatible)
Pembuat         : Hasabi
Tanggal         : 2026-10-02
*/

WITH param_wilayah AS (
    SELECT
        '' AS filter_provinsi,
        '' AS filter_kabupaten
),
base AS (
    SELECT
        b.level_1_code,
        b.level_1_name,
        b.level_2_code,
        b.level_2_name,
        b.level_3_code,
        b.level_3_name,
        b.level_4_code,
        b.level_4_name,
        b.level_5_code,
        b.level_5_name,
        b.level_6_code,
        b.level_6_name,
        b.level_1_full_code,
        b.level_2_full_code,
        r.assignment_id,
        r.no_kk,
        d.no_urut_kk,
        d.nik_dtsen
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
        AND (b.assignment_status_alias = 'APPROVED BY Admin Kabupaten' OR b.assignment_status_alias = 'APPROVED BY Pengawas')
        AND COALESCE(r.jenis_prelist, '') <> 'dummy'
        AND (
            r.jenis_prelist = 'keluarga'
            OR (r.jenis_prelist IS NULL AND r.is_new_value = 1)
        )
        AND CAST(r.ada_keluarga_value AS INT) IN (1,2)
        AND CAST(d.keberadaan_dtsen_value AS INT) IN (1,5)
        AND (r.no_kk IS NULL OR length(CAST(r.no_kk AS VARCHAR)) <> 16)
        AND (
            (pw.filter_provinsi <> '' AND CAST(b.level_1_full_code AS CHAR) = pw.filter_provinsi)
            OR (pw.filter_kabupaten <> '' AND LEFT(CAST(b.level_2_full_code AS CHAR), 4) REGEXP CONCAT('^(', pw.filter_kabupaten, ')$'))
            OR (pw.filter_provinsi = '' AND pw.filter_kabupaten = '')
        )
)
SELECT
    level_1_code,
    level_1_name,
    level_2_code,
    level_2_name,
    level_3_code,
    level_3_name,
    level_4_code,
    level_4_name,
    level_5_code,
    level_5_name,
    level_6_code,
    level_6_name,
    assignment_id,
    no_kk,
    no_urut_kk,
    nik_dtsen,
    NOW() AS running_time
FROM base
ORDER BY level_1_code, level_2_code, level_3_code, level_4_code, level_5_code, level_6_code, assignment_id;
