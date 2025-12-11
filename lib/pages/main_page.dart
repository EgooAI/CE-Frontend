import 'package:flutter/material.dart';
import '../models/user.dart';
import 'chat_page.dart';
import 'calendar_page.dart';
import 'task_page.dart';
import 'profile_page.dart';

class MainPage extends StatefulWidget {
  final User user;

  const MainPage({super.key, required this.user});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  final List<GlobalKey<State>> _pageKeys = [
    GlobalKey<State>(), // ChatPage
    GlobalKey<State>(), // CalendarPage
    GlobalKey<State>(), // TaskPage
    GlobalKey<State>(), // ProfilePage
  ];

  // 公共方法：切换到指定页面
  void switchToPage(int index) {
    if (index >= 0 && index < 4) {
      setState(() {
        _currentIndex = index;
      });

      // 触发对应页面的数据刷新
      if (index == 1 || index == 2) {
        final pageState = _pageKeys[index].currentState;
        if (pageState != null && pageState.mounted) {
          (pageState as dynamic).refreshData?.call();
        }
      }
    }
  }

  // 导航到日程的指定日期
  void navigateToScheduleDate(DateTime date) {
    // 先切换到日历页面
    switchToPage(1);

    // 延迟一下确保页面已切换
    Future.delayed(const Duration(milliseconds: 100), () {
      // 获取日历页面状态并跳转到指定日期
      final calendarState = _pageKeys[1].currentState;
      if (calendarState != null && calendarState.mounted) {
        try {
          (calendarState as dynamic).jumpToDate(date);
        } catch (e) {
          print('跳转日期失败: $e');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ChatPage(key: _pageKeys[0]),
          CalendarPage(key: _pageKeys[1]),
          TaskPage(key: _pageKeys[2]),
          ProfilePage(key: _pageKeys[3], initialUser: widget.user),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });

          // 切换到日历或任务页面时，触发数据刷新
          if (index == 1) {
            // 日历页面
            final calendarState = _pageKeys[1].currentState;
            if (calendarState != null && calendarState.mounted) {
              // 使用反射或接口调用刷新方法
              (calendarState as dynamic).refreshData?.call();
            }
          } else if (index == 2) {
            // 任务页面
            final taskState = _pageKeys[2].currentState;
            if (taskState != null && taskState.mounted) {
              (taskState as dynamic).refreshData?.call();
            }
          }
        },
        type: BottomNavigationBarType.fixed, // 确保显示所有标签和图标
        // enableFeedback: false, // 禁用触觉反馈
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: '聊天'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '日历',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.task), label: '任务'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
