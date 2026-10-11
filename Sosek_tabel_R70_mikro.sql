/*
Judul           : R.70 Mikro Ijazah Tertinggi Lebih Rendah dari Data Prelist
Tujuan          : Listing identifikasi penduduk dengan ijazah tertinggi hasil pendataan (b3r15) lebih rendah dari ijazah pada data prelist
Kategori        : Mikro (Listing)
Database/dialek : Fasih Data
Pembuat         : Najwa Azrai
Tanggal         : 2026-10-06
Catatan         : Filter status keberadaan keluarga: ada_keluarga_value IN (1,2) (1 = Ditemukan, 2 = Baru). Hanya assignment APPROVED BY Pengawas / Admin Kabupaten.
                  Level penduduk: dari tabel nested (n) dengan keberadaan_dtsen_value IN (1,5) = tinggal di rumah ini (kode 5 mengikuti rule R.53). Sesuaikan jika kode keberadaan berbeda.
                  Variabel Blok III diambil dari tabel nested_dtsen_var (v), dihubungkan ke nested_dtsen (n) lewat assignment_id, assignment_date_modified, dan index1 (alternatif: n.no_urut_kk = v.no_urut_kk_var).
                  b3r15 = ijazah_value; b3r15_prelist diambil dari teks kolom ijazah_prelist (bentuk [{label=..., value=NN}]) dengan SUBSTRING_INDEX. Baris tanpa nilai prelist tidak terhitung.
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
      '1709|1771' AS filter_kabupaten
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
    v.ijazah_value,
    v.ijazah_label,
    v.ijazah_prelist,
    CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(v.ijazah_prelist, 'value=', -1), '}', 1) AS INT) AS ijazah_prelist_kode,
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
        AND v.ijazah_prelist LIKE '%value=%'
        AND CAST(v.ijazah_value AS INT) < CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(v.ijazah_prelist, 'value=', -1), '}', 1) AS INT)
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
