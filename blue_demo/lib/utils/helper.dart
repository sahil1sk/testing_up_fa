import 'dart:convert';

import 'package:blue_demo/models/BlueModel.dart';
import 'package:shared_preferences/shared_preferences.dart';

const blueKey = "blueKey";

Future<SharedPreferences> getSharedInstance() async {
  return await SharedPreferences.getInstance();
}

Future<String> getString() async {
  final prefs = await getSharedInstance();
  return prefs.getString(blueKey) ?? jsonEncode(List.empty());
}

Future<void> setString(String str) async {
  final prefs = await getSharedInstance();
  prefs.setString(blueKey, str);
}

//If we have string then convert it into list and return it otherwise return empty string
Future<List<BlueModel>> getBlueList() async {
  return blueModelFromJson(await getString());
}

//In this we are checking that if we have list then add one more object to it and save it
// and then if we don't have then create new list and save it.
Future<void> setBlueModelData(BlueModel model) async {
  final data = jsonDecode(await getString());
  print("get list");
  print(data);
  data.add(model.toJson());
  print("setting data");
  print(data);
  await setString(jsonEncode(data));
}

Future<void> addFirstIfNotAvailable(BlueModel model) async {
  List<BlueModel> list = blueModelFromJson(await getString());
  bool check = list.any((e) => e.id == model.id);
  if(check) {
    return;
  }else {
    list.add(model);
    await setString(blueModelToJson(list));
  }
}

// Means we are removing the element from the list to not show them
Future<void> setIsRemoved(String id) async {
  List<BlueModel> list = blueModelFromJson(await getString());
  print("list is here");
  print(list);
  int index = list.indexWhere((e) => e.id == id);
  list[index].isRemoved = true;
  await setString(blueModelToJson(list));
}

//Changing the name from the list so that it will sync the name from here to get the latest name
Future<void> changeNameOfModel(String id, String name) async {
  List<BlueModel> list = blueModelFromJson(await getString());
  int index = list.indexWhere((e) => e.id == id);
  list[index].name = name;
  setString(blueModelToJson(list));
}

// Setting all devices visible, this function is triggered from the drawer
Future<void> setAllDevicesVisible() async {
  List<BlueModel> list = blueModelFromJson(await getString());
  list.map((e) => e.isRemoved = false).toList();
  setString(blueModelToJson([]));
}

