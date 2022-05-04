// To parse this JSON data, do
//
//     final blueModel = blueModelFromJson(jsonString);

import 'dart:convert';

List<BlueModel> blueModelFromJson(String str) => List<BlueModel>.from(json.decode(str).map((x) => BlueModel.fromJson(x)));

String blueModelToJson(List<BlueModel> data) => json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class BlueModel {
  BlueModel({
    this.id,
    this.name,
    this.isRemoved,
  });

  String? id;
  String? name;
  bool? isRemoved;

  factory BlueModel.fromJson(Map<String, dynamic> json) => BlueModel(
    id: json["id"],
    name: json["name"],
    isRemoved: json["isRemoved"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "isRemoved": isRemoved,
  };
}
