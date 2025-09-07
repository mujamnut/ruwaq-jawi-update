/// Test data for ebooks
/// This contains mock data for testing the ebook admin interface

class TestEbookData {
  static List<Map<String, dynamic>> getSampleEbooks() {
    return [
      {
        'id': '550e8400-e29b-41d4-a716-446655440001',
        'title': 'Tafsir Al-Quran Al-Karim - Surah Al-Fatihah',
        'author': 'Dr. Ahmad Mahmud',
        'description': 'Tafsir lengkap Surah Al-Fatihah dengan penjelasan mendalam tentang makna dan hikmah setiap ayat.',
        'category_id': 'e1166e04-4f53-4d1a-87b6-e71af547d896',
        'pdf_url': 'https://storage.supabase.co/ebooks/tafsir-alfatihah.pdf',
        'thumbnail_url': 'https://storage.supabase.co/thumbnails/tafsir-alfatihah.jpg',
        'total_pages': 120,
        'is_premium': true,
        'is_active': true,
        'views_count': 245,
        'downloads_count': 89,
        'created_at': '2025-01-15T10:30:00Z',
        'updated_at': '2025-01-15T10:30:00Z',
        'categories': {'id': 'e1166e04-4f53-4d1a-87b6-e71af547d896', 'name': 'Quran & Tafsir'}
      },
      {
        'id': '550e8400-e29b-41d4-a716-446655440002',
        'title': 'Hadis 40 - Imam Nawawi',
        'author': 'Imam An-Nawawi',
        'description': 'Koleksi 40 hadis pilihan yang mencakup asas-asas agama Islam. Setiap hadis disertai dengan syarah dan penjelasan yang mudah difahami.',
        'category_id': '25004d73-6445-418e-9726-4e1022ff5309',
        'pdf_url': 'https://storage.supabase.co/ebooks/hadis-40-nawawi.pdf',
        'thumbnail_url': 'https://storage.supabase.co/thumbnails/hadis-40-nawawi.jpg',
        'total_pages': 95,
        'is_premium': false,
        'is_active': true,
        'views_count': 178,
        'downloads_count': 134,
        'created_at': '2025-01-14T08:15:00Z',
        'updated_at': '2025-01-14T08:15:00Z',
        'categories': {'id': '25004d73-6445-418e-9726-4e1022ff5309', 'name': 'Hadis & Sunnah'}
      },
      {
        'id': '550e8400-e29b-41d4-a716-446655440003',
        'title': 'Panduan Solat Lengkap',
        'author': 'Ustaz Muhammad Ali',
        'description': 'Panduan lengkap tentang tata cara solat yang betul mengikut sunnah Rasulullah SAW. Termasuk doa-doa dan zikir selepas solat.',
        'category_id': 'a39016be-df7a-44a0-859e-7caaa32d8732',
        'pdf_url': 'https://storage.supabase.co/ebooks/panduan-solat.pdf',
        'thumbnail_url': 'https://storage.supabase.co/thumbnails/panduan-solat.jpg',
        'total_pages': 78,
        'is_premium': false,
        'is_active': true,
        'views_count': 312,
        'downloads_count': 201,
        'created_at': '2025-01-13T14:45:00Z',
        'updated_at': '2025-01-13T14:45:00Z',
        'categories': {'id': 'a39016be-df7a-44a0-859e-7caaa32d8732', 'name': 'Fiqh'}
      },
      {
        'id': '550e8400-e29b-41d4-a716-446655440004',
        'title': 'Sirah Nabi Muhammad SAW',
        'author': 'Dr. Fatimah Zahra',
        'description': 'Biografi lengkap Rasulullah SAW dari kelahiran hingga wafat. Ditulis dengan gaya bahasa yang mudah difahami untuk semua peringkat umur.',
        'category_id': '49819bc9-abaf-4196-8854-e12147c440de',
        'pdf_url': 'https://storage.supabase.co/ebooks/sirah-nabi.pdf',
        'thumbnail_url': 'https://storage.supabase.co/thumbnails/sirah-nabi.jpg',
        'total_pages': 256,
        'is_premium': true,
        'is_active': true,
        'views_count': 198,
        'downloads_count': 67,
        'created_at': '2025-01-12T09:20:00Z',
        'updated_at': '2025-01-12T09:20:00Z',
        'categories': {'id': '49819bc9-abaf-4196-8854-e12147c440de', 'name': 'Sirah'}
      },
      {
        'id': '550e8400-e29b-41d4-a716-446655440005',
        'title': 'Akidah Islam Asas',
        'author': 'Prof. Dr. Hassan Ibrahim',
        'description': 'Penjelasan komprehensif tentang rukun iman dan asas-asas akidah Islam. Sesuai untuk pelajar dan dewasa yang ingin memperkukuh keimanan.',
        'category_id': '6e69d652-58b7-4376-b416-a5672f0f7c94',
        'pdf_url': 'https://storage.supabase.co/ebooks/akidah-asas.pdf',
        'thumbnail_url': 'https://storage.supabase.co/thumbnails/akidah-asas.jpg',
        'total_pages': 143,
        'is_premium': true,
        'is_active': true,
        'views_count': 156,
        'downloads_count': 78,
        'created_at': '2025-01-11T16:30:00Z',
        'updated_at': '2025-01-11T16:30:00Z',
        'categories': {'id': '6e69d652-58b7-4376-b416-a5672f0f7c94', 'name': 'Akidah'}
      },
      {
        'id': '550e8400-e29b-41d4-a716-446655440006',
        'title': 'Adab dan Akhlak Muslim',
        'author': 'Ustazah Khadijah Ahmad',
        'description': 'Panduan praktis tentang adab dan akhlak yang mulia dalam kehidupan seharian seorang Muslim. Berdasarkan Al-Quran dan Sunnah.',
        'category_id': 'ee66c3d9-74e4-44dd-8761-62ea489b10fb',
        'pdf_url': 'https://storage.supabase.co/ebooks/adab-akhlak.pdf',
        'thumbnail_url': 'https://storage.supabase.co/thumbnails/adab-akhlak.jpg',
        'total_pages': 89,
        'is_premium': false,
        'is_active': true,
        'views_count': 234,
        'downloads_count': 123,
        'created_at': '2025-01-10T11:15:00Z',
        'updated_at': '2025-01-10T11:15:00Z',
        'categories': {'id': 'ee66c3d9-74e4-44dd-8761-62ea489b10fb', 'name': 'Akhlak & Tasawuf'}
      },
      {
        'id': '550e8400-e29b-41d4-a716-446655440007',
        'title': 'Belajar Bahasa Arab Asas',
        'author': 'Ustaz Omar Yusof',
        'description': 'Buku panduan asas untuk mempelajari bahasa Arab dengan kaedah yang mudah dan berkesan. Termasuk latihan dan contoh ayat.',
        'category_id': '600baa07-f492-4df1-af75-3127ea151d28',
        'pdf_url': 'https://storage.supabase.co/ebooks/bahasa-arab-asas.pdf',
        'thumbnail_url': 'https://storage.supabase.co/thumbnails/bahasa-arab-asas.jpg',
        'total_pages': 167,
        'is_premium': true,
        'is_active': true,
        'views_count': 189,
        'downloads_count': 95,
        'created_at': '2025-01-09T13:40:00Z',
        'updated_at': '2025-01-09T13:40:00Z',
        'categories': {'id': '600baa07-f492-4df1-af75-3127ea151d28', 'name': 'Bahasa Arab'}
      }
    ];
  }
  
  static List<Map<String, dynamic>> getCategories() {
    return [
      {'id': 'e1166e04-4f53-4d1a-87b6-e71af547d896', 'name': 'Quran & Tafsir'},
      {'id': '25004d73-6445-418e-9726-4e1022ff5309', 'name': 'Hadis & Sunnah'},
      {'id': 'a39016be-df7a-44a0-859e-7caaa32d8732', 'name': 'Fiqh'},
      {'id': '49819bc9-abaf-4196-8854-e12147c440de', 'name': 'Sirah'},
      {'id': '6e69d652-58b7-4376-b416-a5672f0f7c94', 'name': 'Akidah'},
      {'id': 'ee66c3d9-74e4-44dd-8761-62ea489b10fb', 'name': 'Akhlak & Tasawuf'},
      {'id': '600baa07-f492-4df1-af75-3127ea151d28', 'name': 'Bahasa Arab'}
    ];
  }
}
