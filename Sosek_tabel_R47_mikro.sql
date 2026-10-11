/*
Judul           : Tabel Mikro Penduduk Berstatus Orangtua/Mertua dengan Selisih Umur thd Kepala Keluarga <= 10 Tahun
Tujuan          : Identifikasi dan listing individu berstatus orangtua/mertua yang selisih umurnya dengan Kepala Keluarga tidak wajar (<= 10 tahun)
Kategori        : Mikro (Listing)
Database/dialek : Fasih Data
Pembuat         : Susanto
Tanggal         : 2026-10-02
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
    dn.level_1_full_code,
    dn.level_2_full_code,
    dn.level_3_full_code,
    dn.level_4_full_code,
    dn.level_5_full_code,
    dn.level_6_full_code,
    dn.assignment_id,
    dn.no_urut_kk,
    dn.nik_dtsen,
    dn.hubungan_value AS hubungan_ortu_mertua,
    dn.umur_ak AS umur_ortu_mertua,
    kk.umur_ak AS umur_kepala_keluarga,
    rt.nama_kk,
    rt.catatan,
    CONCAT('https://fasih-sm.bps.go.id/app/assignment/fd68e454-ba45-4b85-8205-f3bf777ded24/', dn.assignment_id) AS link_fasih_sm
FROM tgr_fd68e454.nested_dtsen dn
CROSS JOIN param_wilayah pw

-- ==========================================
-- SELF-JOIN UNTUK MENGAMBIL DATA KEPALA KELUARGA
-- ==========================================
INNER JOIN tgr_fd68e454.nested_dtsen kk 
  ON dn.assignment_id = kk.assignment_id 
  AND dn.assignment_date_modified = kk.assignment_date_modified
  AND kk.hubungan_value = '1' -- Hanya ambil anggota yang Kepala Keluarga

INNER JOIN tgr_fd68e454.base_table_assignment bta 
  ON dn.assignment_id = bta.assignment_id  
  AND dn.assignment_date_modified = bta.assignment_date_modified
INNER JOIN tgr_fd68e454.root_table rt 
  ON bta.assignment_id = rt.assignment_id 
  AND bta.assignment_date_modified = rt.assignment_date_modified 
WHERE 
  bta.is_active = 1 
  AND bta.assignment_status_id = 2
  AND bta.assignment_status_alias IN ('APPROVED BY Pengawas','APPROVED BY Admin Kabupaten')
  AND COALESCE(rt.jenis_prelist, '') <> 'dummy'
  AND (
        rt.jenis_prelist = 'keluarga'
        OR (rt.jenis_prelist IS NULL AND rt.is_new_value = 1)
      )
  AND CAST(rt.ada_keluarga_value AS INT) IN (1, 2)
  AND CAST(dn.keberadaan_dtsen_value AS INT) IN (1, 5)
  
  -- ==========================================
  -- FILTER SELISIH UMUR ORANGTUA/MERTUA DENGAN KEPALA KELUARGA <= 10
  -- ==========================================
  AND dn.hubungan_value IN ('6','7') -- Filter Orang Tua (6) atau Mertua (7)
  AND ABS(dn.umur_ak - kk.umur_ak) <= 10 -- Cek selisih umur dengan KK kurang dari atau sama dengan 10 tahun
  
  -- ==========================================
  -- LOGIKA FILTER WILAYAH
  -- ==========================================
  AND (
    (pw.filter_provinsi <> '' AND bta.level_1_full_code = pw.filter_provinsi)
    OR
    (pw.filter_kabupaten <> '' AND bta.level_2_full_code REGEXP pw.filter_kabupaten)
    OR
    (pw.filter_provinsi = '' AND pw.filter_kabupaten = '')
  )
ORDER BY 
    dn.level_1_full_code,
    dn.level_2_full_code,
    dn.level_3_full_code,
    dn.level_4_full_code,
    dn.level_5_full_code,
    dn.level_6_full_code;