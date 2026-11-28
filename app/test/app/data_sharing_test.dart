import 'package:anything/app/data_sharing.dart';
import 'package:anything/app/providers.dart';
import 'package:anything/domain/repositories/data_sharing_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_data_sharing_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage();
  late FakeDataSharingRepository repository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    repository = FakeDataSharingRepository();
  });

  ProviderContainer container([DataSharingRepository? other]) {
    final c = ProviderContainer(overrides: [dataSharingRepositoryProvider.overrideWithValue(other ?? repository)]);
    addTearDown(c.dispose);
    return c;
  }

  test('everything is off until the user turns it on', () async {
    final c = container();
    await c.read(dataSharingProvider.notifier).load();
    expect(c.read(dataSharingProvider), isEmpty);
    expect(repository.restored, isEmpty);
  });

  test('a choice is applied, saved and restored on the next launch', () async {
    await container().read(dataSharingProvider.notifier).setEnabled(DataSharing.analytics, true);
    expect(repository.calls, [(DataSharing.analytics, true)]);

    final next = container();
    await next.read(dataSharingProvider.notifier).load();
    expect(repository.restored, {DataSharing.analytics});
    expect(next.read(dataSharingProvider), {DataSharing.analytics});
  });

  test('turning it off forgets the saved choice', () async {
    final vm = container().read(dataSharingProvider.notifier);
    await vm.setEnabled(DataSharing.crashReports, true);
    await vm.setEnabled(DataSharing.crashReports, false);
    expect(await storage.read(key: dataSharingKey(DataSharing.crashReports)), isNull);
  });

  test('a refused notification permission changes nothing', () async {
    repository.allowed = false;
    final c = container();
    expect(await c.read(dataSharingProvider.notifier).setEnabled(DataSharing.notifications, true), isFalse);
    expect(c.read(dataSharingProvider), isEmpty);
    expect(await storage.read(key: dataSharingKey(DataSharing.notifications)), isNull);
  });

  test('notifications blocked in the system settings show as off', () async {
    FlutterSecureStorage.setMockInitialValues({dataSharingKey(DataSharing.notifications): 'true'});
    repository.allowed = false;
    final c = container();
    await c.read(dataSharingProvider.notifier).load();
    expect(c.read(dataSharingProvider), isEmpty);
  });

  test('disableAll turns off everything that was on', () async {
    final c = container();
    final vm = c.read(dataSharingProvider.notifier);
    await vm.setEnabled(DataSharing.analytics, true);
    await vm.setEnabled(DataSharing.notifications, true);
    repository.calls.clear();
    await vm.disableAll();
    expect(repository.calls, [(DataSharing.analytics, false), (DataSharing.notifications, false)]);
    expect(c.read(dataSharingProvider), isEmpty);
  });

  test('without Firebase nothing is restored', () async {
    FlutterSecureStorage.setMockInitialValues({dataSharingKey(DataSharing.analytics): 'true'});
    final c = container(const NoDataSharingRepository());
    await c.read(dataSharingProvider.notifier).load();
    expect(c.read(dataSharingProvider), isEmpty);
  });
}
