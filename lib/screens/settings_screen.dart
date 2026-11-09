import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정', key: Key('settingsTitle')),
      ),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.person),
            title: Text('계정 정보'),
            subtitle: Text('로그인 상태 및 프로필 관리'),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.notifications),
            title: Text('알림 설정'),
            subtitle: Text('푸시 알림 및 리마인더 수신 여부'),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.info),
            title: Text('앱 정보'),
            subtitle: Text('Keepy v1.0.0'),
          ),
        ],
      ),
    );
  }
}