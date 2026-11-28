/// ข้อความทั้งหมดที่ผู้ใช้เห็น 1 ชุดต่อ 1 ภาษา — Dart ล้วน (ไม่พึ่ง Flutter) จึงใช้ได้ทั้ง domain, AI และ ViewModel
/// เพิ่มข้อความใหม่: ประกาศที่นี่แล้วใส่ให้ครบทุกภาษา (ขาดภาษาไหน compile ไม่ผ่าน)
library;

import '../../ai/llm_provider.dart';
import '../../domain/recurrence.dart';
import '../utils/dates.dart';
import 'strings_en.dart';
import 'strings_th.dart';

/// ภาษาที่รองรับ — [nativeName] แสดงเป็นภาษาของตัวเอง ผู้ใช้จึงหาเจอแม้อ่านภาษาปัจจุบันไม่ออก
enum AppLanguage {
  th('ไทย'),
  en('English');

  const AppLanguage(this.nativeName);
  final String nativeName;

  /// รหัสภาษา (ใช้เป็น Locale และค่าที่เก็บในเครื่อง)
  String get code => name;
}

abstract class AppStrings {
  const AppStrings();

  factory AppStrings.of(AppLanguage language) => switch (language) {
        AppLanguage.th => const ThStrings(),
        AppLanguage.en => const EnStrings(),
      };

  AppLanguage get language;

  // ── รูปแบบที่ใช้ร่วมกันทุกภาษา
  String fmtDay(DateTime d) => '${d.day} ${monthsShort[d.month - 1]}';
  String fmtDate(DateTime d) => '${fmtDay(d)} ${displayYear(d.year)}';

  String fmtRange(DateTime start, DateTime? end) {
    if (end == null) return fmtDay(start);
    return start.year == end.year ? '${fmtDay(start)} – ${fmtDay(end)}' : '${fmtDate(start)} – ${fmtDate(end)}';
  }

  /// ป้ายเวลาเทียบกับวันนี้ ('พรุ่งนี้', 'อีก 5 วัน') หรือ null ถ้าผ่านไปแล้ว
  String? relativeLabel(DateTime start, DateTime last, DateTime now, {bool isRange = false}) {
    if (start.isAfter(now)) {
      final n = daysBetween(now, start);
      if (n == 1) return tomorrow;
      return n > 60 ? inMonths((n / 30).round()) : inDays(n);
    }
    if (!last.isBefore(now)) return isRange ? ongoing : today;
    return null;
  }

  String recurrenceLabel(Recurrence r) {
    switch (r.every) {
      case 'daily':
        return everyDay;
      case 'weekly':
        return everyWeek;
      case 'monthly':
        return everyMonth;
      case 'yearly':
        return everyYear;
    }
    final p = Recurrence.parseEvery(r.every);
    return p == null ? r.every : everyN(p.$1, p.$2);
  }

  /// วันและเวลาตามเครื่องของผู้ใช้ เช่น เวลาที่โควตากลับมาใช้ได้
  String fmtDateTime(DateTime d) =>
      '${fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String providerLabel(AiProviderKind kind) => switch (kind) {
        AiProviderKind.managed => managedLabel,
        AiProviderKind.onDevice => onDeviceLabel,
        _ => kind.label,
      };

  String providerDescription(AiProviderKind kind) => switch (kind) {
        AiProviderKind.managed => managedDescription,
        AiProviderKind.onDevice => onDeviceDescription,
        AiProviderKind.openRouter => openRouterDescription,
        _ => cloudDescription(kind.company),
      };

  // ── วันที่และเวลา
  List<String> get monthsShort;
  List<String> get monthsLong;
  /// จันทร์ → อาทิตย์ (ตามลำดับ DateTime.weekday)
  List<String> get weekdays;
  /// ชื่อวันย่อข้างปฏิทินกิจกรรม เริ่มจากอาทิตย์ (ว่าง = เว้นแถว)
  List<String> get heatmapWeekdays;
  /// ปีที่แสดงในวันที่ (ไทยใช้ พ.ศ.)
  int displayYear(int year);
  /// ปีเดี่ยวๆ เช่น หัวข้อกลุ่มรายการ
  String yearLabel(int year);
  String get today;
  String get tomorrow;
  String get ongoing;
  String inDays(int n);
  String inMonths(int n);

  // ── ใช้ร่วมกัน
  String get appTagline;
  String get cancel;
  String get close;
  String get save;
  String get delete;
  String get edit;
  String get send;
  String get retry;
  String get later;
  String get goToSettings;
  String get download;
  String get camera;
  String get gallery;
  String get photos;
  String saveFailed(Object error);
  String deleteFailed(Object error);

  // ── เข้าสู่ระบบ
  String get email;
  String get password;
  String get passwordHint;
  String get showPassword;
  String get hidePassword;
  String get createAccount;
  String get signIn;
  String get switchToSignIn;
  String get switchToSignUp;
  String get credentialsRequired;
  String confirmationSent(String email);
  String get invalidCredentials;
  String get emailNotConfirmed;
  String get userAlreadyExists;
  String get weakPassword;
  String connectionFailed(Object error);
  String get orDivider;
  String continueWith(String provider);
  String socialSignInFailed(String provider, Object error);
  String get signupDisabled;

  // ── Timeline และการ์ดรายการ
  String get search;
  String get overview;
  String get settings;
  String get refreshFailed;
  String get loadFailed;
  String get noFilterMatches;
  String get todayEmpty;
  String get entryExamples;
  String get earlier;
  String itemCount(int n);
  String get clearFilter;
  String get upcoming;
  String allCount(int n);
  String get noUpcoming;
  String get noUpcomingDetail;
  String occurrencesDone(int done);
  String occurrenceOpen(int done);
  String occurrenceOf(int done, int total, String last);
  String progressLabel(int done, int total);
  String metricEach(String label, String value, String unit);
  String metricTotal(String value, String unit);
  String metricRemaining(String value, String unit);
  String get deleted;
  String get deletedSeries;
  String get undo;
  String undoFailed(Object error);

  // ── การเกิดซ้ำ
  String get everyDay;
  String get everyWeek;
  String get everyMonth;
  String get everyYear;
  /// [unit] = d | w | m | y
  String everyN(int n, String unit);

  // ── ค้นหาและภาพรวม
  String get searchHint;
  String get clearSearch;
  String get searchPrompt;
  String get orPickCategory;
  String get noSearchResults;
  String get noSearchResultsDetail;
  String foundCount(int n);
  String age(int years);
  String dayCount(int n);
  String daysLogged(String year);
  String get bestStreak;
  String get totalEntries;
  String get plannedAhead;
  String get activityCalendar;
  String get tapDayHint;
  String get byCategory;
  String heatmapSummary(int year, int days);
  String get logged;
  String get planned;

  // ── หน้าแก้ไขรายการ
  String get deleteEntryTitle;
  String get deleteSeriesWarning;
  String get discardTitle;
  String get discardMessage;
  String get keepEditing;
  String get discard;
  String get startDate;
  String get date;
  String get endDateOptional;
  String get reviewEntry;
  String get newEntry;
  String get kindEvent;
  String get kindDaily;
  String get titleField;
  String get titleHint;
  String get details;
  String get detailsHint;
  String get markdownHelp;
  String get category;
  String get takePhoto;
  String get numbers;
  String get removeNumber;
  String get addNumber;
  String get repeats;
  String get noRepeat;
  String get unlimited;
  String get timesSuffix;
  String endsOn(String date);
  String get removeEndDate;
  String importedFrom(String ref);
  String get clearDate;
  String get pickDate;

  // ── ตรวจความถูกต้องของรายการ
  String yearLooksBuddhist(int year);
  String unknownCategory(String key);
  String get endNotAfterStart;
  String get dailyNoRange;
  String invalidRecurrence(String every);
  String get recurringNoRange;
  String get timesOutOfRange;
  String get untilBeforeStart;
  String unknownMetric(String key);
  String notANumber(String key);
  String get entryEmpty;
  String tooManyPhotos(int max);

  // ── รูปภาพ
  String get photoLoadFailed;
  String photoPosition(int index, int total);
  String get removePhoto;
  String get photoLimitReached;
  String get cameraDenied;
  String get galleryDenied;
  String photoOpenFailed(Object error);
  String get photosUnusable;
  String photosOverRoom(int room);

  // ── กล่องพิมพ์ เสียง และผู้ช่วย
  String get composerHint;
  String get speak;
  String get recording;
  String recordingLeft(int seconds);
  String get stopAndSend;
  String get transcribing;
  String get noSpeech;
  String get micDenied;
  String micFailed(Object error);
  String transcribeFailed(Object error);
  String get assistantTitle;
  String savedCount(int n);
  String get aiNotSetUp;
  String needApiKey(String service);
  String needLocalModel(String size);
  String get noVoiceModel;
  String needVoiceModel(String size);
  String get aiThinking;
  String get nothingSaved;
  String unattachedPhotos(int n);
  String get saved;
  String saveCount(int n);
  String get answerHint;
  String get followUpHint;
  String get editBeforeSaving;
  String unexpectedError(Object error);
  String someSavesFailed(String failures);
  String attachedPhotosLog(int n);

  // ── ข้อเสนอของ AI (recorder)
  String get aiUnreadable;
  String unknownCommand(Object? type);
  String get unsupported;
  String get reviewBelow;
  String get needMoreInfo;
  String get noAnswer;
  String get invalidCategoryKey;
  String get invalidCategoryLabel;
  String categoryExists(String key);
  String newCategory(String label);
  String get invalidMetricKey;
  String metricExists(String key);
  String newMetric(String label);
  String get photoTitle;
  String duplicateEntry(String title, String date);
  String recurrenceStarting(String recurrence, String date);
  String timesCount(int n);
  String dailySummary(String date, String content);
  String addSummary(String title, String category, String when);
  String editRef(Object? ref);
  String get targetNotFound;
  String dateChange(String from, String to);
  String endDateChange(String? to);
  String titleChange(String title);
  String get bodyChange;
  String categoryChange(String label);
  String attachPhotos(int n);
  String get nothingChanged;
  String editSummary(String title, String changes);
  String checkRequest(String item);
  String checkRequestIn(String item, String title);
  String get checkItemNotFound;
  String get checkDone;
  String get uncheck;
  String looksBuddhist(String field, String value);
  String invalidDate(String field, String value);

  // ── AI ของแอป โควตา และการใช้งาน
  String get managedLabel;
  String get managedDescription;
  String get managedConsentTitle;
  String get managedConsentMessage;
  String get agree;
  String get consentGiven;
  String get consentNeeded;
  String get withdrawConsent;
  String get useOtherAi;
  String get aiQuotaMinute;
  String aiQuotaDay(String when);
  String aiQuotaMonth(String when);
  /// ใช้แทนเวลาเมื่อ server ไม่ได้บอกว่าจะใช้ได้อีกเมื่อไร
  String get aiResetLater;
  String get aiServiceBusy;
  String get sessionExpired;
  String get aiRequestTooLarge;
  String managedAiFailed(int status);
  String get usage;
  String get plan;
  String get planFree;
  String get planMember;
  String get usageAiToday;
  String get usageAiMonth;
  String get usageStorage;
  String usageOf(String used, String limit);
  String get usageFailed;

  // ── บริการ AI
  String get onDeviceLabel;
  String get onDeviceDescription;
  String cloudDescription(String company);
  String get openRouterDescription;
  String serviceUnreachable(String service, Object error);
  String malformedResponse(String service, int status);
  String get invalidApiKey;
  String get invalidApiKeyCheckSettings;
  String outOfCredit(String service);
  String requestForbidden(String service, Object message);
  String modelForbidden(String model);
  String modelNotFound(String model);
  String quotaExceeded(String service);
  String serviceOverloaded(String service);
  String requestRefused(String service);
  String get answerTooLong;
  String emptyAnswer(Object? reason);
  String get upstreamFailed;
  String modelNotDownloaded(String size);
  String get inputTooLarge;

  // ── ตั้งค่า
  String get general;
  String get languageSetting;
  String get signOutTitle;
  String get signOutMessage;
  String get signOut;
  String signOutFailed(Object error);
  String get currentAccount;
  String get aiForRecording;
  String get noApiKeyYet;
  String get localModel;
  String get data;
  String get importLegacy;
  String get importLegacyDetail;
  String get apiKeySaved;
  String get nothingToImport;
  String importedCount(int n);
  String importFailed(Object error);
  String get unsupportedExport;
  String get deleteKeyTitle;
  String deleteKeyMessage(String service);
  String get linkCopied;
  String get manageLocalModel;
  String get apiKeyReplace;
  String apiKeyFor(String service);
  String get pasteKey;
  String keyHelp(String url);
  String get show;
  String get hide;
  String get saveKey;
  String get copyLink;
  String get deleteKey;
  String get model;
  String modelListFailed(Object error);
  String get saveKeyForModels;
  String get loadingModels;
  String modelCount(int n, String service);
  String get modelNotListed;
  String get reloadModels;
  String downloading(int percent);
  String get checking;
  String get modelReady;
  String get modelMissing;
  String downloadFailed(Object error);
  String get downloadModelTitle;
  String downloadModelMessage(String size);
  String get removeModelTitle;
  String removeModelMessage(String size);
  String modelSize(String size);
  String get localModelNote;
}
