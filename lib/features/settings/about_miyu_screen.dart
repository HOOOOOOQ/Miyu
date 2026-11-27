import 'package:flutter/material.dart';
import 'package:miyu/features/settings/about_miyu_section.dart';
import 'package:miyu/theme/theme.dart';

/// Screen opened from Settings → About Miyu.
/// Navigation: Settings → About Miyu → {About Miyu, Developer Profile, Social Media, Support Miyu}.
class AboutMiyuScreen extends StatelessWidget {
  const AboutMiyuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MiyuColors.bgDark,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: MiyuColors.textDark,
            title: Text('About Miyu', style: TextStyle(fontFamily: 'Figtree', fontWeight: FontWeight.w700)),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: AboutMiyuSection(),
            ),
          ),
        ],
      ),
    );
  }
}
