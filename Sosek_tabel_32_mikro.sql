/*
Judul   : Tabel 32 (MIKRO). Daftar Case Missing Value Variabel Kependudukan
Tujuan  : Daftar anggota keluarga (identitas: kode_sls, no_kk, nama_kk, no_urut_kk,
          nama_dtsen, nik_dtsen) yang memiliki minimal satu case missing value (NULL,
          string kosong, atau kode sentinel 7777/8888/9999) pada variabel
          kependudukan, untuk kebutuhan tracing/cleaning oleh petugas. Dasar Tabel 32
          (Agregat).
Sumber  : [Reviewed] 17.09.2026 - Tabel Anomali Keluarga SE - Tambahan 1.xlsx (sheet '32').
          Kondisi  : APPROVED by PENGAWAS & APPROVED by ADMIN KAB/KOTA.
          Catatan penting - skip pattern kuesioner CAPI (TGR), sama seperti versi
          Agregat (lihat Agregat/Sosek/Sosek_tabel_32.sql untuk detail enableCondition
          tiap field). Flag per variabel bernilai NULL jika variabel tersebut memang
          tidak wajib diisi untuk keberadaan_dtsen_value baris ybs (bukan missing),
          1 jika wajib diisi tapi kosong/NULL/sentinel, 0 jika wajib diisi dan terisi.
          Hanya baris dengan minimal 1 flag = 1 yang ditampilkan.
Kategori : Mikro
Database/dialek : StarRocks (dialek MySQL-compatible)
Pembuat  : Fauzan Faldy Anggita
Tanggal  : 2026-10-03
*/

WITH param_wilayah AS (
  /* =================================================================================
     BLOK PENGATURAN WILAYAH (Ubah nilai di dalam tanda kutip tunggal di bawah ini)
     ================================================================================= */
  SELECT
    '' AS filter_provinsi,
    '' AS filter_kabupaten
),
/* ================================================================================= */

/* 1. BASE: satu baris per anggota keluarga, dilengkapi identitas KK dan nama_dtsen_var */
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
    r.assignment_id,
    r.kode_sls,
    r.no_kk,
    r.nama_kk,
    d.no_urut_kk,
    d.nik_dtsen,
    d.nama_dtsen,
    v.nama_dtsen_var,
    d.hubungan_label,
    d.hubungan_value,
    d.keberadaan_dtsen_label,
    TRIM(CAST(d.keberadaan_dtsen_value AS CHAR)) AS keberadaan_dtsen_value,
    d.alamat_dn_label,
    d.alamat_dn_value,
    d.prov_dn_label,
    d.prov_dn_value,
    d.kab_dn_label,
    d.kab_dn_value,
    d.domisili_ln_label,
    d.domisili_ln_value,
    d.status_kawin_label,
    d.status_kawin_value,
    d.jk_dtsen_label,
    d.jk_dtsen_value,
    d.tgl_lahir,
    d.bln_lahir_label,
    d.bln_lahir_value,
    d.thn_lahir,
    d.umur_ak
  FROM tgr_fd68e454.nested_dtsen d
  INNER JOIN tgr_fd68e454.base_table_assignment b
    ON d.assignment_id = b.assignment_id
   AND d.assignment_date_modified = b.date_modified
  INNER JOIN tgr_fd68e454.root_table r
    ON d.assignment_id = r.assignment_id
   AND d.assignment_date_modified = r.assignment_date_modified
  LEFT JOIN tgr_fd68e454.nested_dtsen_var v
    ON v.assignment_id = d.assignment_id
   AND v.index1 = d.index1
   AND v.assignment_date_modified = d.assignment_date_modified
  CROSS JOIN param_wilayah pw
  WHERE
    (
      (pw.filter_provinsi <> '' AND b.level_1_full_code = pw.filter_provinsi)
      OR (pw.filter_kabupaten <> '' AND b.level_2_full_code REGEXP pw.filter_kabupaten)
      OR (pw.filter_provinsi = '' AND pw.filter_kabupaten = '')
    )
    AND b.is_active = 1
    AND b.assignment_status_id = 2
	AND r.ada_keluarga_value in (1,2)
    AND COALESCE(r.jenis_prelist, '') <> 'dummy'
),

/* 2. FLAG: 1 flag per variabel - NULL = tidak wajib diisi (N/A), 1 = missing, 0 = terisi */
flagged AS (
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
    b.assignment_id,
    b.kode_sls,
    b.no_kk,
    b.nama_kk,
    b.no_urut_kk,
    b.nik_dtsen,
    b.nama_dtsen,
    b.keberadaan_dtsen_label,
    b.keberadaan_dtsen_value,

    CASE WHEN nama_dtsen IS NULL OR TRIM(nama_dtsen) = '' THEN 1 ELSE 0 END AS flag_nama_dtsen,
    CASE WHEN nama_dtsen_var IS NULL OR TRIM(nama_dtsen_var) = '' THEN 1 ELSE 0 END AS flag_nama_dtsen_var,
    CASE WHEN keberadaan_dtsen_value IS NULL OR keberadaan_dtsen_value = '' OR keberadaan_dtsen_value IN ('7777','8888','9999') THEN 1 ELSE 0 END AS flag_keberadaan_dtsen,

    -- wajib hanya jika keberadaan_dtsen_value IN (1,3,4,5)
    CASE WHEN keberadaan_dtsen_value NOT IN ('1','3','4','5') THEN NULL
         WHEN hubungan_label IS NULL OR TRIM(hubungan_label) = '' OR TRIM(hubungan_label) IN ('7777','8888','9999')
           OR hubungan_value IS NULL OR TRIM(hubungan_value) = '' OR TRIM(hubungan_value) IN ('7777','8888','9999')
         THEN 1 ELSE 0 END AS flag_hubungan,
    CASE WHEN keberadaan_dtsen_value NOT IN ('1','3','4','5') THEN NULL
         WHEN status_kawin_label IS NULL OR TRIM(status_kawin_label) = '' OR TRIM(status_kawin_label) IN ('7777','8888','9999')
           OR status_kawin_value IS NULL OR TRIM(status_kawin_value) = '' OR TRIM(status_kawin_value) IN ('7777','8888','9999')
         THEN 1 ELSE 0 END AS flag_status_kawin,
    CASE WHEN keberadaan_dtsen_value NOT IN ('1','3','4','5') THEN NULL
         WHEN jk_dtsen_label IS NULL OR TRIM(jk_dtsen_label) = '' OR TRIM(jk_dtsen_label) IN ('7777','8888','9999')
           OR jk_dtsen_value IS NULL OR TRIM(jk_dtsen_value) = '' OR TRIM(jk_dtsen_value) IN ('7777','8888','9999')
         THEN 1 ELSE 0 END AS flag_jk_dtsen,
    CASE WHEN keberadaan_dtsen_value NOT IN ('1','3','4','5') THEN NULL
         WHEN tgl_lahir IS NULL OR TRIM(tgl_lahir) = '' OR TRIM(tgl_lahir) IN ('7777','8888','9999')
         THEN 1 ELSE 0 END AS flag_tgl_lahir,
    CASE WHEN keberadaan_dtsen_value NOT IN ('1','3','4','5') THEN NULL
         WHEN bln_lahir_label IS NULL OR TRIM(bln_lahir_label) = '' OR TRIM(bln_lahir_label) IN ('7777','8888','9999')
           OR bln_lahir_value IS NULL OR TRIM(bln_lahir_value) = '' OR TRIM(bln_lahir_value) IN ('7777','8888','9999')
         THEN 1 ELSE 0 END AS flag_bln_lahir,
    CASE WHEN keberadaan_dtsen_value NOT IN ('1','3','4','5') THEN NULL
         WHEN thn_lahir IS NULL OR TRIM(thn_lahir) = '' OR TRIM(thn_lahir) IN ('7777','8888','9999')
         THEN 1 ELSE 0 END AS flag_thn_lahir,
    CASE WHEN keberadaan_dtsen_value NOT IN ('1','3','4','5') THEN NULL
         WHEN umur_ak IS NULL OR umur_ak IN (7777,8888,9999)
         THEN 1 ELSE 0 END AS flag_umur_ak,

    -- wajib hanya jika keberadaan_dtsen_value IN (1,5)
    CASE WHEN keberadaan_dtsen_value NOT IN ('1','5') THEN NULL
         WHEN alamat_dn_label IS NULL OR TRIM(alamat_dn_label) = '' OR TRIM(alamat_dn_label) IN ('7777','8888','9999')
           OR alamat_dn_value IS NULL OR TRIM(alamat_dn_value) = '' OR TRIM(alamat_dn_value) IN ('7777','8888','9999')
         THEN 1 ELSE 0 END AS flag_alamat_dn,

    -- wajib hanya jika keberadaan_dtsen_value = 3
    CASE WHEN keberadaan_dtsen_value <> '3' THEN NULL
         WHEN prov_dn_label IS NULL OR TRIM(prov_dn_label) = '' OR TRIM(prov_dn_label) IN ('7777','8888','9999')
           OR prov_dn_value IS NULL OR TRIM(prov_dn_value) = '' OR TRIM(prov_dn_value) IN ('7777','8888','9999')
         THEN 1 ELSE 0 END AS flag_prov_dn,
    CASE WHEN keberadaan_dtsen_value <> '3' THEN NULL
         WHEN kab_dn_label IS NULL OR TRIM(kab_dn_label) = '' OR TRIM(kab_dn_label) IN ('7777','8888','9999')
           OR kab_dn_value IS NULL OR TRIM(kab_dn_value) = '' OR TRIM(kab_dn_value) IN ('7777','8888','9999')
         THEN 1 ELSE 0 END AS flag_kab_dn,

    -- wajib hanya jika keberadaan_dtsen_value = 4
    CASE WHEN keberadaan_dtsen_value <> '4' THEN NULL
         WHEN domisili_ln_label IS NULL OR TRIM(domisili_ln_label) = '' OR TRIM(domisili_ln_label) IN ('7777','8888','9999')
           OR domisili_ln_value IS NULL OR TRIM(domisili_ln_value) = '' OR TRIM(domisili_ln_value) IN ('7777','8888','9999')
         THEN 1 ELSE 0 END AS flag_domisili_ln
  FROM base b
)

/* 3. HASIL AKHIR: hanya baris dengan minimal 1 variabel missing, dilengkapi daftar
      nama variabel yang missing per baris agar mudah ditelusuri petugas */
SELECT
    level_1_code, level_1_name,
    level_2_code, level_2_name,
    level_3_code, level_3_name,
    level_4_code, level_4_name,
    level_5_code, level_5_name,
    level_6_code, level_6_name,
    assignment_id,
    kode_sls,
    no_kk,
    nama_kk,
    no_urut_kk,
    nama_dtsen,
    nik_dtsen,
    keberadaan_dtsen_label,
    keberadaan_dtsen_value,
    (
        COALESCE(flag_nama_dtsen,0) + COALESCE(flag_nama_dtsen_var,0) + COALESCE(flag_keberadaan_dtsen,0)
        + COALESCE(flag_hubungan,0) + COALESCE(flag_status_kawin,0) + COALESCE(flag_jk_dtsen,0)
        + COALESCE(flag_tgl_lahir,0) + COALESCE(flag_bln_lahir,0) + COALESCE(flag_thn_lahir,0) + COALESCE(flag_umur_ak,0)
        + COALESCE(flag_alamat_dn,0) + COALESCE(flag_prov_dn,0) + COALESCE(flag_kab_dn,0) + COALESCE(flag_domisili_ln,0)
    ) AS jumlah_variabel_missing,
    CONCAT_WS(', ',
        CASE WHEN flag_nama_dtsen = 1 THEN 'nama_dtsen' END,
        CASE WHEN flag_nama_dtsen_var = 1 THEN 'nama_dtsen_var' END,
        CASE WHEN flag_keberadaan_dtsen = 1 THEN 'keberadaan_dtsen' END,
        CASE WHEN flag_hubungan = 1 THEN 'hubungan' END,
        CASE WHEN flag_status_kawin = 1 THEN 'status_kawin' END,
        CASE WHEN flag_jk_dtsen = 1 THEN 'jk_dtsen' END,
        CASE WHEN flag_tgl_lahir = 1 THEN 'tgl_lahir' END,
        CASE WHEN flag_bln_lahir = 1 THEN 'bln_lahir' END,
        CASE WHEN flag_thn_lahir = 1 THEN 'thn_lahir' END,
        CASE WHEN flag_umur_ak = 1 THEN 'umur_ak' END,
        CASE WHEN flag_alamat_dn = 1 THEN 'alamat_dn' END,
        CASE WHEN flag_prov_dn = 1 THEN 'prov_dn' END,
        CASE WHEN flag_kab_dn = 1 THEN 'kab_dn' END,
        CASE WHEN flag_domisili_ln = 1 THEN 'domisili_ln' END
    ) AS daftar_variabel_missing,
    NOW() AS running_time
FROM flagged
WHERE (
    COALESCE(flag_nama_dtsen,0) + COALESCE(flag_nama_dtsen_var,0) + COALESCE(flag_keberadaan_dtsen,0)
    + COALESCE(flag_hubungan,0) + COALESCE(flag_status_kawin,0) + COALESCE(flag_jk_dtsen,0)
    + COALESCE(flag_tgl_lahir,0) + COALESCE(flag_bln_lahir,0) + COALESCE(flag_thn_lahir,0) + COALESCE(flag_umur_ak,0)
    + COALESCE(flag_alamat_dn,0) + COALESCE(flag_prov_dn,0) + COALESCE(flag_kab_dn,0) + COALESCE(flag_domisili_ln,0)
) > 0
ORDER BY level_1_code, level_2_code, level_3_code, level_4_code, level_5_code, level_6_code, assignment_id, no_urut_kk;
