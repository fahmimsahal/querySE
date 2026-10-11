/*
Judul : Tabel R.133. Kombinasi kepemilikan 2+ aset dengan kode 2 (sisa bug prelist sebelum 8 Juli 2026) (MIKRO)
Tujuan : Daftar keluarga dengan sisa kode prelist lama (nilai=2) pada kolom jumlah aset
Kategori : Mikro
Database/dialek : StarRocks (dialek MySQL-compatible)
Pembuat : Fauzan Faldy Anggita
Tanggal : 2026-10-01
Sumber          : [Reviewed] 23.09.2026 - Tabel Anomali Keluarga SE - Tambahan 2.xlsx, Sheet R.133
Rule (rantab)   : (b4r17a=2|b=2|c=2|d=2|e=2|f=2|gi=2|hi=2) & tgl_submit < 08/07/2026
Catatan         : b4r17a..hi = jumlah_tabung3kg, tabung5kg, kulkas, ac, emas, laptop, motor, mobil. tgl_submit diproksikan dari base_table_assignment.date_modified. Kolom jumlah_<aset> dipakai sebagai COALESCE(jumlah_<aset>_new, jumlah_<aset>) sesuai pola kueri_keluarga_pip.txt (jumlah_<aset>_new berisi nilai hasil koreksi admin, dipakai jika terisi); untuk mobil/motor ditambah fallback: jika hasil COALESCE null/0 tapi nilai_mobil/nilai_motor terisi, dianggap 1 unit. Memakai nilai effective (COALESCE _new) berarti kasus yang kode-2-nya sudah dikoreksi admin TIDAK lagi muncul di sini - sesuai tujuan tabel ini untuk memantau sisa kasus yang BELUM dikoreksi. Filter status keberadaan: CAST(r.ada_keluarga_value AS INT) IN (1,2) dan CAST(kk.keberadaan_dtsen_value AS INT) IN (1,5), dicek pada baris ART Kepala Keluarga (nested_dtsen.hubungan_value='1') sebagai status-of-record keluarga.
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
    '3201' AS filter_kabupaten

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
    r.jumlah_emas,
    r.jumlah_emas_new,
    r.jumlah_laptop,
    r.jumlah_laptop_new,
    r.jumlah_motor,
    r.jumlah_motor_new,
    r.nilai_motor,
    r.jumlah_mobil,
    r.jumlah_mobil_new,
    r.nilai_mobil,
    b.date_modified,
    CASE WHEN (COALESCE(r.jumlah_tabung3kg_new, r.jumlah_tabung3kg) = 2 OR COALESCE(r.jumlah_tabung5kg_new, r.jumlah_tabung5kg) = 2 OR COALESCE(r.jumlah_kulkas_new, r.jumlah_kulkas) = 2 OR COALESCE(r.jumlah_ac_new, r.jumlah_ac) = 2 OR COALESCE(r.jumlah_emas_new, r.jumlah_emas) = 2 OR COALESCE(r.jumlah_laptop_new, r.jumlah_laptop) = 2 OR CASE WHEN (COALESCE(r.jumlah_motor_new, r.jumlah_motor) IS NULL OR COALESCE(r.jumlah_motor_new, r.jumlah_motor) = 0) AND r.nilai_motor IS NOT NULL AND r.nilai_motor <> 0 THEN 1 ELSE COALESCE(r.jumlah_motor_new, r.jumlah_motor) END = 2 OR CASE WHEN (COALESCE(r.jumlah_mobil_new, r.jumlah_mobil) IS NULL OR COALESCE(r.jumlah_mobil_new, r.jumlah_mobil) = 0) AND r.nilai_mobil IS NOT NULL AND r.nilai_mobil <> 0 THEN 1 ELSE COALESCE(r.jumlah_mobil_new, r.jumlah_mobil) END = 2) AND CAST(b.date_modified AS DATE) < '2026-07-08' THEN 1 ELSE 0 END AS flag_jumlah_keluarga
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
  -- level_1_name,
  level_2_code,
  -- level_2_name,
  level_3_code,
  -- level_3_name,
  level_4_code,
  -- level_4_name,
  level_5_code,
  level_6_code,
  -- level_5_name,
  -- level_6_code,
  -- level_6_name,
  assignment_id,
  no_kk,
  nama_kk,
  jumlah_tabung3kg,
  jumlah_tabung3kg_new,
  jumlah_tabung5kg,
  jumlah_tabung5kg_new,
  jumlah_kulkas,
  jumlah_kulkas_new,
  jumlah_ac,
  jumlah_ac_new,
  jumlah_emas,
  jumlah_emas_new,
  jumlah_laptop,
  jumlah_laptop_new,
  jumlah_motor,
  jumlah_motor_new,
  nilai_motor,
  jumlah_mobil,
  jumlah_mobil_new,
  nilai_mobil,
  -- date_modified,
  NOW() AS running_time
FROM base
WHERE flag_jumlah_keluarga = 1
ORDER BY level_1_code, level_2_code, level_3_code, level_4_code, level_5_code, level_6_code, assignment_id;
