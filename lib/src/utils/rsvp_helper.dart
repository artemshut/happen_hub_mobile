import 'package:flutter/material.dart';

Color rsvpColor(String status) {
  switch (status.toLowerCase()) {
    case "accepted":
    case "attending":
    case "going":
      return Colors.green;
    case "declined":
    case "not_going":
    case "cant_go":
      return Colors.red;
    case "maybe":
    case "tentative":
      return Colors.orange;
    default:
      return Colors.grey;
  }
}
