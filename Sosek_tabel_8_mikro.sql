/*
Judul           : Tabel 8. Jumlah Penduduk yang mempunyai NIK tidak 16 digit menurut Provinsi (Level Mikro)
Tujuan          : Menampilkan daftar anggota keluarga dengan NIK yang jumlah digitnya tidak 16 (length(NIK) != 16) untuk ditindaklanjuti
Kategori        : Mikro
Database/dialek : Fasih Data
Pembuat         : Najwa Azrai
Tanggal         : 2026-10-02
*/

WITH
param_wilayah AS (
    /* =================================================================================
       BLOK PENGATURAN WILAYAH (Ubah nilai di dalam tanda kutip tunggal di bawah ini)
       ================================================================================= */
    SELECT
        -- Provinsi dan kabupaten/kota akan diisi oleh extension saat query dijalankan.
        -- Format: satu atau beberapa kode, pisahkan dengan tanda pipa | (contoh: '32|33|35' atau '3201|3202|3205').
        -- Kosongkan '' jika tidak dipakai.
        '' AS filter_provinsi,
        '' AS filter_kabupaten
)
select
  d.assignment_id,
  d.level_1_full_code,
  d.level_2_full_code,
  d.level_3_full_code,
  d.level_3_name as nama_kecamatan,
  d.level_4_full_code,
  d.level_4_name as nama_desa,
  d.level_6_full_code,
  d.level_6_name as nama_sls,
  r.nama_kk,
  r.no_kk,
  d.no_urut_kk,
  d.nama_dtsen as nama_anggota,
  d.nik_dtsen as nik,
  coalesce(length(d.nik_dtsen), 0) as jumlah_digit_nik,
  d.hubungan_label,
  d.keberadaan_dtsen_label,
  d.jk_dtsen_label,
  d.tgl_lahir,
  d.bln_lahir_value,
  d.thn_lahir,
  d.umur_ak as umur
from tgr_fd68e454.nested_dtsen d
inner join tgr_fd68e454.base_table_assignment b
  on d.assignment_id = b.assignment_id
  and d.assignment_date_modified = b.date_modified
inner join tgr_fd68e454.root_table r
  on d.assignment_id = r.assignment_id
  and d.assignment_date_modified = r.assignment_date_modified
cross join param_wilayah p
where
    b.is_active = 1
    and b.assignment_status_id = 2
    and (b.assignment_status_alias = 'APPROVED BY Admin Kabupaten' OR b.assignment_status_alias = 'APPROVED BY Pengawas')
    and coalesce(r.jenis_prelist, '') <> 'dummy'
    and (
        r.jenis_prelist = 'keluarga'
        or (r.jenis_prelist is null and r.is_new_value = 1)
    )
    and CAST(r.ada_keluarga_value as int) IN (1,2)
    and (
        (coalesce(p.filter_provinsi, '') = '' and coalesce(p.filter_kabupaten, '') = '')
        or (coalesce(p.filter_provinsi, '') <> '' and b.level_1_full_code REGEXP p.filter_provinsi)
        or (coalesce(p.filter_kabupaten, '') <> '' and b.level_2_full_code REGEXP p.filter_kabupaten)
    )
    -- Filter status keberadaan: 1 = tinggal di rumah ini, 5 = anggota keluarga baru
    and CAST(d.keberadaan_dtsen_value as int) in (1, 5)
    -- Syntax: length(NIK) != 16 (NIK kosong/null ikut dihitung)
    and coalesce(length(d.nik_dtsen), 0) <> 16
order by
  d.level_1_full_code,
  d.level_2_full_code,
  d.level_3_full_code,
  d.level_4_full_code,
  d.level_6_full_code,
  d.assignment_id,
  d.no_urut_kk;