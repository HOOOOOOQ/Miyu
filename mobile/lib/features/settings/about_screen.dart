import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../core/theme/miyu_colors.dart';
import '../../providers/core_providers.dart';
import '../../shared/widgets/miyu_logo.dart';
import '../../shared/widgets/miyu_scaffold.dart';
import '../../shared/widgets/section_header.dart';
import '../../services/socket_service.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final socket = ref.read(socketServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MiyuScaffold(
      appBar: AppBar(title: const Text('About Miyu')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          children: [
            const Center(child: MiyuLogo(size: 84)),
            const SizedBox(height: 18),
            Center(
              child: Text('Miyu', style: Theme.of(context).textTheme.headlineLarge),
            ),
            Center(
              child: Text(
                'Version ${AppConfig.appVersion} · ${AppConfig.appEnv}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? MiyuColors.darkTextSecondary : MiyuColors.lightTextSecondary,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Miyu is a messaging app built for calm, focused conversations: '
              'real-time chat, crystal-clear calls and a thoughtful glass interface.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: isDark ? MiyuColors.darkTextSecondary : MiyuColors.lightTextSecondary,
              ),
            ),
            const SectionHeader(title: 'Diagnostics'),
            _InfoCard(
              rows: [
                _InfoRow('API endpoint', AppConfig.normalizedApiBaseUrl),
                _InfoRow('Socket endpoint', AppConfig.normalizedSocketUrl),
                _InfoRow(
                  'Realtime',
                  switch (socket.state) {
                    SocketConnectionState.connected => 'Connected',
                    SocketConnectionState.connecting => 'Connecting',
                    SocketConnectionState.disconnected => 'Disconnected',
                    SocketConnectionState.failed => 'Failed',
                    SocketConnectionState.idle => 'Idle',
                  },
                ),
                const _InfoRow('Google sign-in', 'Verified server-side'),
                const _InfoRow('Calls', 'WebRTC + TURN relay'),
              ],
            ),
            const SectionHeader(title: 'Data & storage'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Messages are stored on Miyu servers. Miyu does not claim end-to-end '
                'encryption; transport is protected with TLS and media is stored in a '
                'managed cloud bucket. You can delete your account from Settings → Security.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.55,
                  color: isDark ? MiyuColors.darkTextSecondary : MiyuColors.lightTextSecondary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                '© ${DateTime.now().year} Miyu',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? MiyuColors.darkTextSecondary : MiyuColors.lightTextSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? MiyuColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? MiyuColors.darkBorder : MiyuColors.lightBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    rows[i].label,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  rows[i].value,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? MiyuColors.darkTextSecondary : MiyuColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
            if (i != rows.length - 1) const Divider(height: 20),
          ],
        ],
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;
}
