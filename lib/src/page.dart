import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:sqlcool/sqlcool.dart';
import 'package:sqlview/sqlview.dart';
import 'controller.dart';
import 'dialogs.dart';
import 'state.dart';

class _DbSwitcherPageState extends State<DbSwitcherPage> {
  _DbSwitcherPageState(
      {@required this.dbSwitcher,
      this.import = false,
      @required this.exportPath})
      : assert(dbSwitcher != null),
        assert(exportPath != null);

  final DbSwitcher dbSwitcher;
  final bool import;
  final String exportPath;

  SelectBloc _bloc;

  @override
  void initState() {
    //print("DB: ${dbSwitcher.switcherDb.file.path}");
    _bloc = SelectBloc(
      database: dbSwitcher.switcherDb,
      table: "database",
      columns: "id,name,slug",
      orderBy: 'name ASC',
      reactive: true,
      //verbose: true,
    );
    super.initState();
  }

  @override
  void dispose() {
    _bloc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScopedModel<DbSwitchState>(
        model: dbSwitcher.state,
        child: Stack(
          children: <Widget>[
            CrudView(
              bloc: _bloc,
              trailingBuilder: (context, item) {
                int id = int.parse("${item["id"]}");
                Widget buttons = (exportPath == null)
                    ? _TrailingButton(
                        dbSwitcher: dbSwitcher, id: id, item: item)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                              icon: const Icon(Icons.save),
                              onPressed: () => confirmExportDb(
                                  context: context,
                                  id: id,
                                  name: "${item["name"]}",
                                  dbSwitcher: dbSwitcher,
                                  destinationPath: exportPath)),
                          _TrailingButton(
                              dbSwitcher: dbSwitcher, id: id, item: item)
                        ],
                      );
                return buttons;
              },
            ),
            Positioned(
                right: 15.0,
                bottom: 15.0,
                child: FloatingActionButton(
                  child: const Icon(Icons.add),
                  onPressed: () => addProjectDialog(context, dbSwitcher),
                )),
          ],
        ));
  }
}

class _TrailingButton extends StatelessWidget {
  const _TrailingButton(
      {Key key,
      @required this.dbSwitcher,
      @required this.id,
      @required this.item})
      : super(key: key);

  final DbSwitcher dbSwitcher;
  final int id;
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: dbSwitcher.activeDb.id == id
          ? const Icon(Icons.star, color: Colors.yellow)
          : const Icon(Icons.settings_backup_restore),
      onPressed: () =>
          dbSwitcher.switchDb(id: id, slug: "${item["slug"]}").then((_) {
            dbSwitcher.logger.infoFlash("Switched to ${item["name"]}");
          }),
    );
  }
}

/// The main page to manage db switches
class DbSwitcherPage extends StatefulWidget {
  /// Requires a [DbSwitcher] instance
  DbSwitcherPage(
      {@required this.dbSwitcher,
      this.import = false,
      @required this.exportPath});

  /// The main switcher instance
  final DbSwitcher dbSwitcher;

  /// Use the import database feature
  final bool import;

  /// Use the export database feature
  final String exportPath;

  @override
  _DbSwitcherPageState createState() => _DbSwitcherPageState(
      dbSwitcher: dbSwitcher, import: import, exportPath: exportPath);
}
