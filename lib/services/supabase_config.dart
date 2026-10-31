/// تنظیمات Supabase — فقط کلیدِ عمومی (publishable) اینجا می‌آید.
/// کلیدِ secret را هرگز داخل برنامه نگذار.
const String kSupabaseUrl = 'https://uxrghzclmgfcgwdaghvd.supabase.co';
const String kSupabaseAnonKey = 'sb_publishable_MUR0vJZld-1DHpm3OSvEpw_2Z9rH89R';

/// آدرسِ برگشت بعد از ورود با Google (فقط اندروید/iOS). باید در Supabase هم ثبت شود.
const String kAuthRedirect = 'io.supabase.maghz://login-callback/';

bool get supabaseConfigured =>
    kSupabaseUrl.isNotEmpty && kSupabaseAnonKey.isNotEmpty;
