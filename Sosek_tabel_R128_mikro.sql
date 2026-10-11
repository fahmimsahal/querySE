/*
Judul : R.128. Pengeluaran bukan makanan tahunan = bulanan x 12 (MIKRO)
Tujuan : Daftar keluarga dengan entri pengeluaran bukan makanan tahunan yang hasil copy dari pengeluaran bulanan dikali 12
Kategori : Mikro
Database/dialek : StarRocks (dialek MySQL-compatible)
Pembuat : Fauzan Faldy Anggita
Tanggal : 2026-10-01
Sumber          : [Reviewed] 23.09.2026 - Tabel Anomali Keluarga SE - Tambahan 2.xlsx, Sheet R.128
Rule (rantab)   : b4r16c = b4r16b*12
Catatan         : b4r16b=pengeluaran_non_makan_bulanan. b4r16c=pengeluaran_non_makan_tahunan. Filter status keberadaan: CAST(r.ada_keluarga_value AS INT) IN (1,2) dan CAST(kk.keberadaan_dtsen_value AS INT) IN (1,5), dicek pada baris ART Kepala Keluarga (nested_dtsen.hubungan_value='1') sebagai status-of-record keluarga.
Update          : + filter wilayah (param_wilayah), + running_time
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
    r.nama_kk,
    r.ada_keluarga_value,
    kk.keberadaan_dtsen_value,
    r.pengeluaran_non_makan_bulanan,
    r.pengeluaran_non_makan_tahunan,
    CASE WHEN r.pengeluaran_non_makan_bulanan IS NOT NULL AND r.pengeluaran_non_makan_tahunan IS NOT NULL AND r.pengeluaran_non_makan_tahunan = r.pengeluaran_non_makan_bulanan * 12 THEN 1 ELSE 0 END AS flag_jumlah_keluarga
  FROM tgr_fd68e454.root_table r
  CROSS JOIN param_wilayah pw
  INNER JOIN tgr_fd68e454.base_table_assignment b
    ON b.assignment_id = r.assignment_id
   AND b.date_modified = r.assignment_date_modified
  INNER JOIN tgr_fd68e454.nested_dtsen kk
    ON kk.assignment_id = r.assignment_id
   AND kk.assignment_date_modified = r.assignment_date_modified
   AND kk.hubungan_value = '1'
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
  nama_kk,
  pengeluaran_non_makan_bulanan,
  pengeluaran_non_makan_tahunan,
  NOW() AS running_time
FROM base
WHERE flag_jumlah_keluarga = 1
ORDER BY level_1_code, level_2_code, level_3_code, level_4_code, level_5_code, level_6_code, assignment_id;
