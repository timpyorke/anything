import 'app_strings.dart';

class ThStrings extends AppStrings {
  const ThStrings();

  @override
  AppLanguage get language => AppLanguage.th;

  // ── วันที่และเวลา
  @override
  List<String> get monthsShort => const ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
  @override
  List<String> get monthsLong => const ['มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'];
  @override
  List<String> get weekdays => const ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];
  @override
  List<String> get heatmapWeekdays => const ['', 'จ', '', 'พ', '', 'ศ', ''];
  @override
  int displayYear(int year) => year + 543;
  @override
  String yearLabel(int year) => 'พ.ศ. ${displayYear(year)}';
  @override
  String get today => 'วันนี้';
  @override
  String get tomorrow => 'พรุ่งนี้';
  @override
  String get ongoing => 'กำลังดำเนินอยู่';
  @override
  String inDays(int n) => 'อีก $n วัน';
  @override
  String inMonths(int n) => 'อีก ~$n เดือน';

  // ── ใช้ร่วมกัน
  @override
  String get appTagline => 'บันทึกชีวิตด้วย AI';
  @override
  String get cancel => 'ยกเลิก';
  @override
  String get close => 'ปิด';
  @override
  String get save => 'บันทึก';
  @override
  String get delete => 'ลบ';
  @override
  String get edit => 'แก้ไข';
  @override
  String get send => 'ส่ง';
  @override
  String get retry => 'ลองใหม่';
  @override
  String get later => 'ไว้ก่อน';
  @override
  String get goToSettings => 'ไปตั้งค่า';
  @override
  String get download => 'ดาวน์โหลด';
  @override
  String get camera => 'กล้อง';
  @override
  String get gallery => 'คลังรูป';
  @override
  String get photos => 'รูปภาพ';
  @override
  String saveFailed(Object error) => 'บันทึกไม่สำเร็จ: $error';
  @override
  String deleteFailed(Object error) => 'ลบไม่สำเร็จ: $error';

  // ── เข้าสู่ระบบ
  @override
  String get email => 'อีเมล';
  @override
  String get password => 'รหัสผ่าน';
  @override
  String get passwordHint => 'อย่างน้อย 8 ตัวอักษร';
  @override
  String get showPassword => 'แสดงรหัสผ่าน';
  @override
  String get hidePassword => 'ซ่อนรหัสผ่าน';
  @override
  String get createAccount => 'สร้างบัญชี';
  @override
  String get signIn => 'เข้าสู่ระบบ';
  @override
  String get switchToSignIn => 'มีบัญชีแล้ว? เข้าสู่ระบบ';
  @override
  String get switchToSignUp => 'ยังไม่มีบัญชี? สร้างบัญชี';
  @override
  String get credentialsRequired => 'ใส่อีเมล และรหัสผ่านอย่างน้อย 8 ตัวอักษร';
  @override
  String confirmationSent(String email) => 'ส่งอีเมลยืนยันไปที่ $email แล้ว — ยืนยันแล้วกลับมาเข้าสู่ระบบ';
  @override
  String get invalidCredentials => 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
  @override
  String get emailNotConfirmed => 'ยังไม่ได้ยืนยันอีเมล — ตรวจกล่องจดหมาย';
  @override
  String get userAlreadyExists => 'อีเมลนี้มีบัญชีแล้ว — เข้าสู่ระบบแทน';
  @override
  String get weakPassword => 'รหัสผ่านง่ายเกินไป';
  @override
  String connectionFailed(Object error) => 'เชื่อมต่อไม่ได้: $error';
  @override
  String get orDivider => 'หรือ';
  @override
  String continueWith(String provider) => 'ดำเนินการต่อด้วย $provider';
  @override
  String socialSignInFailed(String provider, Object error) => 'เข้าสู่ระบบด้วย $provider ไม่สำเร็จ: $error';
  @override
  String get signupDisabled => 'ปิดรับสมัครบัญชีใหม่ — ใช้บัญชีที่มีอยู่แล้ว';

  // ── Timeline และการ์ดรายการ
  @override
  String get search => 'ค้นหา';
  @override
  String get overview => 'ภาพรวม';
  @override
  String get settings => 'ตั้งค่า';
  @override
  String get refreshFailed => 'โหลดข้อมูลล่าสุดไม่สำเร็จ';
  @override
  String get loadFailed => 'โหลดข้อมูลไม่สำเร็จ';
  @override
  String get noFilterMatches => 'ไม่พบรายการที่ตรงกับตัวกรอง';
  @override
  String get todayEmpty => 'ยังไม่ได้บันทึก พิมพ์หรือกดไมค์เล่าให้ AI ฟังได้เลย';
  @override
  String get entryExamples => 'เช่น “วิ่งมา 5 กม.” หรือ “ศุกร์หน้านัดหมอ”';
  @override
  String get earlier => 'ก่อนหน้านี้';
  @override
  String itemCount(int n) => '$n รายการ';
  @override
  String get clearFilter => 'ล้างตัวกรอง';
  @override
  String get upcoming => 'กำลังจะมาถึง';
  @override
  String allCount(int n) => 'ทั้งหมด $n';
  @override
  String get noUpcoming => 'ไม่มีรายการล่วงหน้า';
  @override
  String get noUpcomingDetail => 'นัดหมายหรือแผนที่บันทึกไว้จะแสดงที่นี่';
  @override
  String occurrencesDone(int done) => 'ครบ $done ครั้ง';
  @override
  String occurrenceOpen(int done) => 'ครั้งที่ ${done + 1} · ผ่านไป $done ครั้ง';
  @override
  String occurrenceOf(int done, int total, String last) => 'ครั้งที่ ${done + 1}/$total · ครั้งสุดท้าย $last';
  @override
  String progressLabel(int done, int total) => 'ความคืบหน้า $done จาก $total ครั้ง';
  @override
  String metricEach(String label, String value, String unit) => '$label ครั้งละ $value $unit';
  @override
  String metricTotal(String value, String unit) => 'สะสม $value $unit';
  @override
  String metricRemaining(String value, String unit) => 'คงเหลือ $value $unit';
  @override
  String get deleted => 'ลบแล้ว';
  @override
  String get deletedSeries => 'ลบรายการที่เกิดซ้ำทั้งชุดแล้ว';
  @override
  String get undo => 'เลิกทำ';
  @override
  String undoFailed(Object error) => 'เลิกทำไม่สำเร็จ: $error';

  // ── การเกิดซ้ำ
  @override
  String get everyDay => 'ทุกวัน';
  @override
  String get everyWeek => 'ทุกสัปดาห์';
  @override
  String get everyMonth => 'ทุกเดือน';
  @override
  String get everyYear => 'ทุกปี';
  @override
  String everyN(int n, String unit) => 'ทุก $n ${const {'d': 'วัน', 'w': 'สัปดาห์', 'm': 'เดือน', 'y': 'ปี'}[unit]}';

  // ── ค้นหาและภาพรวม
  @override
  String get searchHint => 'ค้นหาชื่อ เนื้อหา หมวด…';
  @override
  String get clearSearch => 'ล้างคำค้น';
  @override
  String get searchPrompt => 'พิมพ์คำที่ต้องการค้นหา';
  @override
  String get orPickCategory => 'หรือเลือกหมวด';
  @override
  String get noSearchResults => 'ไม่พบรายการที่ตรงกับคำค้น';
  @override
  String get noSearchResultsDetail => 'ลองใช้คำที่สั้นลง หรือค้นด้วยชื่อหมวด';
  @override
  String foundCount(int n) => 'พบ $n รายการ';
  @override
  String age(int years) => 'อายุ $years ปี';
  @override
  String dayCount(int n) => '$n วัน';
  @override
  String daysLogged(String year) => 'วันที่มีบันทึก ($year)';
  @override
  String get bestStreak => 'บันทึกต่อเนื่องนานสุด';
  @override
  String get totalEntries => 'รายการทั้งหมด';
  @override
  String get plannedAhead => 'มีแผนล่วงหน้า';
  @override
  String get activityCalendar => 'ปฏิทินกิจกรรม';
  @override
  String get tapDayHint => 'แตะวันที่มีสีเพื่อดูบันทึกของวันนั้น';
  @override
  String get byCategory => 'แยกตามหมวด';
  @override
  String heatmapSummary(int year, int days) => 'ปฏิทินกิจกรรมปี ${displayYear(year)}: มีบันทึก $days วัน';
  @override
  String get logged => 'มีบันทึก';
  @override
  String get planned => 'แผนล่วงหน้า';

  // ── หน้าแก้ไขรายการ
  @override
  String get deleteEntryTitle => 'ลบรายการนี้?';
  @override
  String get deleteSeriesWarning => 'รายการที่เกิดซ้ำจะถูกลบทั้งชุด';
  @override
  String get discardTitle => 'ทิ้งการแก้ไข?';
  @override
  String get discardMessage => 'สิ่งที่แก้ไว้ยังไม่ได้บันทึก';
  @override
  String get keepEditing => 'แก้ต่อ';
  @override
  String get discard => 'ทิ้ง';
  @override
  String get startDate => 'เริ่ม';
  @override
  String get date => 'วันที่';
  @override
  String get endDateOptional => 'ถึง (ถ้ามี)';
  @override
  String get reviewEntry => 'ตรวจก่อนบันทึก';
  @override
  String get newEntry => 'เพิ่มบันทึก';
  @override
  String get kindEvent => 'เหตุการณ์';
  @override
  String get kindDaily => 'บันทึกรายวัน';
  @override
  String get titleField => 'ชื่อ';
  @override
  String get titleHint => 'เกิดอะไรขึ้น';
  @override
  String get details => 'รายละเอียด';
  @override
  String get detailsHint => 'เล่าต่อได้เลย';
  @override
  String get markdownHelp => 'ขึ้นต้น “- ” เป็นรายการ, “- [ ] ” เป็นช่องติ๊ก, **ข้อความ** เป็นตัวหนา';
  @override
  String get category => 'หมวด';
  @override
  String get takePhoto => 'ถ่ายรูป';
  @override
  String get numbers => 'ตัวเลข';
  @override
  String get removeNumber => 'เอาออก';
  @override
  String get addNumber => 'เพิ่มตัวเลข';
  @override
  String get repeats => 'เกิดซ้ำ';
  @override
  String get noRepeat => 'ไม่เกิดซ้ำ';
  @override
  String get unlimited => 'ไม่จำกัด';
  @override
  String get timesSuffix => 'ครั้ง';
  @override
  String endsOn(String date) => 'สิ้นสุด $date';
  @override
  String get removeEndDate => 'เอาวันสิ้นสุดออก';
  @override
  String importedFrom(String ref) => 'นำเข้าจาก $ref';
  @override
  String get clearDate => 'ล้างวันที่';
  @override
  String get pickDate => 'เลือกวันที่';

  // ── ตรวจความถูกต้องของรายการ
  @override
  String yearLooksBuddhist(int year) => 'ปี $year ดูเหมือนเป็น พ.ศ. — ใช้ ค.ศ.';
  @override
  String unknownCategory(String key) => 'ไม่มีหมวด "$key"';
  @override
  String get endNotAfterStart => 'วันสิ้นสุดต้องอยู่หลังวันเริ่ม';
  @override
  String get dailyNoRange => 'บันทึกรายวันใช้ช่วงวันที่/เกิดซ้ำไม่ได้';
  @override
  String invalidRecurrence(String every) => 'รูปแบบการเกิดซ้ำไม่ถูกต้อง: $every';
  @override
  String get recurringNoRange => 'รายการที่เกิดซ้ำใช้ช่วงวันที่ไม่ได้';
  @override
  String get timesOutOfRange => 'จำนวนครั้งต้องอยู่ระหว่าง 1–1000';
  @override
  String get untilBeforeStart => 'วันสิ้นสุดการเกิดซ้ำต้องไม่ก่อนวันเริ่ม';
  @override
  String unknownMetric(String key) => 'ไม่มี metric "$key"';
  @override
  String notANumber(String key) => 'ค่า $key ไม่ใช่ตัวเลข';
  @override
  String get entryEmpty => 'ต้องมีชื่อ เนื้อหา รูป หรือตัวเลขอย่างน้อยหนึ่งอย่าง';
  @override
  String tooManyPhotos(int max) => 'แนบรูปได้ไม่เกิน $max รูปต่อรายการ';

  // ── รูปภาพ
  @override
  String get photoLoadFailed => 'โหลดรูปไม่ได้ แตะเพื่อลองใหม่';
  @override
  String photoPosition(int index, int total) => 'รูปที่ $index จาก $total';
  @override
  String get removePhoto => 'เอารูปออก';
  @override
  String get photoLimitReached => 'แนบรูปได้ไม่เกินนี้แล้ว เอารูปเดิมออกก่อน';
  @override
  String get cameraDenied => 'ใช้กล้องไม่ได้ ตรวจสิทธิ์ในการตั้งค่าเครื่อง';
  @override
  String get galleryDenied => 'เปิดคลังรูปไม่ได้ ตรวจสิทธิ์ในการตั้งค่าเครื่อง';
  @override
  String photoOpenFailed(Object error) => 'เปิดรูปไม่ได้: $error';
  @override
  String get photosUnusable => 'บางรูปใช้ไม่ได้ (รองรับ JPEG, PNG, WebP, GIF ขนาดไม่เกิน 5 MB)';
  @override
  String photosOverRoom(int room) => 'เพิ่มได้อีก $room รูป ที่เหลือไม่ได้แนบ';

  // ── กล่องพิมพ์ เสียง และผู้ช่วย
  @override
  String get composerHint => 'เล่าอะไรก็ได้…';
  @override
  String get speak => 'พูด';
  @override
  String get recording => 'กำลังอัดเสียง…';
  @override
  String recordingLeft(int seconds) => 'เหลือ $seconds วินาที · ครบแล้วส่งให้เอง';
  @override
  String get stopAndSend => 'หยุดและส่ง';
  @override
  String get transcribing => 'กำลังถอดเสียงในเครื่อง…';
  @override
  String get noSpeech => 'ไม่ได้ยินเสียง แตะไมค์แล้วพูดใหม่ได้เลย';
  @override
  String get micDenied => 'ใช้ไมโครโฟนไม่ได้ ตรวจสิทธิ์ในการตั้งค่าเครื่อง';
  @override
  String micFailed(Object error) => 'เปิดไมโครโฟนไม่ได้: $error';
  @override
  String transcribeFailed(Object error) => 'ถอดเสียงไม่สำเร็จ: $error';
  @override
  String get assistantTitle => 'ผู้ช่วยบันทึก';
  @override
  String savedCount(int n) => 'บันทึกแล้ว $n รายการ';
  @override
  String get aiNotSetUp => 'ยังไม่ได้ตั้งค่า AI';
  @override
  String needApiKey(String service) => 'ใส่ API key ของ $service ในหน้าตั้งค่าก่อน';
  @override
  String needLocalModel(String size) => 'ดาวน์โหลดโมเดล Gemma ($size) ในหน้าตั้งค่าก่อน';
  @override
  String get noVoiceModel => 'ยังไม่มีโมเดลฟังเสียง';
  @override
  String needVoiceModel(String size) => 'ดาวน์โหลดโมเดล Gemma ($size) ในหน้าตั้งค่าก่อน เสียงจะถูกถอดเป็นข้อความในเครื่อง';
  @override
  String get aiThinking => 'AI กำลังคิด…';
  @override
  String get nothingSaved => 'ยังไม่มีอะไรถูกบันทึก';
  @override
  String unattachedPhotos(int n) => 'รูป $n รูปไม่ได้แนบกับรายการที่เลือก จะไม่ถูกเก็บ';
  @override
  String get saved => 'บันทึกแล้ว';
  @override
  String saveCount(int n) => 'บันทึก $n รายการ';
  @override
  String get answerHint => 'ตอบคำถาม…';
  @override
  String get followUpHint => 'บอกเพิ่มหรือแก้…';
  @override
  String get editBeforeSaving => 'แก้ก่อนบันทึก';
  @override
  String unexpectedError(Object error) => 'เกิดข้อผิดพลาด: $error';
  @override
  String someSavesFailed(String failures) => 'บางรายการบันทึกไม่สำเร็จ:\n$failures';
  @override
  String attachedPhotosLog(int n) => '[แนบรูป $n รูป]';

  // ── ข้อเสนอของ AI (recorder)
  @override
  String get aiUnreadable => 'AI ตอบกลับในรูปแบบที่อ่านไม่ได้ ลองพิมพ์ใหม่อีกครั้ง';
  @override
  String unknownCommand(Object? type) => 'คำสั่งที่ไม่รู้จัก: $type';
  @override
  String get unsupported => 'ไม่รองรับ';
  @override
  String get reviewBelow => 'ตรวจรายการด้านล่างก่อนบันทึก';
  @override
  String get needMoreInfo => 'ขอข้อมูลเพิ่มอีกนิด';
  @override
  String get noAnswer => 'ยังไม่มีคำตอบ ลองพิมพ์ใหม่อีกครั้ง';
  @override
  String get invalidCategoryKey => 'ชื่อ key ของหมวดต้องเป็นภาษาอังกฤษตัวเล็ก เช่น pet';
  @override
  String get invalidCategoryLabel => 'ชื่อหมวดต้องยาว 1–40 ตัวอักษร';
  @override
  String categoryExists(String key) => 'มีหมวด "$key" อยู่แล้ว';
  @override
  String newCategory(String label) => 'สร้างหมวดใหม่: $label';
  @override
  String get invalidMetricKey => 'ชื่อ metric ต้องเป็นภาษาอังกฤษตัวเล็ก เช่น water';
  @override
  String metricExists(String key) => 'มี metric "$key" อยู่แล้ว';
  @override
  String newMetric(String label) => 'เพิ่มตัวเลขใหม่ที่จะติดตาม: $label';
  @override
  String get photoTitle => 'รูปภาพ';
  @override
  String duplicateEntry(String title, String date) => 'มี "$title" วันที่ $date อยู่แล้ว';
  @override
  String recurrenceStarting(String recurrence, String date) => '$recurrence เริ่ม $date';
  @override
  String timesCount(int n) => '$n ครั้ง';
  @override
  String dailySummary(String date, String content) => 'บันทึกวันที่ $date: $content';
  @override
  String addSummary(String title, String category, String when) => 'เพิ่ม "$title" · $category · $when';
  @override
  String editRef(Object? ref) => 'แก้ไขรายการ $ref';
  @override
  String get targetNotFound => 'ไม่พบรายการที่อ้างถึง';
  @override
  String dateChange(String from, String to) => 'วันที่ $from → $to';
  @override
  String endDateChange(String? to) => 'ถึงวันที่ → ${to ?? 'ไม่มี'}';
  @override
  String titleChange(String title) => 'ชื่อ → $title';
  @override
  String get bodyChange => 'แก้เนื้อหา';
  @override
  String categoryChange(String label) => 'หมวด → $label';
  @override
  String attachPhotos(int n) => 'แนบรูป $n รูป';
  @override
  String get nothingChanged => 'ไม่มีอะไรเปลี่ยน';
  @override
  String editSummary(String title, String changes) => 'แก้ไข "$title": $changes';
  @override
  String checkRequest(String item) => 'ติ๊ก "$item"';
  @override
  String checkRequestIn(String item, String title) => 'ติ๊ก "$item" ใน $title';
  @override
  String get checkItemNotFound => 'ไม่พบข้อนี้ใน checklist';
  @override
  String get checkDone => '✓ เสร็จแล้ว';
  @override
  String get uncheck => 'ยกเลิกติ๊ก';
  @override
  String looksBuddhist(String field, String value) => '$field $value ดูเหมือนเป็น พ.ศ.';
  @override
  String invalidDate(String field, String value) => '$field "$value" ไม่ใช่วันที่ที่ถูกต้อง';

  // ── AI ของแอป โควตา และการใช้งาน
  @override
  String get managedLabel => 'AI ของแอป';
  @override
  String get managedDescription => 'ไม่ต้องใช้ API key มีโควตาตามแผน ข้อความและรูปที่แนบส่งผ่านเซิร์ฟเวอร์ของเรา';
  @override
  String get managedConsentTitle => 'ใช้ AI ของแอป?';
  @override
  String get managedConsentMessage => 'ข้อความและรูปที่คุณส่ง พร้อมข้อมูลประกอบ (หมวด ตัวชี้วัด รายการที่กำลังจะมาถึง รายการใน 14 วันล่าสุด และ checklist ที่ค้าง) '
      'จะถูกส่งผ่านเซิร์ฟเวอร์ของเราไปประมวลผลที่ Anthropic (Claude) หรือ Google (Gemini)\n\n'
      'ตัวส่งต่อของเราไม่เก็บเนื้อหาที่ส่ง บันทึกเฉพาะจำนวนครั้ง โมเดล และจำนวน token '
      'ส่วนประวัติการใช้ AI ในบัญชีของคุณยังเก็บข้อความและคำตอบเหมือนใช้ AI อื่น\n\n'
      'ถ้าไม่ยินยอม เลือก AI อื่นได้ในหน้าตั้งค่า';
  @override
  String get agree => 'ยินยอม';
  @override
  String get consentGiven => 'คุณยินยอมให้ส่งข้อมูลผ่าน AI ของแอปแล้ว';
  @override
  String get consentNeeded => 'ยังไม่ได้ยินยอม';
  @override
  String get withdrawConsent => 'ถอนความยินยอม';
  @override
  String get useOtherAi => 'ใช้ AI อื่น';
  @override
  String get aiQuotaMinute => 'ส่งถี่เกินไป รอสักครู่แล้วลองใหม่';
  @override
  String aiQuotaDay(String when) => 'ใช้ AI ของแอปครบโควตาวันนี้แล้ว ใช้ได้อีก $when';
  @override
  String aiQuotaMonth(String when) => 'ใช้ AI ของแอปครบโควตาเดือนนี้แล้ว ใช้ได้อีก $when';
  @override
  String get aiResetLater => 'ภายหลัง';
  @override
  String get aiServiceBusy => 'AI ของแอปมีผู้ใช้เต็มสำหรับวันนี้ ลองใหม่ภายหลัง หรือใช้ AI อื่น';
  @override
  String get sessionExpired => 'การเข้าสู่ระบบหมดอายุ ออกจากระบบแล้วเข้าใหม่';
  @override
  String get aiRequestTooLarge => 'ข้อความหรือรูปใหญ่เกินไป ลองส่งทีละน้อย';
  @override
  String managedAiFailed(int status) => 'AI ของแอปขัดข้อง (HTTP $status) ลองใหม่ภายหลัง';
  @override
  String get usage => 'การใช้งาน';
  @override
  String get plan => 'แผน';
  @override
  String get planFree => 'Free';
  @override
  String get planMember => 'Member';
  @override
  String get usageAiToday => 'AI ของแอป วันนี้';
  @override
  String get usageAiMonth => 'AI ของแอป เดือนนี้';
  @override
  String get usageStorage => 'พื้นที่เก็บรูป';
  @override
  String usageOf(String used, String limit) => '$used จาก $limit';
  @override
  String storageFull(String limit) => 'พื้นที่เก็บรูปเต็ม (จำกัด $limit) จึงยังไม่ได้บันทึก เอารูปที่เพิ่มใหม่ออกแล้วบันทึกได้ '
      'หรือเอารูปเก่าออกจากรายการแล้วบันทึกก่อน จึงเพิ่มรูปใหม่';
  @override
  String get photosPurgedLater => 'รูปจะถูกลบถาวรหลัง 30 วัน';
  @override
  String get usageFailed => 'โหลดการใช้งานไม่ได้';

  // ── บริการ AI
  @override
  String get onDeviceLabel => 'Gemma บนเครื่อง';
  @override
  String get onDeviceDescription => 'ทำงานในมือถือ ไม่ต้องใช้เน็ต ข้อมูลไม่ออกจากเครื่อง';
  @override
  String cloudDescription(String company) => 'ใช้ API key ของคุณ ข้อความและรูปที่แนบถูกส่งไปที่ $company';
  @override
  String get openRouterDescription => 'key เดียวใช้ได้หลายค่าย ข้อความและรูปผ่าน OpenRouter ไปยังผู้ให้บริการของโมเดล';
  @override
  String serviceUnreachable(String service, Object error) => 'เชื่อมต่อ $service ไม่ได้: $error';
  @override
  String malformedResponse(String service, int status) => '$service ตอบกลับผิดรูปแบบ (HTTP $status)';
  @override
  String get invalidApiKey => 'API key ไม่ถูกต้อง';
  @override
  String get invalidApiKeyCheckSettings => 'API key ไม่ถูกต้อง — ตรวจในหน้าตั้งค่า';
  @override
  String outOfCredit(String service) => 'เครดิต $service ไม่พอ';
  @override
  String requestForbidden(String service, Object message) => '$service ไม่อนุญาตคำขอนี้: $message';
  @override
  String modelForbidden(String model) => 'API key นี้ไม่มีสิทธิ์ใช้โมเดล $model';
  @override
  String modelNotFound(String model) => 'ไม่พบโมเดล "$model" — เลือกโมเดลใหม่ในหน้าตั้งค่า';
  @override
  String quotaExceeded(String service) => 'ใช้โควตา $service เกินแล้ว ลองใหม่ภายหลัง';
  @override
  String serviceOverloaded(String service) => '$service มีผู้ใช้มากในขณะนี้ ลองใหม่ภายหลัง';
  @override
  String requestRefused(String service) => '$service ปฏิเสธคำขอนี้';
  @override
  String get answerTooLong => 'คำตอบของ AI ยาวเกินกำหนด ลองแบ่งเล่าทีละเรื่อง';
  @override
  String emptyAnswer(Object? reason) => 'AI ไม่ได้ตอบกลับ${reason == null ? '' : ' ($reason)'}';
  @override
  String get upstreamFailed => 'ผู้ให้บริการโมเดลขัดข้อง';
  @override
  String modelNotDownloaded(String size) => 'ยังไม่ได้ดาวน์โหลดโมเดล Gemma ($size) — ไปที่หน้าตั้งค่า';
  @override
  String get inputTooLarge => 'ข้อความหรือรูปมากเกินกว่าที่โมเดลบนเครื่องรับได้ — แบ่งเป็นหลายครั้ง';

  // ── ตั้งค่า
  @override
  String get general => 'ทั่วไป';
  @override
  String get languageSetting => 'ภาษา';
  @override
  String get signOutTitle => 'ออกจากระบบ?';
  @override
  String get signOutMessage => 'ต้องเข้าสู่ระบบใหม่เพื่อดูบันทึก';
  @override
  String get signOut => 'ออกจากระบบ';
  @override
  String signOutFailed(Object error) => 'ออกจากระบบไม่สำเร็จ: $error';
  @override
  String get currentAccount => 'บัญชีที่ใช้อยู่';
  @override
  String get aiForRecording => 'AI ที่ใช้บันทึก';
  @override
  String get noApiKeyYet => 'ยังไม่ได้ใส่ API key';
  @override
  String get localModel => 'โมเดลในเครื่อง';
  @override
  String get data => 'ข้อมูล';
  @override
  String get importLegacy => 'นำเข้าจากระบบเดิม';
  @override
  String get importLegacyDetail => 'ไฟล์ JSON ที่ export จากระบบเดิม · นำเข้าซ้ำได้ ไม่สร้างรายการซ้ำ';
  @override
  String get apiKeySaved => 'บันทึก API key แล้ว (เก็บในเครื่องเท่านั้น)';
  @override
  String get nothingToImport => 'ไม่มีรายการใหม่ (นำเข้าครบแล้ว)';
  @override
  String importedCount(int n) => 'นำเข้าแล้ว $n รายการ';
  @override
  String importFailed(Object error) => 'นำเข้าไม่สำเร็จ: $error';
  @override
  String get unsupportedExport => 'ไม่ใช่ไฟล์ export ที่รองรับ (life-dashboard-export version 1)';
  @override
  String get deleteKeyTitle => 'ลบ API key?';
  @override
  String deleteKeyMessage(String service) => 'key ของ $service จะถูกลบจากเครื่องนี้ ต้องใส่ใหม่ถ้าจะใช้อีก';
  @override
  String get linkCopied => 'คัดลอกลิงก์แล้ว วางในเบราว์เซอร์เพื่อสร้าง key';
  @override
  String get manageLocalModel => 'จัดการโมเดลในเครื่อง';
  @override
  String get apiKeyReplace => 'API key (ตั้งไว้แล้ว — ใส่ใหม่เพื่อเปลี่ยน)';
  @override
  String apiKeyFor(String service) => 'API key ของ $service';
  @override
  String get pasteKey => 'วาง key ที่นี่';
  @override
  String keyHelp(String url) => 'สร้างได้ที่ $url · เก็บใน Keychain/Keystore ของเครื่อง แยกตามบัญชี';
  @override
  String get show => 'แสดง';
  @override
  String get hide => 'ซ่อน';
  @override
  String get saveKey => 'บันทึก key';
  @override
  String get copyLink => 'คัดลอกลิงก์';
  @override
  String get deleteKey => 'ลบ key';
  @override
  String get model => 'โมเดล';
  @override
  String modelListFailed(Object error) => 'โหลดรายชื่อโมเดลไม่ได้ — $error';
  @override
  String get saveKeyForModels => 'บันทึก API key ก่อน เพื่อโหลดรายชื่อโมเดล';
  @override
  String get loadingModels => 'กำลังโหลดรายชื่อโมเดล…';
  @override
  String modelCount(int n, String service) => '$n โมเดลจาก $service';
  @override
  String get modelNotListed => 'โมเดลที่เลือกไว้ไม่อยู่ในรายชื่อ — เลือกใหม่';
  @override
  String get reloadModels => 'โหลดรายชื่อโมเดลใหม่';
  @override
  String downloading(int percent) => 'กำลังดาวน์โหลด $percent%';
  @override
  String get checking => 'กำลังตรวจสอบ…';
  @override
  String get modelReady => 'พร้อมใช้ — ทำงานในเครื่อง ไม่ต้องใช้เน็ต';
  @override
  String get modelMissing => 'ยังไม่ได้ดาวน์โหลด';
  @override
  String downloadFailed(Object error) => 'ดาวน์โหลดไม่สำเร็จ: $error';
  @override
  String get downloadModelTitle => 'ดาวน์โหลด Gemma 4 E2B?';
  @override
  String downloadModelMessage(String size) => 'ไฟล์ขนาด $size ควรใช้ Wi-Fi และมีพื้นที่ว่างพอ\nหลังดาวน์โหลดแล้ว AI จะทำงานในเครื่องได้โดยไม่ต้องใช้เน็ต';
  @override
  String get removeModelTitle => 'ลบโมเดลในเครื่อง?';
  @override
  String removeModelMessage(String size) => 'จะใช้เสียงพูดและ AI ในเครื่องไม่ได้จนกว่าจะดาวน์โหลดใหม่ ($size)';
  @override
  String modelSize(String size) => 'ขนาด $size';
  @override
  String get localModelNote => 'ใช้ฟังเสียงที่พูด (ถอดเป็นข้อความในเครื่อง) และใช้บันทึกได้เมื่อเลือก AI ในเครื่อง';
}
