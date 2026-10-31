/// تنظیمات Supabase — این دو مقدار را از Supabase › Project Settings › API بردار.
/// (کلیدِ anon عمومی است و گذاشتنش داخل برنامه مشکلی ندارد؛ service_role را هرگز اینجا نگذار.)
const String kSupabaseUrl = '';
const String kSupabaseAnonKey = '';

/// آدرسِ برگشت بعد از ورود با Google (فقط اندروید/iOS). باید در Supabase هم ثبت شود.
const String kAuthRedirect = 'io.supabase.maghz://login-callback/';

bool get supabaseConfigured =>
    kSupabaseUrl.isNotEmpty && kSupabaseAnonKey.isNotEmpty;
