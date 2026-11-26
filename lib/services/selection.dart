import 'package:flutter/widgets.dart';

import '../modeles/chanson.dart';

/// Les titres cochés pour agir sur plusieurs à la fois (appui long sur un
/// titre pour commencer).
class Selection extends ChangeNotifier {
  final Set<int> _ids = {};
  List<Chanson> _liste = const [];

  /// Vrai dès qu'au moins un titre est coché.
  bool get active => _ids.isNotEmpty;
  int get nombre => _ids.length;
  bool contient(Chanson c) => _ids.contains(c.id);

  /// La liste dans laquelle on sélectionne (pour « Tout sélectionner »).
  List<Chanson> get liste => _liste;

  bool get toutEstCoche =>
      _liste.isNotEmpty && _liste.every((c) => _ids.contains(c.id));

  /// Identifiants des titres cochés, dans l'ordre de la liste.
  List<int> get ids => [
    for (final c in _liste)
      if (_ids.contains(c.id)) c.id,
  ];

  /// Coche ou décoche [c]. [liste] est la liste affichée autour du titre.
  void basculer(Chanson c, List<Chanson> liste) {
    if (!identical(liste, _liste)) {
      // Nouvelle liste : on ne garde que ce qui y figure.
      final ids = {for (final x in liste) x.id};
      _ids.removeWhere((id) => !ids.contains(id));
      _liste = liste;
    }
    if (!_ids.remove(c.id)) _ids.add(c.id);
    notifyListeners();
  }

  void toutBasculer() {
    if (toutEstCoche) {
      _ids.clear();
    } else {
      _ids.addAll(_liste.map((c) => c.id));
    }
    notifyListeners();
  }

  void vider() {
    if (_ids.isEmpty) return;
    _ids.clear();
    notifyListeners();
  }
}

/// Donne accès à la sélection aux titres d'un écran.
class SelectionScope extends InheritedNotifier<Selection> {
  const SelectionScope({
    super.key,
    required Selection selection,
    required super.child,
  }) : super(notifier: selection);

  /// La sélection de l'écran, ou null s'il n'y en a pas (recherche…).
  static Selection? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SelectionScope>()?.notifier;
}
