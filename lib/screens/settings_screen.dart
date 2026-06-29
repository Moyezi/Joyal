import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../providers/auth_provider.dart';

/// Navidrome 服务器连接设置页面。
///
/// 用户在「我的」页面右上角点击设置图标进入此页面，
/// 填写 NAS 上 Navidrome 的地址、用户名和密码后建立连接。
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _baseUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // 回填已保存的凭据
    final auth = ref.read(authProvider);
    _baseUrlController.text = auth.baseUrl ?? '';
    _usernameController.text = auth.username ?? '';
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final baseUrl = _baseUrlController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (baseUrl.isEmpty || username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写完整的连接信息')));
      return;
    }

    await ref
        .read(authProvider.notifier)
        .connect(baseUrl: baseUrl, username: username, password: password);

    if (mounted) {
      final authState = ref.read(authProvider);
      if (authState.isConnected) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('连接成功')));
        Navigator.of(context).pop();
      } else if (authState.error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('连接失败: ${authState.error}')));
      }
    }
  }

  Future<void> _disconnect() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('断开连接'),
        content: const Text('确定要断开与服务器的连接并清除凭据吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '确定',
              style: TextStyle(color: context.favoriteRedColor),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authProvider.notifier).disconnect();
      _baseUrlController.clear();
      _usernameController.clear();
      _passwordController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('服务器设置')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        children: [
          // ── 连接状态 ──
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: authState.isConnected
                  ? Colors.green.withValues(alpha: 0.08)
                  : context.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Row(
              children: [
                Icon(
                  authState.isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: authState.isConnected
                      ? Colors.green
                      : context.secondaryColor,
                ),
                const SizedBox(width: AppTheme.spacingSM),
                Text(
                  authState.isConnected ? '已连接' : '未连接',
                  style: context.textTitleMedium.copyWith(
                    color: authState.isConnected
                        ? Colors.green.shade700
                        : context.secondaryColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacingXL),

          // ── 服务器地址 ──
          _SectionLabel('服务器地址'),
          const SizedBox(height: AppTheme.spacingSM),
          TextField(
            controller: _baseUrlController,
            style: context.textBodyLarge,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: 'http://nas.local:4533',
              hintStyle: context.textBodyMedium,
              prefixIcon: const Icon(Icons.dns_outlined, size: 20),
              filled: true,
              fillColor: context.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMD,
                vertical: 14,
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacingLG),

          // ── 用户名 ──
          _SectionLabel('用户名'),
          const SizedBox(height: AppTheme.spacingSM),
          TextField(
            controller: _usernameController,
            style: context.textBodyLarge,
            decoration: InputDecoration(
              hintText: '输入 Navidrome 用户名',
              hintStyle: context.textBodyMedium,
              prefixIcon: const Icon(Icons.person_outline, size: 20),
              filled: true,
              fillColor: context.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMD,
                vertical: 14,
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacingLG),

          // ── 密码 ──
          _SectionLabel('密码'),
          const SizedBox(height: AppTheme.spacingSM),
          TextField(
            controller: _passwordController,
            style: context.textBodyLarge,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: '输入密码',
              hintStyle: context.textBodyMedium,
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              filled: true,
              fillColor: context.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMD,
                vertical: 14,
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacingXL),

          // ── 连接按钮 ──
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: authState.isLoading ? null : _connect,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? context.surfaceColor
                    : context.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                elevation: 0,
              ),
              child: authState.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '连接服务器',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),

          // ── 断开连接 ──
          if (authState.isConnected) ...[
            const SizedBox(height: AppTheme.spacingMD),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _disconnect,
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.favoriteRedColor,
                  side: BorderSide(color: context.favoriteRedColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                ),
                child: const Text('断开连接', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],

          const SizedBox(height: AppTheme.spacingXL),

          // ── 说明 ──
          Text(
            '请输入你部署在 NAS 上的 Navidrome 服务器地址。\n'
            '连接采用 Subsonic Token 认证，密码不会明文传输。',
            style: context.textCaption,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: context.textTitleMedium);
  }
}
