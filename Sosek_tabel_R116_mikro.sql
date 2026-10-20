/*
Judul           : Tabel R.116. Keluarga dengan Jumlah meteran listrik 1 dengan daya 450 watt, tetapi memiliki AC >2 unit (MIKRO)
Tujuan          : Daftar keluarga dengan 1 meteran berdaya 450 watt namun memiliki AC lebih dari 2 unit
Kategori        : Mikro
Database/dialek : StarRocks (dialek MySQL-compatible)
Tanggal         : 2026-10-01
Sumber          : [Reviewed] 23.09.2026 - Tabel Anomali Keluarga SE - Tambahan 2.xlsx, Sheet R.116
Rule (rantab)   : jml_meteran=1 & b4r14.b=1 & b4r17.d>2
Catatan         : b4r14.b=nested_meteran.daya_terpasang_value (1=450 watt). b4r17.d=jumlah_ac. Kolom jumlah_<aset> dipakai sebagai COALESCE(jumlah_<aset>_new, jumlah_<aset>) sesuai pola kueri_keluarga_pip.txt (jumlah_<aset>_new berisi nilai hasil koreksi admin, dipakai jika terisi). Filter status keberadaan: CAST(r.ada_keluarga_value AS INT) IN (1,2) dan CAST(kk.keberadaan_dtsen_value AS INT) IN (1,5), dicek pada baris ART Kepala Keluarga (nested_dtsen.hubungan_value='1') sebagai status-of-record keluarga.
Update          : + filter wilayah (param_wilayah), + running_time, hanya menampilkan keluarga anomali, + filter jml_meteran = 1, + daftar_remark
*/

WITH
param_wilayah AS (
  /* =================================================================================
     BLOK PENGATURAN WILAYAH (Ubah nilai di dalam tanda kutip tunggal di bawah ini)
     ================================================================================= */
  SELECT
    -- 1. Jika tugasnya 1 Provinsi FULL: Ketik kode provinsinya (contoh: '32').
    -- Jika ingin menggunakan filter kabupaten (opsi 2), biarkan ini kosong ''
    '' AS filter_provinsi,

    -- 2. Jika tugasnya beberapa Kabupaten SAJA: Ketik kodenya dan pisahkan dengan tanda pipa | (contoh: '3201|3202|3205')
    -- Jika sudah mengisi filter provinsi di atas, biarkan ini kosong ''.
    '' AS filter_kabupaten

    -- Jika keduanya kosong ('') -> seluruh Indonesia.
),
-- Remark tingkat meteran (variabel meteran -> assignment_id + index1)
remark_meteran AS (
  SELECT
    assignment_id,
    index1,
    MAX(CASE WHEN data_key = 'daya_terpasang_value' THEN `comment` END) AS rm_daya_terpasang
  FROM tgr_fd68e454.base_table_remark
  WHERE data_key IN ('daya_terpasang_value')
  GROUP BY assignment_id, index1
),
-- Remark tingkat keluarga (variabel keluarga -> cukup assignment_id)
remark_root AS (
  SELECT
    assignment_id,
    MAX(CASE WHEN data_key = 'jumlah_ac' THEN `comment` END) AS rm_jumlah_ac,
    MAX(CASE WHEN data_key = 'jumlah_ac_new' THEN `comment` END) AS rm_jumlah_ac_new,
    MAX(CASE WHEN data_key = 'jml_meteran' THEN `comment` END) AS rm_jml_meteran
  FROM tgr_fd68e454.base_table_remark
  WHERE data_key IN ('jumlah_ac', 'jumlah_ac_new', 'jml_meteran')
  GROUP BY assignment_id
),
-- Hanya keluarga anomali: 1 meteran, daya 450 watt, TAPI memiliki AC > 2 unit
base AS (
  SELECT
    b.level_1_full_code,
    b.level_2_full_code,
    b.level_3_full_code,
    b.level_4_full_code,
    b.level_5_full_code,
    b.level_6_full_code,
    r.assignment_id,
    r.no_kk,
    r.nama_kk,
    r.jml_meteran,
    m.daya_terpasang_value,
    m.daya_terpasang_label,
    r.jumlah_ac,
    r.jumlah_ac_new,
    m.no_meteran,
    concat(
      CASE WHEN rm.rm_daya_terpasang IS NOT NULL THEN concat('daya_terpasang_value: ', rm.rm_daya_terpasang, '; ') ELSE '' END,
      CASE WHEN rr.rm_jumlah_ac IS NOT NULL THEN concat('jumlah_ac: ', rr.rm_jumlah_ac, '; ') ELSE '' END,
      CASE WHEN rr.rm_jumlah_ac_new IS NOT NULL THEN concat('jumlah_ac_new: ', rr.rm_jumlah_ac_new, '; ') ELSE '' END,
      CASE WHEN rr.rm_jml_meteran IS NOT NULL THEN concat('jml_meteran: ', rr.rm_jml_meteran, '; ') ELSE '' END
    ) AS daftar_remark
  FROM tgr_fd68e454.root_table r
  CROSS JOIN param_wilayah pw
  INNER JOIN tgr_fd68e454.base_table_assignment b
    ON b.assignment_id = r.assignment_id
   AND b.date_modified = r.assignment_date_modified
  INNER JOIN tgr_fd68e454.nested_dtsen kk
    ON kk.assignment_id = r.assignment_id
   AND kk.assignment_date_modified = r.assignment_date_modified
   AND kk.hubungan_value = '1'
  INNER JOIN tgr_fd68e454.nested_meteran m
    ON m.assignment_id = r.assignment_id
   AND m.assignment_date_modified = r.assignment_date_modified
  LEFT JOIN remark_meteran rm
    ON rm.assignment_id = m.assignment_id
   AND rm.index1 = m.index1
  LEFT JOIN remark_root rr
    ON rr.assignment_id = r.assignment_id
  WHERE
    b.is_active = 1
    AND b.assignment_status_id = 2
    AND b.assignment_status_alias <> 'DRAFT'
    AND COALESCE(r.jenis_prelist, '') <> 'dummy'
    AND (
        r.jenis_prelist = 'keluarga'
        OR (r.jenis_prelist IS NULL AND r.is_new_value = 1)
    )
    AND CAST(r.ada_keluarga_value AS INT) IN (1,2)
    AND CAST(kk.keberadaan_dtsen_value AS INT) IN (1,5)
    -- Kondisi anomali: hanya 1 meteran, daya 450 watt, dan jumlah AC > 2 unit
    AND CAST(r.jml_meteran AS INT) = 1
    AND CAST(m.daya_terpasang_value AS INT) = 1
    AND COALESCE(r.jumlah_ac_new, r.jumlah_ac) > 2
    -- Exclude data dengan remark #DC_00 / #0 pada variabel anomali
    -- daya_terpasang_value = variabel meteran (assignment_id + index1), jumlah_ac & jml_meteran = variabel keluarga (assignment_id)
    AND NOT EXISTS (
        SELECT 1
        FROM tgr_fd68e454.base_table_remark x
        WHERE x.assignment_id = r.assignment_id
          AND (
                (x.index1 = m.index1 AND x.data_key IN ('daya_terpasang_value'))
                OR x.data_key IN ('jumlah_ac', 'jumlah_ac_new', 'jml_meteran')
              )
          AND (lower(trim(x.comment)) LIKE '#dc%00' OR lower(trim(x.comment)) LIKE '#0')
    )
    AND (
        (pw.filter_provinsi <> '' AND CAST(b.level_1_full_code AS CHAR) = pw.filter_provinsi)
        OR (pw.filter_kabupaten <> '' AND LEFT(CAST(b.level_2_full_code AS CHAR), 4) REGEXP CONCAT('^(', pw.filter_kabupaten, ')$'))
        OR (pw.filter_provinsi = '' AND pw.filter_kabupaten = '')
    )
)
SELECT
  level_1_full_code,
  level_2_full_code,
  level_3_full_code,
  level_4_full_code,
  level_5_full_code,
  level_6_full_code,
  assignment_id,
  no_kk,
  nama_kk,
  jml_meteran,
  no_meteran,
  daya_terpasang_value,
  daya_terpasang_label,
  coalesce(jumlah_ac_new, jumlah_ac) AS jumlah_ac,
  daftar_remark,
  NOW() AS running_time,
  CONCAT('https://fasih-sm.bps.go.id/app/assignment/fd68e454-ba45-4b85-8205-f3bf777ded24/', assignment_id) AS link_fasih_sm
FROM base
ORDER BY level_1_full_code, level_2_full_code, level_3_full_code,
         level_4_full_code, level_5_full_code, level_6_full_code, assignment_id;
