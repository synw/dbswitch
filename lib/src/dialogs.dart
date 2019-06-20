import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'controller.dart';

/// Confirmation dialog to export the database
void confirmExportDb(
    {@required BuildContext context,
    @required int id,
    @required String name,
    @required String destinationPath,
    @required DbSwitcher dbSwitcher}) {
  showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(title: Text("Export $name ?"), actions: <Widget>[
          FlatButton(
            child: const Text("Cancel"),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          FlatButton(
            child: const Text("Save"),
            onPressed: () {
              dbSwitcher
                  .exportDb(id: id, destinationPath: destinationPath)
                  .catchError((dynamic e) {
                throw (e);
              });
              Navigator.of(context).pop();
            },
          ),
        ]);
      });
}

/// Import a database from storage
void importProjectDialog(
    {BuildContext context, DbSwitcher dbSwitcher, String sourcePath}) {
  final controller = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Name"),
        content: TextField(
          controller: controller,
          autofocus: true,
        ),
        actions: <Widget>[
          FlatButton(
            child: const Text("Cancel"),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          FlatButton(
            child: const Text("Import"),
            onPressed: () {
              dbSwitcher.importDb(
                  name: "${controller.text}", sourcePath: sourcePath);
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

/// A dialog to add a new database
void addProjectDialog(BuildContext context, DbSwitcher dbSwitcher) {
  final controller = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Name"),
        content: TextField(
          controller: controller,
          autofocus: true,
        ),
        actions: <Widget>[
          FlatButton(
            child: const Text("Cancel"),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          FlatButton(
            child: const Text("Save"),
            onPressed: () {
              dbSwitcher.addDb(name: controller.text);
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
