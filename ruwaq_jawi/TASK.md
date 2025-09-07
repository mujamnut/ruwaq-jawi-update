# TASK.md - Maktabah App Development Tasks

## Ringkasan Projek (Terkini)
* __Platform__: Flutter + Supabase, pembayaran melalui WebView (Chip/ToyyibPay) dan Edge Functions.
* __Status__: ~85% siap. Aplikasi Pelajar ~95%, Admin ~90%, Sistem Pembayaran ~95% (aliran asas).
* __Capaian Utama Siap__: Auth lengkap, UI pelajar, player video+PDF, pengesanan progress, langganan & pembayaran asas, dashboard/admin asas, RLS menyeluruh.

## Status DB & Payment (Kemaskini Terkini)
* __Jadual baharu__: `subscription_plans`, `user_subscriptions`, `payments`, `webhook_logs`.
* __Polisi__: RLS untuk `user_subscriptions`, `payments`, `webhook_logs` + polisi service role.
* __Profil__:
  - Kolum `profiles.subscription_status` ditambah (jika tiada).
  - Fungsi `check_active_subscription(user_uuid)` untuk semakan aktif.
  - Fungsi trigger `update_profile_subscription_status()` + trigger `update_profile_on_subscription_change` pada `user_subscriptions` untuk sync automatik.
* __Nota penyatuan__: Skema lama `subscriptions`/`transactions` masih wujud. Pilih satu set skema dan migrasi/nyahaktif yang lama.

## Ciri Siap (Ringkas)
* __Auth__: Daftar/Log masuk/Lupa kata laluan, profil, navigasi berperanan, auto-login, pengurusan sesi.
* __Pelajar__: Home + banner, senarai & carian kitab, butiran kitab, saved items, tema Islamik, loading/error states.
* __Player__: YouTube video, PDF Viewer, split view, sync progress masa nyata.
* __Langganan & Pembayaran__: UI pelan, WebView pembayaran, webhook, aktivasi automatik, unlock kandungan, `SubscriptionProvider`.
* __Admin__: Dashboard asas, pengurusan kandungan dan pengguna.

## Tugasan Berbaki (Terperinci)
### Pembayaran & Langganan
* __Skrin kejayaan/kegagalan pembayaran__ (UI, retry, deep-link kembali ke app).
* __Peringatan pembaharuan__ (notifikasi lokal + checker server-side).
* __Naik taraf/Turun taraf pelan__ dengan prorata.
* __Refund request__ + kelulusan admin + hook API refund gateway.
* __Resit/Invois__: jana rekod, PDF/Email ke pengguna.
* __Webhook hardening__: verifikasi tandatangan, idempotency key, retry/backoff, logging terperinci.
* __Penyatuan skema DB__: pilih `user_subscriptions/payments` vs `subscriptions/transactions`, migrasi data, deprecate jadual lama.
* __Pengendalian ralat gateway__: timeout, duplicate, user-cancel; mapping status konsisten.
* __Lock akses premium__ ketika pembayaran pending.

### Admin
* __Analitik__: graf hasil, aktif, churn, MRR, ARPU.
* __Eksport data__: CSV transaksi/langganan.
* __Pengurusan kategori__: CRUD penuh, susunan, ikon.
* __Tetapan aplikasi__: feature flags, maintenance mode, contact info.
* __Manual override langganan__: aktif/nyahaktif + audit log.

### Kualiti & Ujian
* __Unit test__: auth, logik langganan, operasi DB, util/formatter.
* __Integration test__: aliran pembayaran end-to-end + webhook.
* __UAT__: senario pelajar/admin, kes tepi (network/offline).
* __Prestasi__: lazy-loading, caching, semak indeks query, memory/leaks.

### Keselamatan
* __Audit RLS__ (deny-by-default) dan semak SELECT/INSERT/UPDATE/DELETE.
* __Edge Functions__: semak secrets/ENV, least privilege.
* __Pengurusan kunci__: simpan ENV dev/prod dengan selamat, rotasi kunci.

### UX Mikro
* __Empty states__ untuk senarai (kitab, saved, transaksi).
* __Skeleton loading__ untuk home/kitab/player.
* __Mesej ralat jelas__ + tindakan (retry/report).
* __Lokalisasi__ BM/EN label pembayaran & polisi.
* __Aksesibiliti__: teks lebih besar, kontras, TalkBack/VoiceOver.

### Deploy & Launch
* __Aset kedai aplikasi__: screenshot, deskripsi, polisi privasi, terma.
* __Production setup__: Supabase & payment keys, app signing, CI/CD, release build.

### Monitoring
* __Analytics event map__: view_kitab, start_payment, payment_success/fail, subscribe_*, progress_*.
* __Crashlytics & Performance Monitoring__.
* __Amaran kadar gagal pembayaran__ & kesihatan webhook.

## Langkah Seterusnya (Keutamaan)
1. Lengkapkan skrin kejayaan/kegagalan pembayaran + deep-link balik ke app.
2. Kuatkan webhook (signature, idempotency, retry) dan uji E2E.
3. Putuskan dan satukan skema DB; rancang migrasi/deprecation.
4. Bina papan analitik admin asas (graf ringkas) dan eksport CSV.
5. Mula rangka ujian unit/integrasi untuk aliran pembayaran.