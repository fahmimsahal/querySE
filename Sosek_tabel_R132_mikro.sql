/*
Judul           : R.132. Aset bergerak (selain emas) > 5 tetapi pengeluaran bukan makanan bulanan < Rp100.000 (MIKRO)
Tujuan          : Daftar keluarga dengan kepemilikan aset bergerak banyak namun pengeluaran bukan makanan bulanan sangat rendah
Kategori        : Mikro
Database/dialek : StarRocks (dialek MySQL-compatible)
Pembuat         : Fauzan Faldy Anggita
Tanggal         : 2026-10-01
Sumber          : [Reviewed] 23.09.2026 - Tabel Anomali Keluarga SE - Tambahan 2.xlsx, Sheet R.132
Rule (rantab)   : SUM(b4r17a,b,c,d,f,g,h) > 5 & b4r16b < 100.000
Catatan         : b4r17a..h (kecuali emas) = jumlah_tabung3kg, tabung5kg, kulkas, ac, laptop, motor, mobil. b4r16b=pengeluaran_non_makan_bulanan. Kolom jumlah_<aset> dipakai sebagai COALESCE(jumlah_<aset>_new, jumlah_<aset>) sesuai pola kueri_keluarga_pip.txt (jumlah_<aset>_new berisi nilai hasil koreksi admin, dipakai jika terisi); untuk mobil/motor ditambah fallback: jika hasil COALESCE null/0 tapi nilai_mobil/nilai_motor terisi, dianggap 1 unit. Filter status keberadaan: CAST(r.ada_keluarga_value AS INT) IN (1,2) dan CAST(kk.keberadaan_dtsen_value AS INT) IN (1,5), dicek pada baris ART Kepala Keluarga (nested_dtsen.hubungan_value='1') sebagai status-of-record keluarga.
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
    '3171' AS filter_kabupaten

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
    r.jumlah_tabung3kg,
    r.jumlah_tabung3kg_new,
    r.jumlah_tabung5kg,
    r.jumlah_tabung5kg_new,
    r.jumlah_kulkas,
    r.jumlah_kulkas_new,
    r.jumlah_ac,
    r.jumlah_ac_new,
    r.jumlah_laptop,
    r.jumlah_laptop_new,
    r.jumlah_motor,
    r.jumlah_motor_new,
    r.nilai_motor,
    r.jumlah_mobil,
    r.jumlah_mobil_new,
    r.nilai_mobil,
    r.pengeluaran_non_makan_bulanan,
    CASE WHEN (COALESCE(COALESCE(r.jumlah_tabung3kg_new, r.jumlah_tabung3kg),0) + COALESCE(COALESCE(r.jumlah_tabung5kg_new, r.jumlah_tabung5kg),0) + COALESCE(COALESCE(r.jumlah_kulkas_new, r.jumlah_kulkas),0) + COALESCE(COALESCE(r.jumlah_ac_new, r.jumlah_ac),0) + COALESCE(COALESCE(r.jumlah_laptop_new, r.jumlah_laptop),0) + COALESCE(CASE WHEN (COALESCE(r.jumlah_motor_new, r.jumlah_motor) IS NULL OR COALESCE(r.jumlah_motor_new, r.jumlah_motor) = 0) AND r.nilai_motor IS NOT NULL AND r.nilai_motor <> 0 THEN 1 ELSE COALESCE(r.jumlah_motor_new, r.jumlah_motor) END,0) + COALESCE(CASE WHEN (COALESCE(r.jumlah_mobil_new, r.jumlah_mobil) IS NULL OR COALESCE(r.jumlah_mobil_new, r.jumlah_mobil) = 0) AND r.nilai_mobil IS NOT NULL AND r.nilai_mobil <> 0 THEN 1 ELSE COALESCE(r.jumlah_mobil_new, r.jumlah_mobil) END,0)) > 5 AND r.pengeluaran_non_makan_bulanan < 100000 THEN 1 ELSE 0 END AS flag_jumlah_keluarga
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
  (COALESCE(COALESCE(jumlah_tabung3kg_new, jumlah_tabung3kg),0) + COALESCE(COALESCE(jumlah_tabung5kg_new, jumlah_tabung5kg),0) + COALESCE(COALESCE(jumlah_kulkas_new, jumlah_kulkas),0) + COALESCE(COALESCE(jumlah_ac_new, jumlah_ac),0) + COALESCE(COALESCE(jumlah_laptop_new, jumlah_laptop),0) + COALESCE(CASE WHEN (COALESCE(jumlah_motor_new, jumlah_motor) IS NULL OR COALESCE(jumlah_motor_new, jumlah_motor) = 0) AND nilai_motor IS NOT NULL AND nilai_motor <> 0 THEN 1 ELSE COALESCE(jumlah_motor_new, jumlah_motor) END,0) + COALESCE(CASE WHEN (COALESCE(jumlah_mobil_new, jumlah_mobil) IS NULL OR COALESCE(jumlah_mobil_new, jumlah_mobil) = 0) AND nilai_mobil IS NOT NULL AND nilai_mobil <> 0 THEN 1 ELSE COALESCE(jumlah_mobil_new, jumlah_mobil) END,0)) as jumlah_aset,
  pengeluaran_non_makan_bulanan,
  NOW() AS running_time
FROM base
WHERE flag_jumlah_keluarga = 1
ORDER BY level_1_code, level_2_code, level_3_code, level_4_code, level_5_code, level_6_code, assignment_id;
