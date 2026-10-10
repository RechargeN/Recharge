enum WorkspaceType { personal, page }

class WorkspaceRef {
  const WorkspaceRef({required this.type, required this.id});

  factory WorkspaceRef.personal(String userId) {
    return WorkspaceRef(type: WorkspaceType.personal, id: userId);
  }

  factory WorkspaceRef.page(String pageId) {
    return WorkspaceRef(type: WorkspaceType.page, id: pageId);
  }

  final WorkspaceType type;
  final String id;

  bool get isPersonal => type == WorkspaceType.personal;
  bool get isPage => type == WorkspaceType.page;

  @override
  bool operator ==(Object other) {
    return other is WorkspaceRef && other.type == type && other.id == id;
  }

  @override
  int get hashCode => Object.hash(type, id);
}
