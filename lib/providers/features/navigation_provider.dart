import 'package:flutter/material.dart';

class NavigationProvider extends ChangeNotifier {
  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;

  // History stack for the main layout tabs
  final List<int> _history = [0];

  void setIndex(int index, {bool clearHistory = false}) {
    if (_selectedIndex == index) return;
    
    if (clearHistory) {
      _history.clear();
    }
    _history.add(index);
    _selectedIndex = index;
    notifyListeners();
  }

  bool goBack() {
    if (_history.length > 1) {
      _history.removeLast();
      _selectedIndex = _history.last;
      notifyListeners();
      return true;
    }
    return false;
  }

  // Helper to check if we can go back in the tab history
  bool get canGoBack => _history.length > 1;
  
  // Named tab navigation helpers
  void openPOS() => setIndex(1);
  void openSessions() => setIndex(0);
  void openDashboard() => setIndex(2);
  void openHistory() => setIndex(3);
  void openWarehouse() => setIndex(4);
  void openCatalog() => setIndex(5);
  void openEmployees() => setIndex(6);
  void openTrash() => setIndex(7);
  void openSettings() => setIndex(8);
  void openReturns() => setIndex(9);
  void openWriteOffs() => setIndex(10);
}
