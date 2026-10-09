/*
Judul : Tabel 31. Jumlah Keluarga Menurut Jumlah Anggota Keluarga (Versi Mikro - Jumlah Anggota 0)
Tujuan : Menampilkan baris detail keluarga yang memiliki jumlah anggota keluarga (jml_kk_update) sama dengan 0
Kategori : Mikro (Row-Level)
Database/dialek : Fasih Data
Pembuat : Susanto (Dikonversi ke Mikro oleh Ratih)
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
),
/* ================================================================================= */

/* 1. MASTER WILAYAH: Ambil semua daftar wilayah unik sesuai filter */
     master_wilayah AS (
         SELECT DISTINCT
             level_1_full_code,
             level_1_name,
             level_2_full_code,
             level_2_name
         FROM tgr_fd68e454.base_table_assignment
                  CROSS JOIN param_wilayah pw
         WHERE
             (pw.filter_provinsi <> '' AND level_1_full_code = pw.filter_provinsi)
            OR (pw.filter_kabupaten <> '' AND level_2_full_code REGEXP pw.filter_kabupaten)
            OR (pw.filter_provinsi = '' AND pw.filter_kabupaten = '')
     )

/* 2. HASIL AKHIR MIKRO: Menampilkan daftar baris detail keluarga dengan jumlah anggota = 0 */
SELECT
    mw.level_1_full_code,
    mw.level_1_name,
    mw.level_2_full_code,
    mw.level_2_name,
    rt.assignment_id,
    rt.jml_kk_update AS jumlah_anggota_keluarga,
    rt.nama_kk,
    rt.catatan
FROM master_wilayah mw
         INNER JOIN tgr_fd68e454.base_table_assignment bta
                    ON mw.level_2_full_code = bta.level_2_full_code
                        AND mw.level_1_full_code = bta.level_1_full_code
         INNER JOIN tgr_fd68e454.root_table rt
                    ON bta.assignment_id = rt.assignment_id
WHERE
        bta.is_active = 1
  AND bta.assignment_status_id = 2
  AND (bta.assignment_status_alias = 'APPROVED BY Admin Kabupaten' OR bta.assignment_status_alias = 'APPROVED BY Pengawas')
  AND COALESCE(rt.jenis_prelist, '') <> 'dummy'
  AND (
            rt.jenis_prelist = 'keluarga'
        OR (rt.jenis_prelist IS NULL AND rt.is_new_value = 1)
    )
  AND CAST(rt.ada_keluarga_value AS INT) IN (1, 2)
  -- Kondisi filter khusus jumlah anggota keluarga sama dengan 0
  AND CAST(rt.jml_kk_update AS INT) = 0
ORDER BY
    mw.level_1_full_code,
    mw.level_2_full_code;