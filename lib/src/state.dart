import 'package:scoped_model/scoped_model.dart';
import 'models.dart';

/// The class that holds the state
class DbSwitchState extends Model {
  /// Default constructor
  DbSwitchState();

  /// The actual active database
  ActiveDatabase activeDb;
}
