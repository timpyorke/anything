import 'app_strings.dart';

class EnStrings extends AppStrings {
  const EnStrings();

  @override
  AppLanguage get language => AppLanguage.en;

  /// '1 day' / '3 days'
  static String _count(int n, String one, [String? many]) => '$n ${n == 1 ? one : many ?? '${one}s'}';

  // ── วันที่และเวลา
  @override
  List<String> get monthsShort => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  @override
  List<String> get monthsLong => const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  @override
  List<String> get weekdays => const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  @override
  List<String> get heatmapWeekdays => const ['', 'M', '', 'W', '', 'F', ''];
  @override
  int displayYear(int year) => year;
  @override
  String yearLabel(int year) => '$year';
  @override
  String get today => 'Today';
  @override
  String get tomorrow => 'Tomorrow';
  @override
  String get ongoing => 'Ongoing';
  @override
  String inDays(int n) => 'In ${_count(n, 'day')}';
  @override
  String inMonths(int n) => 'In ~${_count(n, 'month')}';

  // ── ใช้ร่วมกัน
  @override
  String get appTagline => 'Your life diary, powered by AI';
  @override
  String get cancel => 'Cancel';
  @override
  String get close => 'Close';
  @override
  String get save => 'Save';
  @override
  String get delete => 'Delete';
  @override
  String get edit => 'Edit';
  @override
  String get send => 'Send';
  @override
  String get retry => 'Try again';
  @override
  String get later => 'Not now';
  @override
  String get goToSettings => 'Open settings';
  @override
  String get download => 'Download';
  @override
  String get camera => 'Camera';
  @override
  String get gallery => 'Photos';
  @override
  String get photos => 'Photos';
  @override
  String saveFailed(Object error) => 'Could not save: $error';
  @override
  String deleteFailed(Object error) => 'Could not delete: $error';

  // ── เข้าสู่ระบบ
  @override
  String get email => 'Email';
  @override
  String get password => 'Password';
  @override
  String get passwordHint => 'At least 8 characters';
  @override
  String get showPassword => 'Show password';
  @override
  String get hidePassword => 'Hide password';
  @override
  String get createAccount => 'Create account';
  @override
  String get signIn => 'Sign in';
  @override
  String get switchToSignIn => 'Have an account? Sign in';
  @override
  String get switchToSignUp => 'No account yet? Create one';
  @override
  String get credentialsRequired => 'Enter your email and a password of at least 8 characters';
  @override
  String confirmationSent(String email) => 'Confirmation email sent to $email — confirm it, then sign in';
  @override
  String get invalidCredentials => 'Wrong email or password';
  @override
  String get emailNotConfirmed => 'Email not confirmed yet — check your inbox';
  @override
  String get userAlreadyExists => 'This email already has an account — sign in instead';
  @override
  String get weakPassword => 'Password is too weak';
  @override
  String connectionFailed(Object error) => 'Could not connect: $error';
  @override
  String get orDivider => 'or';
  @override
  String continueWith(String provider) => 'Continue with $provider';
  @override
  String socialSignInFailed(String provider, Object error) => 'Could not sign in with $provider: $error';
  @override
  String get signupDisabled => 'New sign-ups are turned off — use an existing account';

  // ── Timeline และการ์ดรายการ
  @override
  String get search => 'Search';
  @override
  String get overview => 'Overview';
  @override
  String get settings => 'Settings';
  @override
  String get refreshFailed => 'Could not load the latest data';
  @override
  String get loadFailed => 'Could not load your data';
  @override
  String get noFilterMatches => 'No entries match this filter';
  @override
  String get todayEmpty => 'Nothing yet. Type, or tap the mic and tell the AI';
  @override
  String get entryExamples => 'e.g. “Ran 5 km” or “Doctor next Friday”';
  @override
  String get earlier => 'Earlier';
  @override
  String itemCount(int n) => _count(n, 'entry', 'entries');
  @override
  String get clearFilter => 'Clear filter';
  @override
  String get upcoming => 'Upcoming';
  @override
  String allCount(int n) => 'All $n';
  @override
  String get noUpcoming => 'Nothing coming up';
  @override
  String get noUpcomingDetail => 'Appointments and plans you record show up here';
  @override
  String occurrencesDone(int done) => 'All ${_count(done, 'time')} done';
  @override
  String occurrenceOpen(int done) => 'No. ${done + 1} · $done so far';
  @override
  String occurrenceOf(int done, int total, String last) => 'No. ${done + 1}/$total · last on $last';
  @override
  String progressLabel(int done, int total) => 'Progress: $done of $total';
  @override
  String metricEach(String label, String value, String unit) => '$label $value $unit each time';
  @override
  String metricTotal(String value, String unit) => 'So far $value $unit';
  @override
  String metricRemaining(String value, String unit) => '$value $unit left';
  @override
  String get deleted => 'Deleted';
  @override
  String get deletedSeries => 'Deleted the whole recurring series';
  @override
  String get undo => 'Undo';
  @override
  String undoFailed(Object error) => 'Could not undo: $error';

  // ── การเกิดซ้ำ
  @override
  String get everyDay => 'Daily';
  @override
  String get everyWeek => 'Weekly';
  @override
  String get everyMonth => 'Monthly';
  @override
  String get everyYear => 'Yearly';
  @override
  String everyN(int n, String unit) => 'Every ${_count(n, const {'d': 'day', 'w': 'week', 'm': 'month', 'y': 'year'}[unit]!)}';

  // ── ค้นหาและภาพรวม
  @override
  String get searchHint => 'Search titles, text, categories…';
  @override
  String get clearSearch => 'Clear search';
  @override
  String get searchPrompt => 'Type to search';
  @override
  String get orPickCategory => 'Or pick a category';
  @override
  String get noSearchResults => 'No matching entries';
  @override
  String get noSearchResultsDetail => 'Try a shorter word, or search by category';
  @override
  String foundCount(int n) => 'Found ${itemCount(n)}';
  @override
  String age(int years) => 'Age $years';
  @override
  String dayCount(int n) => _count(n, 'day');
  @override
  String daysLogged(String year) => 'Days logged ($year)';
  @override
  String get bestStreak => 'Longest streak';
  @override
  String get totalEntries => 'Total entries';
  @override
  String get plannedAhead => 'Planned ahead';
  @override
  String get activityCalendar => 'Activity calendar';
  @override
  String get tapDayHint => 'Tap a coloured day to see its entries';
  @override
  String get byCategory => 'By category';
  @override
  String heatmapSummary(int year, int days) => 'Activity calendar $year: ${_count(days, 'day')} with entries';
  @override
  String get logged => 'Logged';
  @override
  String get planned => 'Planned';

  // ── หน้าแก้ไขรายการ
  @override
  String get deleteEntryTitle => 'Delete this entry?';
  @override
  String get deleteSeriesWarning => 'The whole recurring series will be deleted';
  @override
  String get discardTitle => 'Discard changes?';
  @override
  String get discardMessage => 'Your changes are not saved yet';
  @override
  String get keepEditing => 'Keep editing';
  @override
  String get discard => 'Discard';
  @override
  String get startDate => 'Starts';
  @override
  String get date => 'Date';
  @override
  String get endDateOptional => 'Ends (optional)';
  @override
  String get reviewEntry => 'Review before saving';
  @override
  String get newEntry => 'New entry';
  @override
  String get kindEvent => 'Event';
  @override
  String get kindDaily => 'Daily log';
  @override
  String get titleField => 'Title';
  @override
  String get titleHint => 'What happened';
  @override
  String get details => 'Details';
  @override
  String get detailsHint => 'Tell more';
  @override
  String get markdownHelp => 'Start a line with “- ” for a list or “- [ ] ” for a checkbox; **text** is bold';
  @override
  String get category => 'Category';
  @override
  String get takePhoto => 'Take photo';
  @override
  String get numbers => 'Numbers';
  @override
  String get removeNumber => 'Remove';
  @override
  String get addNumber => 'Add number';
  @override
  String get repeats => 'Repeat';
  @override
  String get noRepeat => 'Does not repeat';
  @override
  String get unlimited => 'No limit';
  @override
  String get timesSuffix => 'times';
  @override
  String endsOn(String date) => 'Ends $date';
  @override
  String get removeEndDate => 'Remove end date';
  @override
  String importedFrom(String ref) => 'Imported from $ref';
  @override
  String get clearDate => 'Clear date';
  @override
  String get pickDate => 'Pick a date';

  // ── ตรวจความถูกต้องของรายการ
  @override
  String yearLooksBuddhist(int year) => 'Year $year looks like a Buddhist Era year — use the Gregorian year';
  @override
  String unknownCategory(String key) => 'Unknown category "$key"';
  @override
  String get endNotAfterStart => 'The end date must be after the start date';
  @override
  String get dailyNoRange => 'A daily log cannot span dates or repeat';
  @override
  String invalidRecurrence(String every) => 'Invalid repeat pattern: $every';
  @override
  String get recurringNoRange => 'A recurring entry cannot span dates';
  @override
  String get timesOutOfRange => 'The number of times must be between 1 and 1000';
  @override
  String get untilBeforeStart => 'The repeat end date cannot be before the start date';
  @override
  String unknownMetric(String key) => 'Unknown metric "$key"';
  @override
  String notANumber(String key) => 'The value of $key is not a number';
  @override
  String get entryEmpty => 'Add at least a title, text, photo or number';
  @override
  String tooManyPhotos(int max) => 'Up to ${_count(max, 'photo')} per entry';

  // ── รูปภาพ
  @override
  String get photoLoadFailed => 'Could not load the photo. Tap to retry';
  @override
  String photoPosition(int index, int total) => 'Photo $index of $total';
  @override
  String get removePhoto => 'Remove photo';
  @override
  String get photoLimitReached => 'Photo limit reached. Remove one first';
  @override
  String get cameraDenied => 'Cannot use the camera. Check permissions in device settings';
  @override
  String get galleryDenied => 'Cannot open your photos. Check permissions in device settings';
  @override
  String photoOpenFailed(Object error) => 'Could not open the photo: $error';
  @override
  String get photosUnusable => 'Some photos cannot be used (JPEG, PNG, WebP or GIF up to 5 MB)';
  @override
  String photosOverRoom(int room) => 'Only ${_count(room, 'more photo', 'more photos')} fit; the rest were not attached';

  // ── กล่องพิมพ์ เสียง และผู้ช่วย
  @override
  String get composerHint => 'Tell me anything…';
  @override
  String get speak => 'Speak';
  @override
  String get recording => 'Recording…';
  @override
  String recordingLeft(int seconds) => '${seconds}s left · sends automatically';
  @override
  String get stopAndSend => 'Stop and send';
  @override
  String get transcribing => 'Transcribing on your device…';
  @override
  String get noSpeech => 'Didn’t catch that. Tap the mic and try again';
  @override
  String get micDenied => 'Cannot use the microphone. Check permissions in device settings';
  @override
  String micFailed(Object error) => 'Could not start the microphone: $error';
  @override
  String transcribeFailed(Object error) => 'Transcription failed: $error';
  @override
  String get assistantTitle => 'Diary assistant';
  @override
  String savedCount(int n) => 'Saved ${itemCount(n)}';
  @override
  String get aiNotSetUp => 'AI is not set up yet';
  @override
  String needApiKey(String service) => 'Add your $service API key in settings first';
  @override
  String needLocalModel(String size) => 'Download the Gemma model ($size) in settings first';
  @override
  String get noVoiceModel => 'No speech model yet';
  @override
  String needVoiceModel(String size) => 'Download the Gemma model ($size) in settings first. Speech is transcribed on your device';
  @override
  String get aiThinking => 'AI is thinking…';
  @override
  String get nothingSaved => 'Nothing has been saved';
  @override
  String unattachedPhotos(int n) => '${_count(n, 'photo')} not attached to a selected item will not be kept';
  @override
  String get saved => 'Saved';
  @override
  String saveCount(int n) => 'Save ${itemCount(n)}';
  @override
  String get answerHint => 'Answer…';
  @override
  String get followUpHint => 'Add or correct something…';
  @override
  String get editBeforeSaving => 'Edit before saving';
  @override
  String unexpectedError(Object error) => 'Something went wrong: $error';
  @override
  String someSavesFailed(String failures) => 'Some items could not be saved:\n$failures';
  @override
  String attachedPhotosLog(int n) => '[${_count(n, 'photo')} attached]';

  // ── ข้อเสนอของ AI (recorder)
  @override
  String get aiUnreadable => 'The AI reply could not be read. Please try again';
  @override
  String unknownCommand(Object? type) => 'Unknown command: $type';
  @override
  String get unsupported => 'Not supported';
  @override
  String get reviewBelow => 'Review the items below before saving';
  @override
  String get needMoreInfo => 'I need a bit more information';
  @override
  String get noAnswer => 'No answer yet. Please try again';
  @override
  String get invalidCategoryKey => 'A category key must be lowercase English, e.g. pet';
  @override
  String get invalidCategoryLabel => 'A category name must be 1–40 characters';
  @override
  String categoryExists(String key) => 'Category "$key" already exists';
  @override
  String newCategory(String label) => 'New category: $label';
  @override
  String get invalidMetricKey => 'A metric key must be lowercase English, e.g. water';
  @override
  String metricExists(String key) => 'Metric "$key" already exists';
  @override
  String newMetric(String label) => 'Track a new number: $label';
  @override
  String get photoTitle => 'Photo';
  @override
  String duplicateEntry(String title, String date) => '"$title" on $date already exists';
  @override
  String recurrenceStarting(String recurrence, String date) => '$recurrence from $date';
  @override
  String timesCount(int n) => _count(n, 'time');
  @override
  String dailySummary(String date, String content) => 'Log for $date: $content';
  @override
  String addSummary(String title, String category, String when) => 'Add "$title" · $category · $when';
  @override
  String editRef(Object? ref) => 'Edit item $ref';
  @override
  String get targetNotFound => 'The referenced entry was not found';
  @override
  String dateChange(String from, String to) => 'Date $from → $to';
  @override
  String endDateChange(String? to) => 'End date → ${to ?? 'none'}';
  @override
  String titleChange(String title) => 'Title → $title';
  @override
  String get bodyChange => 'Text edited';
  @override
  String categoryChange(String label) => 'Category → $label';
  @override
  String attachPhotos(int n) => 'Attach ${_count(n, 'photo')}';
  @override
  String get nothingChanged => 'Nothing changes';
  @override
  String editSummary(String title, String changes) => 'Edit "$title": $changes';
  @override
  String checkRequest(String item) => 'Check "$item"';
  @override
  String checkRequestIn(String item, String title) => 'Check "$item" in $title';
  @override
  String get checkItemNotFound => 'That item is not in the checklist';
  @override
  String get checkDone => '✓ Done';
  @override
  String get uncheck => 'Uncheck';
  @override
  String looksBuddhist(String field, String value) => '$field $value looks like a Buddhist Era year';
  @override
  String invalidDate(String field, String value) => '$field "$value" is not a valid date';

  // ── บริการ AI
  @override
  String get onDeviceLabel => 'Gemma on device';
  @override
  String get onDeviceDescription => 'Runs on your phone, works offline, data stays on the device';
  @override
  String cloudDescription(String company) => 'Uses your API key; text and photos are sent to $company';
  @override
  String get openRouterDescription => 'One key for many models; text and photos go through OpenRouter to the model’s provider';
  @override
  String serviceUnreachable(String service, Object error) => 'Cannot connect to $service: $error';
  @override
  String malformedResponse(String service, int status) => '$service sent a malformed response (HTTP $status)';
  @override
  String get invalidApiKey => 'Invalid API key';
  @override
  String get invalidApiKeyCheckSettings => 'Invalid API key — check it in settings';
  @override
  String outOfCredit(String service) => 'Not enough $service credit';
  @override
  String requestForbidden(String service, Object message) => '$service did not allow this request: $message';
  @override
  String modelForbidden(String model) => 'This API key cannot use the model $model';
  @override
  String modelNotFound(String model) => 'Model "$model" not found — pick another in settings';
  @override
  String quotaExceeded(String service) => '$service quota exceeded. Try again later';
  @override
  String serviceOverloaded(String service) => '$service is busy right now. Try again later';
  @override
  String requestRefused(String service) => '$service refused this request';
  @override
  String get answerTooLong => 'The AI answer was too long. Try one topic at a time';
  @override
  String emptyAnswer(Object? reason) => 'The AI did not answer${reason == null ? '' : ' ($reason)'}';
  @override
  String get upstreamFailed => 'The model provider failed';
  @override
  String modelNotDownloaded(String size) => 'The Gemma model ($size) is not downloaded — go to settings';
  @override
  String get inputTooLarge => 'Too much text or too many photos for the on-device model — split it up';

  // ── ตั้งค่า
  @override
  String get general => 'General';
  @override
  String get languageSetting => 'Language';
  @override
  String get signOutTitle => 'Sign out?';
  @override
  String get signOutMessage => 'You will need to sign in again to see your diary';
  @override
  String get signOut => 'Sign out';
  @override
  String signOutFailed(Object error) => 'Could not sign out: $error';
  @override
  String get currentAccount => 'Signed-in account';
  @override
  String get aiForRecording => 'AI for recording';
  @override
  String get noApiKeyYet => 'No API key yet';
  @override
  String get localModel => 'On-device model';
  @override
  String get data => 'Data';
  @override
  String get importLegacy => 'Import from the old system';
  @override
  String get importLegacyDetail => 'A JSON export from the old system · safe to import again, no duplicates';
  @override
  String get apiKeySaved => 'API key saved (kept on this device only)';
  @override
  String get nothingToImport => 'Nothing new (everything is already imported)';
  @override
  String importedCount(int n) => 'Imported ${itemCount(n)}';
  @override
  String importFailed(Object error) => 'Import failed: $error';
  @override
  String get unsupportedExport => 'Not a supported export file (life-dashboard-export version 1)';
  @override
  String get deleteKeyTitle => 'Delete API key?';
  @override
  String deleteKeyMessage(String service) => 'The $service key will be removed from this device. You will need to enter it again to use it';
  @override
  String get linkCopied => 'Link copied. Paste it into a browser to create a key';
  @override
  String get manageLocalModel => 'Manage on-device model';
  @override
  String get apiKeyReplace => 'API key (already set — enter a new one to replace it)';
  @override
  String apiKeyFor(String service) => '$service API key';
  @override
  String get pasteKey => 'Paste your key here';
  @override
  String keyHelp(String url) => 'Create one at $url · stored in this device’s Keychain/Keystore, per account';
  @override
  String get show => 'Show';
  @override
  String get hide => 'Hide';
  @override
  String get saveKey => 'Save key';
  @override
  String get copyLink => 'Copy link';
  @override
  String get deleteKey => 'Delete key';
  @override
  String get model => 'Model';
  @override
  String modelListFailed(Object error) => 'Could not load the model list — $error';
  @override
  String get saveKeyForModels => 'Save an API key first to load the model list';
  @override
  String get loadingModels => 'Loading models…';
  @override
  String modelCount(int n, String service) => '${_count(n, 'model')} from $service';
  @override
  String get modelNotListed => 'The selected model is not in the list — pick another';
  @override
  String get reloadModels => 'Reload models';
  @override
  String downloading(int percent) => 'Downloading $percent%';
  @override
  String get checking => 'Checking…';
  @override
  String get modelReady => 'Ready — runs on your device, works offline';
  @override
  String get modelMissing => 'Not downloaded';
  @override
  String downloadFailed(Object error) => 'Download failed: $error';
  @override
  String get downloadModelTitle => 'Download Gemma 4 E2B?';
  @override
  String downloadModelMessage(String size) => 'The file is $size. Use Wi-Fi and make sure there is enough free space.\nOnce downloaded, the AI works on your device without internet.';
  @override
  String get removeModelTitle => 'Delete the on-device model?';
  @override
  String removeModelMessage(String size) => 'Voice input and on-device AI stop working until you download it again ($size)';
  @override
  String modelSize(String size) => 'Size $size';
  @override
  String get localModelNote => 'Used to transcribe your speech on the device, and to record entries when on-device AI is selected';
}
