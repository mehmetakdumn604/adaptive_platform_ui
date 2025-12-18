import 'package:flutter/cupertino.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AdaptiveApp(
      title: 'Tab Bar Color Test',
      home: const TestTabColors(),
    );
  }
}

class TestTabColors extends StatefulWidget {
  const TestTabColors({super.key});

  @override
  State<TestTabColors> createState() => _TestTabColorsState();
}

class _TestTabColorsState extends State<TestTabColors> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'Tab Bar Color Test'),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Selected Tab: $_selectedIndex',
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            const Text('Testing selectedItemColor: Red'),
            const Text('Testing unselectedItemColor: Green'),
          ],
        ),
      ),
      bottomNavigationBar: AdaptiveBottomNavigationBar(
        items: [
          // Example 1: PNG asset icon
          AdaptiveNavigationDestination(
            icon: PlatformIcon.asset('assets/icons/house.png', size: 24),
            label: 'Home',
          ),
          // Example 2: SF Symbol with PlatformIcon
          AdaptiveNavigationDestination(
            icon: PlatformIcon.sfSymbol('magnifyingglass', size: 24),
            label: 'Search',
            isSearch: true,
          ),
          // Example 3: Legacy SF Symbol (String)
          AdaptiveNavigationDestination(icon: 'person', label: 'Profile'),
          // Example 4: Legacy SF Symbol
          AdaptiveNavigationDestination(icon: 'gearshape', label: 'Settings'),
        ],
        selectedIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: CupertinoColors.systemRed,
        unselectedItemColor: CupertinoColors.systemGreen,
        useNativeBottomBar: true, // Test with native iOS 26 bar
      ),
    );
  }
}
