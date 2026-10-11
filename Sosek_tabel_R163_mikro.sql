/*
Judul : Tabel R.163. Tabel Mikro keluarga yang memiliki mobil dengan Harga mobil > Rp 1 miliar
Tujuan : Identifikasi Keluarga dengan Aset Mobil
Kategori : Agregat
Database/dialek : Fasih Data
Pembuat : Susanto
Tanggal : 2026-10-06
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
    bta.level_1_full_code,
    bta.level_2_full_code,
    bta.level_3_full_code,
    bta.level_4_full_code,
    bta.level_5_full_code,
    bta.level_6_full_code,
    bta.assignment_id,
    rt.nama_kk,
    rt.jumlah_mobil_new as jumlah_mobil,
    rt.nilai_mobil,
    rt.catatan,
    CONCAT('https://fasih-sm.bps.go.id/app/assignment/fd68e454-ba45-4b85-8205-f3bf777ded24/', bta.assignment_id) AS link_fasih_sm
FROM tgr_fd68e454.base_table_assignment bta
CROSS JOIN param_wilayah pw
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
  
  -- ===================================================
  -- FILTER PRELIST DAN PENDATAAN MOBIL
  -- ===================================================
  AND rt.nilai_mobil > 1000000000 AND rt.jumlah_mobil_new=1
  
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
    bta.level_1_full_code,
    bta.level_2_full_code,
    bta.level_3_full_code,
    bta.level_4_full_code,
    bta.level_5_full_code,
    bta.level_6_full_code;
