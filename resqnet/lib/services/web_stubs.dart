class File {
  final String path;
  File(this.path);
  File get absolute => this;
  Future<File> copy(String path) async => File(path);
  bool existsSync() => false;
}

class Directory {
  final String path;
  Directory(this.path);
}
