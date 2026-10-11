/*
Judul           : Tabel R.117. Keluarga dengan daya 900 watt, tetapi memiliki AC >3 unit (MIKRO)
Tujuan          : Daftar keluarga dengan daya listrik 900 watt namun memiliki AC lebih dari 3 unit
Kategori        : Mikro
Database/dialek : StarRocks (dialek MySQL-compatible)
Pembuat         : Fauzan Faldy Anggita
Tanggal         : 2026-10-01
Sumber          : [Reviewed] 23.09.2026 - Tabel Anomali Keluarga SE - Tambahan 2.xlsx, Sheet R.117
Rule (rantab)   : b4r14.b=2 & b4r17.d>3
Catatan         : b4r14.b=nested_meteran.daya_terpasang_value (2=900 watt). b4r17.d=jumlah_ac. Kolom jumlah_<aset> dipakai sebagai COALESCE(jumlah_<aset>_new, jumlah_<aset>) sesuai pola kueri_keluarga_pip.txt (jumlah_<aset>_new berisi nilai hasil koreksi admin, dipakai jika terisi); untuk mobil/motor ditambah fallback: jika hasil COALESCE null/0 tapi nilai_mobil/nilai_motor terisi, dianggap 1 unit. Filter status keberadaan: CAST(r.ada_keluarga_value AS INT) IN (1,2) dan CAST(kk.keberadaan_dtsen_value AS INT) IN (1,5), dicek pada baris ART Kepala Keluarga (nested_dtsen.hubungan_value='1') sebagai status-of-record keluarga. Satu keluarga bisa punya >1 meteran; agar tetap 1 baris per keluarga, meteran yang lolos filter dipivot ke kolom meteran_daya_1..7 (lihat jumlah_meteran_terdeteksi untuk memastikan tidak ada yang terpotong), karena GROUP_CONCAT/array_agg/WITH RECURSIVE diblokir di cluster ini.
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
    m.daya_terpasang_value,
    m.daya_terpasang_label,
    r.jumlah_ac,
    r.jumlah_ac_new,
    m.no_meteran,
    CONCAT(coalesce(m.no_meteran,'(nomor_meteran_kosong)'), ':', m.daya_terpasang_value,'-',daya_terpasang_label) AS meteran_info,
    CASE WHEN CAST(m.daya_terpasang_value AS INT) = 2 AND COALESCE(r.jumlah_ac_new, r.jumlah_ac) > 3 THEN 1 ELSE 0 END AS flag_jumlah_keluarga
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
),
flagged AS (
  SELECT
    level_1_code, level_1_name, level_2_code, level_2_name, level_3_code, level_3_name,
    level_4_code, level_4_name, level_5_code, level_5_name, level_6_code, level_6_name,
    assignment_id, no_kk, nama_kk, jumlah_ac, jumlah_ac_new, meteran_info,
    ROW_NUMBER() OVER (PARTITION BY assignment_id ORDER BY no_meteran) AS rn
  FROM base
  WHERE flag_jumlah_keluarga = 1
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
  coalesce(jumlah_ac_new,jumlah_ac) as jumlah_ac,
  MAX(CASE WHEN rn = 1 THEN meteran_info END) AS meteran_daya_1,
  MAX(CASE WHEN rn = 2 THEN meteran_info END) AS meteran_daya_2,
  MAX(CASE WHEN rn = 3 THEN meteran_info END) AS meteran_daya_3,
  MAX(CASE WHEN rn = 4 THEN meteran_info END) AS meteran_daya_4,
  MAX(CASE WHEN rn = 5 THEN meteran_info END) AS meteran_daya_5,
  MAX(CASE WHEN rn = 6 THEN meteran_info END) AS meteran_daya_6,
  MAX(CASE WHEN rn = 7 THEN meteran_info END) AS meteran_daya_7,
  COUNT(1) AS jumlah_meteran_terdeteksi,
  NOW() AS running_time
FROM flagged
GROUP BY level_1_code, level_1_name, level_2_code, level_2_name, level_3_code, level_3_name,
         level_4_code, level_4_name, level_5_code, level_5_name, level_6_code, level_6_name,
         assignment_id, no_kk, nama_kk, jumlah_ac, jumlah_ac_new
ORDER BY level_1_code, level_2_code, level_3_code, level_4_code, level_5_code, level_6_code, assignment_id;
