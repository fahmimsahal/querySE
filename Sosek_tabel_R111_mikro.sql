/*
Judul           : Tabel R.111 Mikro. Keluarga dengan sumber penerangan utama bukan listrik, tetapi memiliki mobil
Tujuan          : Listing keluarga dengan penerangan non-listrik namun memiliki mobil
Kategori        : Mikro (Listing)
Database/dialek : StarRocks (dialek MySQL-compatible)
Tanggal         : 2026-10-01
Sumber          : [Reviewed] 23.09.2026 - Tabel Anomali Keluarga SE - Tambahan 2.xlsx, Sheet R.111
Rule (rantab)   : b4r13 = 4 & b4r17hi > 0
Catatan         : b4r13 = root_table.sumber_penerangan_value (4=Bukan listrik). b4r17hi = jumlah_mobil. Kolom jumlah_<aset> dipakai sebagai COALESCE(jumlah_<aset>_new, jumlah_<aset>) sesuai pola kueri_keluarga_pip.txt (jumlah_<aset>_new berisi nilai hasil koreksi admin, dipakai jika terisi); untuk mobil/motor ditambah fallback: jika hasil COALESCE null/0 tapi nilai_mobil/nilai_motor terisi, dianggap 1 unit. Filter status keberadaan: CAST(r.ada_keluarga_value AS INT) IN (1,2) dan CAST(kk.keberadaan_dtsen_value AS INT) IN (1,5), dicek pada baris ART Kepala Keluarga (nested_dtsen.hubungan_value='1') sebagai status-of-record keluarga.
Update          : + filter wilayah (param_wilayah), + running_time, hanya menampilkan keluarga anomali
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
-- Remark tingkat keluarga (variabel keluarga -> cukup assignment_id)
remark_root AS (
  SELECT
    assignment_id,
    MAX(CASE WHEN data_key = 'sumber_penerangan' THEN `comment` END) AS rm_sumber_penerangan,
    MAX(CASE WHEN data_key = 'jumlah_mobil' THEN `comment` END) AS rm_jumlah_mobil,
    MAX(CASE WHEN data_key = 'jumlah_mobil_new' THEN `comment` END) AS rm_jumlah_mobil_new
  FROM tgr_fd68e454.base_table_remark
  WHERE data_key IN ('sumber_penerangan', 'jumlah_mobil', 'jumlah_mobil_new')
  GROUP BY assignment_id
)
/* ================================================================================= */

SELECT DISTINCT
  b.level_1_full_code,
--   b.level_1_name,
  b.level_2_full_code,
--   b.level_2_name,
  b.level_3_full_code,
  b.level_4_full_code,
  b.level_5_full_code,
  b.level_6_full_code,
  r.assignment_id,
  r.nama_kk,
  r.sumber_penerangan_value,
  r.jumlah_mobil,
  r.jumlah_mobil_new,
  r.nilai_mobil,
  -- jumlah mobil efektif (COALESCE new -> lama, fallback 1 unit jika nilai_mobil terisi)
  CASE
    WHEN (COALESCE(r.jumlah_mobil_new, r.jumlah_mobil) IS NULL OR COALESCE(r.jumlah_mobil_new, r.jumlah_mobil) = 0)
         AND r.nilai_mobil IS NOT NULL AND r.nilai_mobil <> 0
    THEN 1
    ELSE COALESCE(r.jumlah_mobil_new, r.jumlah_mobil)
  END AS jumlah_mobil_efektif,
  concat(
    CASE WHEN rr.rm_sumber_penerangan IS NOT NULL THEN concat('sumber_penerangan: ', rr.rm_sumber_penerangan, '; ') ELSE '' END,
    CASE WHEN rr.rm_jumlah_mobil IS NOT NULL THEN concat('jumlah_mobil: ', rr.rm_jumlah_mobil, '; ') ELSE '' END,
    CASE WHEN rr.rm_jumlah_mobil_new IS NOT NULL THEN concat('jumlah_mobil_new: ', rr.rm_jumlah_mobil_new, '; ') ELSE '' END
  ) AS daftar_remark,
  CONCAT('https://fasih-sm.bps.go.id/app/assignment/fd68e454-ba45-4b85-8205-f3bf777ded24/', r.assignment_id) AS link_fasih_sm,
  NOW() AS running_time
FROM tgr_fd68e454.root_table r
CROSS JOIN param_wilayah pw
INNER JOIN tgr_fd68e454.base_table_assignment b
  ON b.assignment_id = r.assignment_id
 AND b.date_modified = r.assignment_date_modified
INNER JOIN tgr_fd68e454.nested_dtsen kk
  ON kk.assignment_id = r.assignment_id
 AND kk.assignment_date_modified = r.assignment_date_modified
 AND kk.hubungan_value = '1'
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
  -- Kondisi anomali: sumber penerangan bukan listrik
  AND CAST(r.sumber_penerangan_value AS INT) = 4
  -- Kondisi anomali: memiliki mobil (> 0 unit, dengan fallback nilai_mobil)
  AND CASE
        WHEN (COALESCE(r.jumlah_mobil_new, r.jumlah_mobil) IS NULL OR COALESCE(r.jumlah_mobil_new, r.jumlah_mobil) = 0)
             AND r.nilai_mobil IS NOT NULL AND r.nilai_mobil <> 0
        THEN 1
        ELSE COALESCE(r.jumlah_mobil_new, r.jumlah_mobil)
      END > 0
  -- Exclude data dengan remark #DC_00 / #0 pada variabel anomali
  AND NOT EXISTS (
      SELECT 1
      FROM tgr_fd68e454.base_table_remark x
      WHERE x.assignment_id = r.assignment_id
        AND x.data_key IN ('sumber_penerangan', 'jumlah_mobil', 'jumlah_mobil_new')
        AND (lower(trim(x.comment)) LIKE '#dc%00' OR lower(trim(x.comment)) LIKE '#0')
  )
  AND (
      (pw.filter_provinsi <> '' AND CAST(b.level_1_full_code AS CHAR) = pw.filter_provinsi)
      OR (pw.filter_kabupaten <> '' AND LEFT(CAST(b.level_2_full_code AS CHAR), 4) REGEXP CONCAT('^(', pw.filter_kabupaten, ')$'))
      OR (pw.filter_provinsi = '' AND pw.filter_kabupaten = '')
  )
ORDER BY
  b.level_1_full_code,
  b.level_2_full_code,
  b.level_3_full_code,
  b.level_4_full_code,
  b.level_5_full_code,
  b.level_6_full_code,
  r.assignment_id;
