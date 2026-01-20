import 'package:flutter/material.dart';

/// 聊天页面欢迎引导组件
class WelcomeGuide extends StatelessWidget {
  final bool showFullGuide;
  final Function(String) onExampleTap;

  const WelcomeGuide({
    super.key,
    required this.showFullGuide,
    required this.onExampleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 仅当没有对话列表时显示完整教程
            if (showFullGuide) ...[
              // 主图标
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  size: 50,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 24),

              // 欢迎标题
              const Text(
                '👋 欢迎使用 懒得记',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              // 副标题
              Text(
                '我可以帮你完成以下任务',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),

              // 功能卡片
              _buildFeatureCard(
                icon: Icons.calendar_today,
                title: '📅 智能日程管理',
                description: '你可以直接将通知信息复制到这里，也可以告诉我"明天下午3点开会"，我会自动为您解析日程',
                color: Colors.blue,
              ),
              const SizedBox(height: 16),

              _buildFeatureCard(
                icon: Icons.mic,
                title: '🎤 语音输入',
                description: '点击麦克风图标，用语音快速输入消息',
                color: Colors.orange,
              ),
              const SizedBox(height: 16),

              _buildFeatureCard(
                icon: Icons.psychology,
                title: '🤖 智能对话',
                description: '我会记住对话上下文，提供更精准的回答',
                color: Colors.purple,
              ),
              const SizedBox(height: 32),
            ],
            // 所有情况下都显示'试试这些问题'
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 20,
                        color: Colors.amber[700],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '试试这些问题',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildExampleChip('帮我安排明天上午10点的会议'),
                  const SizedBox(height: 8),
                  _buildExampleChip('提醒我下周五交报告'),
                  const SizedBox(height: 8),
                  _buildExampleChip('今天有什么安排？'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 开始提示
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_downward, size: 20, color: Colors.grey[400]),
                const SizedBox(width: 8),
                Text(
                  '在下方输入框开始对话',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleChip(String text) {
    return InkWell(
      onTap: () => onExampleTap(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.arrow_forward, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
