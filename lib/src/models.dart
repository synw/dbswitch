import 'package:sqlcool/sqlcool.dart';

/// An active database
class ActiveDatabase {
  /// Provide a [path] and an [id]
  ActiveDatabase({this.path, this.id, this.slug, this.db});

  /// The database id in switcher db
  final int id;

  /// The database path on the filesystem
  final String path;

  /// The database slug: a string without any spaces or special characters
  final String slug;

  /// The [Db] object
  Db db;

  /// String representation
  @override
  String toString() {
    String str = "Active database $id:\n";
    str += "- Path: $path\n";
    str += "- Slug: $slug";
    return str;
  }
}
