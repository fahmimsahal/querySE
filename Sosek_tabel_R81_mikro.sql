/*
Judul           : R.81 Mikro Keluarga di Rumah Susun/Apartemen Milik Sendiri dengan Bukti Kepemilikan Bukan Kode 2
Tujuan          : Listing identifikasi keluarga di rumah susun/apartemen (b4r1a = 3 atau 4), status milik sendiri (b4r3a = 1), tetapi bukti kepemilikan (b4r3b) bukan kode 2
Kategori        : Mikro (Listing)
Database/dialek : Fasih Data
Pembuat         : Najwa Azrai
Tanggal         : 2026-10-06
Catatan         : Filter status keberadaan keluarga: ada_keluarga_value IN (1,2) (1 = Ditemukan, 2 = Baru). Hanya assignment APPROVED BY Pengawas / Admin Kabupaten.
                  b4r3a = status_kepemilikan_value; b4r3b = bukti_kepemilikan_value. Baris dengan bukti_kepemilikan_value kosong tidak terhitung.
                  Level wilayah 3-6 diambil dari base_table_assignment (b).
*/

WITH param_wilayah AS (
  /* =================================================================================
     BLOK PENGATURAN WILAYAH (Ubah nilai di dalam tanda kutip tunggal di bawah ini)
     ================================================================================= */
  SELECT
      -- Provinsi (satu atau beberapa): ketik kodenya, pisahkan dengan tanda pipa | (contoh: '32' atau '32|33|35').
      -- Kosongkan '' jika tidak dipakai.
      '' AS filter_provinsi,

      -- Kabupaten (satu atau beberapa): ketik kodenya, pisahkan dengan tanda pipa | (contoh: '3201' atau '3201|3202|3205').
      -- Kosongkan '' jika tidak dipakai.
      '' AS filter_kabupaten
)

SELECT
    b.level_1_full_code,
    b.level_2_full_code,
    b.level_3_full_code,
    b.level_4_full_code,
    b.level_5_full_code,
    b.level_6_full_code,
    r.no_kk,
    r.jns_bangunan_value,
    r.jns_bangunan_label,
    r.status_kepemilikan_value,
    r.status_kepemilikan_label,
    r.bukti_kepemilikan_value,
    r.bukti_kepemilikan_label,
    CONCAT('https://fasih-sm.bps.go.id/app/assignment/fd68e454-ba45-4b85-8205-f3bf777ded24/', r.assignment_id) AS link_fasih_sm
FROM tgr_fd68e454.root_table r
CROSS JOIN param_wilayah pw
    INNER JOIN tgr_fd68e454.base_table_assignment b
        ON r.assignment_id = b.assignment_id
        AND r.assignment_date_modified = b.date_modified
WHERE
        b.is_active = 1
        AND b.assignment_status_id = 2
        AND b.assignment_status_alias IN ('APPROVED BY Pengawas','APPROVED BY Admin Kabupaten')
        AND COALESCE(r.jenis_prelist, '') <> 'dummy'
        AND (
            r.jenis_prelist = 'keluarga'
            OR (r.jenis_prelist IS NULL AND r.is_new_value = 1)
        )
        AND CAST(r.ada_keluarga_value AS INT) IN (1, 2)
        AND CAST(r.jns_bangunan_value AS INT) IN (3, 4)
        AND CAST(r.status_kepemilikan_value AS INT) = 1
        AND CAST(r.bukti_kepemilikan_value AS INT) <> 2
        -- ==========================================
        -- LOGIKA FILTER WILAYAH
        -- ==========================================
        AND (
            (pw.filter_provinsi <> '' AND b.level_1_full_code REGEXP pw.filter_provinsi)
            OR
            (pw.filter_kabupaten <> '' AND b.level_2_full_code REGEXP pw.filter_kabupaten)
            OR
            (pw.filter_provinsi = '' AND pw.filter_kabupaten = '')
        )
ORDER BY
    b.level_1_full_code,
    b.level_2_full_code,
    b.level_3_full_code,
    b.level_4_full_code,
    b.level_5_full_code,
    b.level_6_full_code;
