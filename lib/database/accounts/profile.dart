import 'package:drift/drift.dart';

class Profile extends Table {
  TextColumn get id => text()();

  // Profile picture data
  TextColumn get pictureContainer => text()();

  TextColumn get data => text()();

  @override
  Set<Column> get primaryKey => {id};
}
