import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/config/theme.dart';
import 'package:joyal_music/screens/music_classification_screen.dart';

void main() {
  testWidgets('small phone classification tabs do not overflow', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(411, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: const MusicClassificationScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      tester.getCenter(find.text('整理待处理歌曲')).dy,
      tester.getCenter(find.text('全部重整')).dy,
    );

    await tester.tap(find.text('服务'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('测试连接'), findsOneWidget);
    expect(find.text('恢复默认'), findsOneWidget);
    expect(find.text('清除密钥'), findsOneWidget);
    final actionY = tester.getCenter(find.text('测试连接')).dy;
    expect(tester.getCenter(find.text('恢复默认')).dy, actionY);
    expect(tester.getCenter(find.text('清除密钥')).dy, actionY);
  });
}
