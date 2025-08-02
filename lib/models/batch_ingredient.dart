import 'package:flutter/material.dart';

class BatchIngredient {
  String name;
  double volume;
  double abv;

  // Add controllers for each field
  final TextEditingController nameController;
  final TextEditingController volumeController;
  final TextEditingController abvController;

  BatchIngredient({this.name = '', this.volume = 0.0, this.abv = 0.0})
      // Initialize controllers with the provided data
      : nameController = TextEditingController(text: name),
        volumeController = TextEditingController(text: volume > 0 ? volume.toString() : ''),
        abvController = TextEditingController(text: abv > 0 ? abv.toString() : '');

  // Dispose method to release resources
  void dispose() {
    nameController.dispose();
    volumeController.dispose();
    abvController.dispose();
  }
}
