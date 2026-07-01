import 'package:flutter/material.dart';
import 'video_extractor_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('实用小工具集合'),
        centerTitle: true,
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        children: [
          _buildToolCard(
            context,
            title: '全平台视频提取',
            icon: Icons.video_library,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VideoExtractorPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(BuildContext context, {required String title, required IconData icon, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).primaryColor),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
