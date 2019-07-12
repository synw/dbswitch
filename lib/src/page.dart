import 'package:dbswitch/src/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:sqlcool/sqlcool.dart';
import 'package:sqlview/sqlview.dart';
import 'controller.dart';
import 'dialogs.dart';

class _DbSwitcherPageState extends State<DbSwitcherPage> {
  _DbSwitcherPageState(
      {@required this.dbSwitcher,
      this.import = false,
      @required this.storagePath})
      : assert(dbSwitcher != null),
        assert(storagePath != null);

  final DbSwitcher dbSwitcher;
  final bool import;
  final String storagePath;

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
    return StreamProvider<ActiveDatabase>.value(
        initialData: dbSwitcher.activeDatabase,
        value: dbSwitcher.changefeed,
        child: Stack(
          children: <Widget>[
            CrudView(
              bloc: _bloc,
              trailingBuilder: (context, item) {
                int id = int.parse("${item["id"]}");
                Widget buttons = (storagePath == null)
                    ? _TrailingButton(
                        dbSwitcher: dbSwitcher, id: id, item: item)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (dbSwitcher.enableImportExport == true)
                            IconButton(
                                icon: const Icon(Icons.file_upload),
                                onPressed: () => confirmExportDb(
                                    context: context,
                                    id: id,
                                    name: "${item["name"]}",
                                    dbSwitcher: dbSwitcher,
                                    destinationPath: storagePath)),
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
                  heroTag: "addProject",
                  child: const Icon(Icons.add, color: Colors.yellow),
                  onPressed: () => addProjectDialog(context, dbSwitcher),
                )),
            if (dbSwitcher.enableImportExport == true)
              Positioned(
                  right: 15.0,
                  bottom: 85.0,
                  child: FloatingActionButton(
                      heroTag: "importProject",
                      child: const Icon(Icons.file_download,
                          color: Colors.blueGrey),
                      onPressed: () => importProjectDialog(
                          context: context,
                          dbSwitcher: dbSwitcher,
                          sourcePath: "$storagePath"))),
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
      icon: Provider.of<ActiveDatabase>(context).id == id
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
      @required this.storagePath});

  /// The main switcher instance
  final DbSwitcher dbSwitcher;

  /// Use the import database feature
  final bool import;

  /// Use the export database feature
  final String storagePath;

  @override
  _DbSwitcherPageState createState() => _DbSwitcherPageState(
      dbSwitcher: dbSwitcher, import: import, storagePath: storagePath);
}
