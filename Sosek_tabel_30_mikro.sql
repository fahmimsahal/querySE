
/*
Judul           : Tabel 30. (Mikro) Penduduk Usia < 10 Tahun dengan Status Pekerjaan Utama
Tujuan          : Identifikasi dan listing individu yang usianya di bawah 10 tahun namun tercatat memiliki status kedudukan dalam pekerjaan
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
    dn.umur_ak,
    var.status_kerja_value,
    rt.nama_kk,
    rt.catatan,
    CONCAT('https://fasih-sm.bps.go.id/app/assignment/fd68e454-ba45-4b85-8205-f3bf777ded24/', dn.assignment_id) AS link_fasih_sm
FROM tgr_fd68e454.nested_dtsen dn
CROSS JOIN param_wilayah pw
INNER JOIN tgr_fd68e454.nested_dtsen_var var 
  ON dn.assignment_id = var.assignment_id 
  AND dn.index1 = var.index1
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
  AND dn.nik_dtsen IS NOT NULL
  AND (
        rt.jenis_prelist = 'keluarga'
        OR (rt.jenis_prelist IS NULL AND rt.is_new_value = 1)
      )
  AND CAST(rt.ada_keluarga_value AS INT) IN (1, 2)
  AND CAST(dn.keberadaan_dtsen_value AS INT) IN (1, 5)
  
  -- ==========================================
  -- FILTER ANOMALI: USIA < 10 TAPI PUNYA STATUS KERJA
  -- (Hapus/comment baris dn.umur_ak < 10 jika ingin me-listing semua usia)
  -- ==========================================
  AND dn.umur_ak < 10
  AND var.status_kerja_value IS NOT NULL
  AND TRIM(var.status_kerja_value) <> ''
  
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