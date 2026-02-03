import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../common/native_context_menu.dart';
import '../../models/chat/conversation.dart';

/// 会话侧边菜单组件
class ConversationDrawer extends StatelessWidget {
  final TextEditingController searchController;
  final bool isSearching;
  final List<Conversation> conversations;
  final List<Conversation> searchResults;
  final String searchError;
  final Conversation? currentConversation;
  final VoidCallback onCreateConversation;
  final VoidCallback onPerformSearch;
  final VoidCallback onClearSearch;
  final Function(Conversation, {bool closeDrawer}) onSelectConversation;
  final Function(Conversation, int) onEditConversationTitle;
  final Function(Conversation, int) onDeleteConversation;

  const ConversationDrawer({
    super.key,
    required this.searchController,
    required this.isSearching,
    required this.conversations,
    required this.searchResults,
    required this.searchError,
    required this.currentConversation,
    required this.onCreateConversation,
    required this.onPerformSearch,
    required this.onClearSearch,
    required this.onSelectConversation,
    required this.onEditConversationTitle,
    required this.onDeleteConversation,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 340,
      backgroundColor: Colors.grey[100],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(0)),
      ),
      child: Column(
        children: [
          // Status bar 背景填充
          Container(
            height: MediaQuery.of(context).viewPadding.top,
            color: Colors.grey[100],
          ),
          SafeArea(
            bottom: false,
            top: false,
            child: Container(
              color: Colors.grey[100],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: '搜索会话标题...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  searchController.clear();
                                  onClearSearch();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          borderSide: BorderSide(color: Colors.blue, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => onPerformSearch(),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('新建对话'),
                    onTap: onCreateConversation,
                  ),
                  const Divider(height: 1),
                ],
              ),
            ),
          ),
          Expanded(child: ClipRect(child: _buildConversationList(context))),
        ],
      ),
    );
  }

  /// 构建会话列表（根据搜索状态显示不同内容）
  Widget _buildConversationList(BuildContext context) {
    // 如果正在搜索，显示搜索结果
    if (isSearching) {
      if (searchError.isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              searchError,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }

      if (searchResults.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text('未搜索到相关会话', style: TextStyle(color: Colors.grey)),
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.zero,
        clipBehavior: Clip.hardEdge,
        itemCount: searchResults.length,
        itemBuilder: (context, index) {
          final conversation = searchResults[index];
          return _buildConversationItem(context, conversation, index);
        },
      );
    }

    // 正常显示全部会话
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      clipBehavior: Clip.hardEdge,
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        return _buildConversationItem(context, conversation, index);
      },
    );
  }

  /// 构建单个会话项
  Widget _buildConversationItem(
    BuildContext context,
    Conversation conversation,
    int index,
  ) {
    final tile = ListTile(
      title: Text(conversation.title),
      subtitle: Text(conversation.updatedAt.toString().split('.')[0]),
      selected: currentConversation?.id == conversation.id,
      selectedTileColor: Colors.grey[300],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      onTap: () => onSelectConversation(conversation, closeDrawer: true),
    );

    final child = NativeContextMenu(
      actions: [
        NativeContextMenuItem(title: '置顶', onSelected: () async {}),
        NativeContextMenuItem(
          title: '编辑对话名称',
          onSelected: () async {
            onEditConversationTitle(conversation, index);
          },
        ),
        NativeContextMenuItem(title: '分享对话', onSelected: () async {}),
        NativeContextMenuItem(
          title: '从对话列表删除',
          isDestructive: true,
          onSelected: () async {
            await _handleDeleteConversation(context, conversation, index);
          },
        ),
      ],
      child: tile,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0.0),
      child: child,
    );
  }

  Future<void> _handleDeleteConversation(
    BuildContext context,
    Conversation conversation,
    int index,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除对话'),
        content: const Text('确定要删除这个对话吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      onDeleteConversation(conversation, index);
    }
  }
}
