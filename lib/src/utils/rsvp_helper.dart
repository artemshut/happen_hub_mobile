import 'package:flutter/material.dart';

Color rsvpColor(String status) {
  switch (status) {
    case "accepted":
      return Colors.green;
    case "declined":
      return Colors.red;
    case "maybe":
      return Colors.orange;
    default:
      return Colors.grey;
  }
}