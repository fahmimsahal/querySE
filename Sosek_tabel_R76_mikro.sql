/*
Judul           : R.76 Mikro Memiliki Stroke tetapi Tidak Mengalami Gangguan Fisik dan Gangguan Wicara
Tujuan          : Listing identifikasi penduduk dengan keluhan stroke (b3r21g = 1) tetapi tidak ada disabilitas fisik (b3r20a = 2) dan wicara (b3r20f = 2)
Kategori        : Mikro (Listing)
Database/dialek : Fasih Data
Pembuat         : Najwa Azrai
Tanggal         : 2026-10-06
Catatan         : Filter status keberadaan keluarga: ada_keluarga_value IN (1,2) (1 = Ditemukan, 2 = Baru). Hanya assignment APPROVED BY Pengawas / Admin Kabupaten.
                  Level penduduk: dari tabel nested (n) dengan keberadaan_dtsen_value IN (1,5) = tinggal di rumah ini (kode 5 mengikuti rule R.53). Sesuaikan jika kode keberadaan berbeda.
                  Variabel Blok III diambil dari tabel nested_dtsen_var (v), dihubungkan ke nested_dtsen (n) lewat assignment_id, assignment_date_modified, dan index1 (alternatif: n.no_urut_kk = v.no_urut_kk_var).
                  b3r21g = sakit_stroke_value; b3r20a = dis_fisik_value; b3r20f = dis_wicara_value (huruf b3r20 dipetakan dari penjelasan rule).
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
    n.no_urut_kk,
    n.nama_dtsen,
    n.nik_dtsen,
    n.hubungan_value,
    n.jk_dtsen_value,
    n.tgl_lahir,
    n.bln_lahir_value,
    n.thn_lahir,
    n.umur_ak,
    v.sakit_stroke_value,
    v.dis_fisik_value,
    v.dis_wicara_value,
    CONCAT('https://fasih-sm.bps.go.id/app/assignment/fd68e454-ba45-4b85-8205-f3bf777ded24/', r.assignment_id) AS link_fasih_sm
FROM tgr_fd68e454.root_table r
CROSS JOIN param_wilayah pw
    INNER JOIN tgr_fd68e454.base_table_assignment b
        ON r.assignment_id = b.assignment_id
        AND r.assignment_date_modified = b.date_modified
    INNER JOIN tgr_fd68e454.nested_dtsen n
        ON n.assignment_id = r.assignment_id
        AND n.assignment_date_modified = r.assignment_date_modified
    INNER JOIN tgr_fd68e454.nested_dtsen_var v
        ON v.assignment_id = n.assignment_id
        AND v.assignment_date_modified = n.assignment_date_modified
        AND v.index1 = n.index1
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
        AND CAST(n.keberadaan_dtsen_value AS INT) IN (1, 5)
        AND CAST(v.sakit_stroke_value AS INT) = 1
        AND CAST(v.dis_fisik_value AS INT) = 2
        AND CAST(v.dis_wicara_value AS INT) = 2
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
    b.level_6_full_code, n.no_urut_kk;
