typedef CrudAction = Future<void> Function();

typedef ForceRefreshAction = Future<void> Function();

/// 执行 CRUD 后强制刷新，确保缓存与页面数据最新
Future<void> runCrudWithForceRefresh({
  required CrudAction action,
  required ForceRefreshAction forceRefresh,
}) async {
  await action();
  await forceRefresh();
}
