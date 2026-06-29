import 'dart:ui' show TextDirection;

class AppLocalizations {
  final String locale;
  AppLocalizations(this.locale);

  static String _currentLocale = 'ar';
  static void setLocale(String locale) => _currentLocale = locale;
  static AppLocalizations get current => AppLocalizations(_currentLocale);

  static const Map<String, Map<String, String>> _translations = {
    // عام
    'app_name': {'ar': 'SFRE', 'en': 'My Bus'},
    'ok': {'ar': 'موافق', 'en': 'OK'},
    'cancel': {'ar': 'إلغاء', 'en': 'Cancel'},
    'save': {'ar': 'حفظ', 'en': 'Save'},
    'delete': {'ar': 'حذف', 'en': 'Delete'},
    'edit': {'ar': 'تعديل', 'en': 'Edit'},
    'error': {'ar': 'حدث خطأ', 'en': 'An error occurred'},
    'loading': {'ar': 'جاري التحميل...', 'en': 'Loading...'},
    'no_data': {'ar': 'لا يوجد بيانات', 'en': 'No data'},
    'retry': {'ar': 'إعادة المحاولة', 'en': 'Retry'},
    'success': {'ar': 'تم بنجاح', 'en': 'Success'},
    'close': {'ar': 'إغلاق', 'en': 'Close'},
    'done': {'ar': 'تم', 'en': 'Done'},
    'try_again': {'ar': 'حاول مرة ثانية', 'en': 'Try again'},
    'send': {'ar': 'إرسال', 'en': 'Send'},
    'select': {'ar': 'اختر', 'en': 'Select'},

    // تسجيل الدخول
    'login': {'ar': 'تسجيل الدخول', 'en': 'Login'},
    'register': {'ar': 'إنشاء حساب', 'en': 'Register'},
    'email': {'ar': 'البريد الإلكتروني', 'en': 'Email'},
    'password': {'ar': 'كلمة المرور', 'en': 'Password'},
    'phone': {'ar': 'رقم الهاتف', 'en': 'Phone Number'},
    'username': {'ar': 'اسم المستخدم', 'en': 'Username'},
    'logout': {'ar': 'تسجيل الخروج', 'en': 'Logout'},
    'change_password': {'ar': 'تغيير كلمة المرور', 'en': 'Change Password'},
    'old_password': {'ar': 'كلمة المرور القديمة', 'en': 'Old Password'},
    'new_password': {'ar': 'كلمة المرور الجديدة', 'en': 'New Password'},
    'login_as_driver': {'ar': 'دخول كسائق', 'en': 'Login as Driver'},
    'login_as_passenger': {'ar': 'دخول كراكب', 'en': 'Login as Passenger'},
    'no_account': {'ar': 'ما عندك حساب؟', 'en': "Don't have an account?"},
    'have_account': {'ar': 'عندك حساب؟', 'en': 'Already have an account?'},

    // الصفحة الرئيسية
    'home': {'ar': 'الرئيسية', 'en': 'Home'},
    'search': {'ar': 'البحث', 'en': 'Search'},
    'map': {'ar': 'الخريطة', 'en': 'Map'},
    'profile': {'ar': 'حسابي', 'en': 'Profile'},
    'settings': {'ar': 'الإعدادات', 'en': 'Settings'},
    'hello_user': {'ar': 'أهلاً،', 'en': 'Hello,'},
    'where_to_go': {'ar': 'إلى أين تريد الذهاب؟', 'en': 'Where do you want to go?'},
    'search_destination': {'ar': 'ابحث عن وجهتك...', 'en': 'Search your destination...'},
    'search_hint': {'ar': 'حدد وجهتك ؟', 'en': 'Where are you going?'},
    'scan_qr': {'ar': 'مسح QR', 'en': 'Scan QR'},
    'my_trips': {'ar': 'رحلاتي', 'en': 'My Trips'},
    'the_map': {'ar': 'الخريطة', 'en': 'Map'},
    'lost_items': {'ar': 'مفقودات', 'en': 'Lost Items'},
    'report': {'ar': 'إبلاغ', 'en': 'Report'},
    'subscription': {'ar': 'اشتراكي', 'en': 'Subscription'},
    'recent_trips': {'ar': 'آخر رحلاتك', 'en': 'Recent Trips'},
    'no_trips_yet': {'ar': 'ابدأ رحلتك الأولى', 'en': 'Start your first trip'},
    'no_trips_desc': {'ar': 'امسح رمز QR عند ركوب الباص', 'en': 'Scan QR code when boarding'},

    // البحث
    'search_title': {'ar': 'البحث عن وجهتك', 'en': 'Find Your Destination'},
    'your_location': {'ar': 'موقعك الحالي', 'en': 'Your Location'},
    'detecting_location': {'ar': 'جاري تحديد الموقع...', 'en': 'Detecting location...'},
    'search_empty': {'ar': 'ابحث عن وجهتك', 'en': 'Search your destination'},
    'search_empty_desc': {'ar': 'اكتب اسم المكان الذي تريد الذهاب اليه  ', 'en': 'Type the place name'},
    'no_routes_found': {'ar': 'لا يوجد  خطوط تصل إلى وجهتك', 'en': 'No routes found'},
    'try_another': {'ar': 'جرّب اسم ثاني', 'en': 'Try another name'},
    'direct_trip': {'ar': 'رحلة مباشرة', 'en': 'Direct Trip'},
    'transfer_trip': {'ar': 'رحلة بتحويل', 'en': 'Transfer Trip'},
    'best': {'ar': 'الأفضل', 'en': 'Best'},
    'minutes': {'ar': 'دقيقة', 'en': 'min'},
    'walk_to_stop': {'ar': 'امشِ {m} متر لأقرب موقف', 'en': 'Walk {m}m to nearest stop'},
    'ride_bus': {'ar': 'اركب الباص', 'en': 'Ride the bus'},
    'walk_to_transfer': {'ar': 'امشِ للموقف', 'en': 'Walk to stop'},
    'from_to': {'ar': 'من {f} إلى {t}', 'en': 'From {f} to {t}'},
    'stations_minutes': {'ar': '{s} محطات \u2022 {m} دقيقة', 'en': '{s} stops \u2022 {m} min'},
    'active_buses': {'ar': '{n} باص نشط', 'en': '{n} active'},
    'walk_meters_min': {'ar': '{m} متر • {n} دقيقة مشي', 'en': '{m}m • {n} min walk'},
    'cant_detect_location': {'ar': 'لم نستطع تحديد موقعك', 'en': 'Could not detect location'},
    'no_buses_on_route': {'ar': 'لا يوجد باصات نشطة حالياً على هذا الخط', 'en': 'No active buses on this route'},
    'bus_eta': {'ar': 'أقرب باص بعد ~{m} دقيقة', 'en': 'Next bus in ~{m} min'},
    'guide_me': {'ar': 'وجّهني', 'en': 'Navigate'},

    // الاشتراك
    'my_subscription': {'ar': 'اشتراكي', 'en': 'My Subscription'},
    'no_subscription': {'ar': 'لا يوجد اشتراك فعّال', 'en': 'No active subscription'},
    'buy_from_pos': {'ar': 'اشترِ من أقرب نقطة بيع', 'en': 'Buy from nearest POS'},
    'nearest_pos': {'ar': 'أقرب نقاط البيع', 'en': 'Nearest POS'},
    'trips_remaining': {'ar': 'الرحلات المتبقية', 'en': 'Remaining'},
    'trips_used': {'ar': 'مستخدمة', 'en': 'Used'},
    'trips_total': {'ar': 'الإجمالي', 'en': 'Total'},
    'valid_until': {'ar': 'صالح حتى', 'en': 'Valid until'},
    'family_members': {'ar': 'أفراد العائلة', 'en': 'Family Members'},
    'add_member': {'ar': 'إضافة عضو', 'en': 'Add Member'},
    'member_email': {'ar': 'إيميل العضو الجديد', 'en': 'New member email'},
    'no_members_yet': {'ar': 'ما في أفراد مضافين بعد', 'en': 'No members added yet'},
    'view_plans': {'ar': 'عرض خطط الاشتراك', 'en': 'View Plans'},
    'sub_plans': {'ar': 'خطط الاشتراك', 'en': 'Subscription Plans'},

    // الخريطة
    'track_stop': {'ar': 'تنبيهني عند الوصول', 'en': 'Alert on arrival'},
    'cancel_tracking': {'ar': 'إلغاء التنبيه', 'en': 'Cancel alert'},
    'track_destination': {'ar': 'نبّهني لما الباص يوصل هون', 'en': 'Alert when bus arrives'},
    'cancel_dest_tracking': {'ar': 'إلغاء تتبع الوجهة', 'en': 'Cancel tracking'},
    'approaching_stop': {'ar': 'اقتربت من موقفك!', 'en': 'Approaching your stop!'},
    'approaching_dest': {'ar': 'اقتربت من وجهتك!', 'en': 'Approaching destination!'},

    // الإشعارات
    'notifications': {'ar': 'الإشعارات', 'en': 'Notifications'},
    'no_notifications': {'ar': 'ما في إشعارات', 'en': 'No notifications'},
    'new_notification': {'ar': 'إشعار جديد', 'en': 'New notification'},

    // البلاغات
    'report_problem': {'ar': 'إبلاغ عن مشكلة', 'en': 'Report a Problem'},
    'select_bus': {'ar': 'اختر الباص', 'en': 'Select Bus'},
    'please_select_bus': {'ar': 'الرجاء اختيار الباص', 'en': 'Please select a bus'},
    'describe_problem': {'ar': 'اشرح المشكلة بالتفصيل...', 'en': 'Describe the problem...'},
    'send_report': {'ar': 'إرسال التقرير', 'en': 'Send Report'},

    // المفقودات
    'lost_found': {'ar': 'المفقودات', 'en': 'Lost & Found'},
    'report_lost': {'ar': 'الإبلاغ عن مفقودات', 'en': 'Report Lost Item'},
    'report_found': {'ar': 'الإبلاغ عن غرض موجود', 'en': 'Report Found Item'},
    'item_desc': {'ar': 'وصف الغرض', 'en': 'Item Description'},
    'choose_from_trips': {'ar': 'اختر من آخر رحلاتك:', 'en': 'Choose from recent trips:'},
    'or_choose_list': {'ar': 'أو اختر من القائمة:', 'en': 'Or choose from list:'},
    'item_photo': {'ar': 'صورة الغرض (اختياري)', 'en': 'Item Photo (optional)'},
    'tap_add_photo': {'ar': 'اضغط لإضافة صورة', 'en': 'Tap to add photo'},
    'camera': {'ar': 'الكاميرا', 'en': 'Camera'},
    'gallery': {'ar': 'المعرض', 'en': 'Gallery'},
    'choose_image_source': {'ar': 'اختر مصدر الصورة', 'en': 'Choose Image Source'},
    'send_report_btn': {'ar': 'إرسال البلاغ', 'en': 'Send Report'},
    'report_item': {'ar': 'إبلاغ عن الغرض', 'en': 'Report Item'},

    // QR
    'scan_qr_title': {'ar': 'مسح QR للركوب', 'en': 'Scan QR to Board'},
    'boarding_success': {'ar': 'تم الركوب بنجاح! 🎉', 'en': 'Boarded Successfully! 🎉'},
    'route_label': {'ar': 'خط:', 'en': 'Route:'},
    'subscribe_now': {'ar': 'اشترك الآن', 'en': 'Subscribe Now'},

    // المفضلة
    'my_favorites': {'ar': 'وجهاتي المفضلة', 'en': 'My Favorites'},
    'search_for_dest': {'ar': 'ابحث عن وجهة', 'en': 'Search destination'},

    // السائق
    'driver_home': {'ar': 'لوحة السائق', 'en': 'Driver Panel'},
    'start_shift': {'ar': 'بدء الدوام', 'en': 'Start Shift'},
    'end_shift': {'ar': 'إنهاء الدوام', 'en': 'End Shift'},
    'stop_shift': {'ar': 'إيقاف الدوام', 'en': 'Stop Shift'},
    'on_duty': {'ar': 'بالخدمة', 'en': 'On Duty'},
    'off_duty': {'ar': 'خارج الخدمة', 'en': 'Off Duty'},
    'report_delay': {'ar': 'تنبيه تأخير', 'en': 'Report Delay'},
    'request_extra_bus': {'ar': 'طلب باص إضافي', 'en': 'Request Extra Bus'},
    'report_issue': {'ar': 'إبلاغ عطل', 'en': 'Report Issue'},
    'my_shifts': {'ar': 'ورديات', 'en': 'Shifts'},
    'no_shifts': {'ar': 'ما في ورديات مجدولة', 'en': 'No scheduled shifts'},
    'confirm_stop': {'ar': 'تأكيد الإيقاف', 'en': 'Confirm Stop'},
    'undo_stop': {'ar': 'تراجع — أنا بالغلط', 'en': 'Undo — My mistake'},
    'bus_maintenance': {'ar': 'الباص بالصيانة — تواصل مع الإدارة', 'en': 'Bus in maintenance — contact admin'},
    'bus_breakdown': {'ar': 'الباص معطّل — تواصل مع الإدارة', 'en': 'Bus broken down — contact admin'},
    'no_shift_assigned': {'ar': 'ما فيك تبدأ — ما في وردية', 'en': 'Cannot start — no shift assigned'},
    'connected': {'ar': 'أنت متصل', 'en': 'Connected'},
    'send_request': {'ar': 'إرسال الطلب', 'en': 'Send Request'},
    'note_optional': {'ar': 'ملاحظة (اختياري)', 'en': 'Note (optional)'},

    // الإعدادات
    'language': {'ar': 'اللغة', 'en': 'Language'},
    'dark_mode': {'ar': 'الوضع الليلي', 'en': 'Dark Mode'},
    'light_mode': {'ar': 'الوضع النهاري', 'en': 'Light Mode'},
    'appearance': {'ar': 'المظهر', 'en': 'Appearance'},
    'account': {'ar': 'الحساب', 'en': 'Account'},
    'version': {'ar': 'الإصدار', 'en': 'Version'},
    'arabic': {'ar': 'العربية', 'en': 'Arabic'},
    'english': {'ar': 'English', 'en': 'English'},
    'edit_profile': {'ar': 'تعديل الحساب', 'en': 'Edit Profile'},

    // إضافات شاملة
    'delete_confirm': {'ar': 'حذف؟', 'en': 'Delete?'},
    'welcome': {'ar': 'أهلاً بك!', 'en': 'Welcome!'},
    'login_continue': {'ar': 'سجّل دخولك للمتابعة', 'en': 'Login to continue'},
    'login_as_driver_desc': {'ar': 'سجّل دخولك كسائق', 'en': 'Login as driver'},
    'wrong_credentials': {'ar': 'بيانات الدخول غلط', 'en': 'Wrong credentials'},
    'register_now': {'ar': 'سجّل الآن', 'en': 'Register now'},
    'create_account': {'ar': 'إنشاء الحساب', 'en': 'Create Account'},
    'wrong_old_password': {'ar': 'كلمة المرور القديمة غلط', 'en': 'Wrong old password'},
    'edit_data': {'ar': 'تعديل البيانات', 'en': 'Edit Data'},
    'save_changes': {'ar': 'حفظ التغييرات', 'en': 'Save Changes'},
    'leave_empty_no_change': {'ar': 'اتركه فاضي إذا ما بدك تغير', 'en': 'Leave empty to keep current'},
    'trip_history_title': {'ar': 'سجل رحلاتي', 'en': 'My Trip History'},
    'scan_qr_to_appear': {'ar': 'لما تركب باص وتمسح QR رح تطلع هون', 'en': 'Board a bus and scan QR to see trips here'},
    'boarding': {'ar': 'ركوب', 'en': 'Board'},
    'exit': {'ar': 'نزول', 'en': 'Exit'},
    'trip_active': {'ar': 'رحلة جارية', 'en': 'Active Trip'},
    'pos_stations': {'ar': 'نقاط الشحن والتجديد', 'en': 'POS Stations'},
    'call': {'ar': 'اتصال', 'en': 'Call'},
    'directions': {'ar': 'الاتجاهات', 'en': 'Directions'},
    'the_map_title': {'ar': 'الخريطة', 'en': 'Map'},
    'cancel_dest_done': {'ar': 'تم إلغاء تتبع الوجهة', 'en': 'Destination tracking cancelled'},
    'no_bus_on_route': {'ar': 'ما في باص نشط على هالخط حالياً', 'en': 'No active bus on this route'},
    'hello_driver': {'ar': 'أهلاً،', 'en': 'Hello,'},
    'driver_default': {'ar': 'سائق', 'en': 'Driver'},
    'user_default': {'ar': 'مستخدم', 'en': 'User'},
    'online': {'ar': 'متصل', 'en': 'Online'},
    'offline': {'ar': 'غير متصل', 'en': 'Offline'},
    'tap_to_stop': {'ar': 'اضغط للتوقف عن العمل', 'en': 'Tap to stop working'},
    'tap_to_start': {'ar': 'اضغط لبدء العمل', 'en': 'Tap to start working'},
    'report_delay_title': {'ar': 'إبلاغ عن تأخير', 'en': 'Report Delay'},
    'how_many_min': {'ar': 'كم دقيقة رح تتأخر؟', 'en': 'How many minutes delay?'},
    'reason': {'ar': 'السبب:', 'en': 'Reason:'},
    'report_breakdown': {'ar': 'إبلاغ عن عطل', 'en': 'Report Breakdown'},
    'breakdown_type': {'ar': 'نوع العطل:', 'en': 'Breakdown type:'},
    'report_btn': {'ar': 'إبلاغ', 'en': 'Report'},
    'error_undo': {'ar': 'حدث خطأ بالتراجع', 'en': 'Error undoing'},
    'sub_label': {'ar': 'الاشتراك', 'en': 'Subscription'},
    'trips_label': {'ar': 'الرحلات', 'en': 'Trips'},
    'expires_in': {'ar': 'ينتهي في', 'en': 'Expires'},
    'sub_remaining': {'ar': 'باقي على انتهاء اشتراكك', 'en': 'Until subscription expires'},
    'trips_used_label': {'ar': 'الرحلات المستخدمة', 'en': 'Trips Used'},
    'manage_family': {'ar': 'إدارة أفراد العائلة', 'en': 'Manage Family Members'},
    'pos_renew': {'ar': 'نقاط الشحن والتجديد', 'en': 'POS & Renewal'},
    'route_details': {'ar': 'تفاصيل الخط', 'en': 'Route Details'},
    'detecting_your_loc': {'ar': 'جاري تحديد موقعك...', 'en': 'Detecting your location...'},
    'alert_cancelled': {'ar': 'تم إلغاء التنبيه', 'en': 'Alert cancelled'},
    'bus_label': {'ar': 'باص', 'en': 'Bus'},
  };

  String tr(String key, [Map<String, String>? params]) {
    String text = _translations[key]?[locale] ?? _translations[key]?['ar'] ?? key;
    if (params != null) {
      params.forEach((k, v) => text = text.replaceAll('{$k}', v));
    }
    return text;
  }

  String t(String key, [Map<String, String>? params]) => tr(key, params);

  TextDirection get textDirection =>
      locale == 'ar' ? TextDirection.rtl : TextDirection.ltr;
}
