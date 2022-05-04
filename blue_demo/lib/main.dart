import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:blue_demo/utils/helper.dart';
import 'package:blue_demo/models/BlueModel.dart';
import 'package:blue_demo/utils/widget_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'widgets.dart';

void main() {
  runApp(const FlutterBlueApp());
}

class FlutterBlueApp extends StatelessWidget {
  const FlutterBlueApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.lightBlue,
      home: StreamBuilder<BluetoothState>(
          stream: FlutterBluePlus.instance.state,
          initialData: BluetoothState.unknown,
          builder: (c, snapshot) {
            final state = snapshot.data;
            if (state == BluetoothState.on) {
              return FindDevicesScreen();
            }
            return BluetoothOffScreen(state: state);
          }),
    );
  }
}

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({Key? key, this.state}) : super(key: key);

  final BluetoothState? state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.white54,
            ),
            Text(
              'Bluetooth Adapter is ${state != null ? state.toString().substring(15) : 'not available'}.',
              style: Theme.of(context)
                  .primaryTextTheme
                  .subtitle2
                  ?.copyWith(color: Colors.white),
            ),
            ElevatedButton(
              child: const Text('TURN ON'),
              onPressed: Platform.isAndroid
                  ? () => FlutterBluePlus.instance.turnOn()
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class FindDevicesScreen extends StatefulWidget {
  FindDevicesScreen({Key? key}) : super(key: key);

  @override
  State<FindDevicesScreen> createState() => _FindDevicesScreenState();
}

class _FindDevicesScreenState extends State<FindDevicesScreen> {
  List<BlueModel> blueList = [];
  bool isPairedDevices = false;
  TextEditingController changeNameController = TextEditingController();

  ButtonStyle bs() => ElevatedButton.styleFrom(
        primary: Colors.blue,
        onPrimary: Colors.white,
        minimumSize: const Size.fromHeight(50), // SETTING THE FULL SIZED BUTTON
      );

  @override
  void initState() {
    //Setting blue list from local data
    Future.delayed(const Duration(microseconds: 1), () async {
      blueList = await getBlueList();
      setState(() {});
    });
    super.initState();
  }

  void editNameDialog(String deviceId, String name) {
    changeNameController.text = name;
    AlertDialog alert = AlertDialog(
      title: const Text("Edit Name"),
      content: customTextField(controller: changeNameController, size: MediaQuery.of(context).size, onChange: (e) {}),
      actions: [
        ElevatedButton(
          child: const Text('DONE'),
          style: bs(),
          onPressed: () async  {
            if (changeNameController.text.trim() != "" && changeNameController.text.trim().isNotEmpty) {
              int index = blueList.indexWhere((e) => e.id == deviceId);
              await changeNameOfModel(deviceId, changeNameController.text); // Setting element in local db that it is removed now
              setState(() {
                blueList.elementAt(index).name = changeNameController.text;
              });
            }

            Navigator.pop(context);
          }
        )
      ],
    );

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      drawer: getDrawer(), // getting drawer
      appBar: AppBar(
        title: const Text('Bluetooth Demo'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () => FlutterBluePlus.instance
            .startScan(timeout: const Duration(seconds: 4)),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              const SizedBox(height: 15),
              if (isPairedDevices)
                StreamBuilder<List<BluetoothDevice>>(
                  stream: Stream.periodic(const Duration(seconds: 2))
                      .asyncMap((_) => FlutterBluePlus.instance.bondedDevices),
                  initialData: const [],
                  builder: (c, snapshot) {
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      return Column(
                        children: snapshot.data!
                            .map((d) {
                          bool check = blueList.any((e) => e.id == d.id.id);
                          BlueModel model = BlueModel(name: d.name, id: d.id.id, isRemoved: false);
                          if(check) {
                            model = blueList.where((e) => e.id == d.id.id).single;
                          } else {
                            setBlueModelData(model);
                            blueList.add(model);
                          }

                          return model.isRemoved! ? Container() :  ListTile(
                                title: Text(model.name!),
                                subtitle: Text(d.id.toString()),
                                trailing: StreamBuilder<BluetoothDeviceState>(
                                  stream: d.state,
                                  initialData:
                                  BluetoothDeviceState.disconnected,
                                  builder: (c, snapshot) {
                                    if (snapshot.data ==
                                        BluetoothDeviceState.connected) {
                                      return ElevatedButton(
                                        child: const Text('OPEN'),
                                        onPressed: () => Navigator.of(context)
                                            .push(MaterialPageRoute(
                                            builder: (context) =>
                                                DeviceScreen(device: d, deviceName: model.name,))),
                                      );
                                    }
                                    return SizedBox(
                                      width: size.width / 3,
                                      child: Row(children: <Widget>[
                                        IconButton(
                                            onPressed: () async {
                                              await addFirstIfNotAvailable(model);
                                              editNameDialog(d.id.id, model.name!);
                                            },
                                            icon: const Icon(Icons.edit, color: Colors.blue)),
                                        IconButton(
                                            onPressed: () async {
                                              await addFirstIfNotAvailable(model);
                                              int index = blueList.indexWhere((e) => e.id == d.id.id);
                                              await setIsRemoved(d.id.id); // Setting element in local db that it is removed now
                                              setState(() {
                                                blueList.elementAt(index).isRemoved = true;
                                              });
                                            },
                                            icon: const Icon(Icons.delete, color: Colors.red)),
                                      ]),
                                    ); // snapshot.data.toString()
                                  },
                                ),
                              );
                        })
                            .toList(),
                      );
                    }
                    return const Center(
                        child: Text("NO PAIRED DEVICES FOUND!!"));
                  },
                ),
              if (!isPairedDevices)
                StreamBuilder<List<ScanResult>>(
                    stream: FlutterBluePlus.instance.scanResults,
                    initialData: const [],
                    builder: (c, snapshot) {
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        return Column(
                          children: snapshot.data!.map(
                            (r)  {
                              bool check = blueList.any((e) => e.id == r.device.id.id);
                              BlueModel model = BlueModel(name: r.device.name, id: r.device.id.id, isRemoved: false);
                              if(check) {
                                model = blueList.where((e) => e.id == r.device.id.id).single;
                              } else {
                                setBlueModelData(model);
                                blueList.add(model);
                              }

                              // Checking if the element is removed now no need to show that element
                              return model.isRemoved! ? Container() :  ScanResultTile(
                                deviceName: model.name!,
                                result: r,
                                edit: () async {
                                  await addFirstIfNotAvailable(model);
                                  editNameDialog(r.device.id.id, model.name!);
                                },
                                remove: () async {
                                  await addFirstIfNotAvailable(model);
                                  int index = blueList.indexWhere((e) => e.id == r.device.id.id);
                                  await setIsRemoved(r.device.id.id); // Setting element in local db that it is removed now
                                  setState(() {
                                    blueList.elementAt(index).isRemoved = true;
                                  });

                                },
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (context) {
                                      r.device.connect();
                                      return DeviceScreen(device: r.device, deviceName: model.name);
                                    }),
                                  );
                                },
                              );
                            },
                          ).toList(),
                        );
                      }
                      return const Center(
                          child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                            "NO CONNECTABLE DEVICES FOUND - PRESS SCAN BUTTON !!"),
                      ));
                    }),
            ],
          ),
        ),
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: FlutterBluePlus.instance.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data!) {
            return FloatingActionButton(
              child: const Icon(Icons.stop),
              onPressed: () => FlutterBluePlus.instance.stopScan(),
              backgroundColor: Colors.red,
            );
          } else {
            return FloatingActionButton(
                child: const Icon(Icons.search),
                onPressed: () => FlutterBluePlus.instance
                    .startScan(timeout: const Duration(seconds: 4)));
          }
        },
      ),
    );
  }

  Drawer getDrawer() {
    return Drawer(
      child: Container(
        margin:
        EdgeInsets.fromLTRB(0, MediaQuery.of(context).padding.top, 0, 0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  ElevatedButton(
                    child: const Text('TURN OFF'),
                    style: bs(),
                    onPressed: Platform.isAndroid
                        ? () => FlutterBluePlus.instance.turnOff()
                        : null,
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    child: const Text('PAIRED DEVICES'),
                    style: bs(),
                    onPressed: () {
                      setState(() {
                        isPairedDevices = true;
                      });
                      Fluttertoast.showToast(msg: "PAIRED DEVICES AVAILABLE");
                    },
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    child: const Text('CONNECTABLE DEVICES'),
                    style: bs(),
                    onPressed: () {
                      setState(() {
                        isPairedDevices = false;
                      });
                      Fluttertoast.showToast(
                          msg: "CONNECTABLE DEVICES AVAILABLE");
                    },
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    child: const Text('SHOW REMOVED DEVICES'),
                    style: bs(),
                    onPressed: () async {
                      blueList.map((e) => e.isRemoved = false).toList();
                      await setAllDevicesVisible();
                      setState(() {});
                      Fluttertoast.showToast(
                          msg: "ALL DEVICES VISIBLE");
                    },
                  ),
                  const SizedBox(height: 25),
                  //Showing simple note
                  const Text(
                    "Note: Only paired devices will be showing here if not paired, then paired from your settings.",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({Key? key, required this.device, this.deviceName}) : super(key: key);

  final BluetoothDevice device;
  final String? deviceName;

  List<int> _getRandomBytes() {
    final math = Random();
    return [
      math.nextInt(255),
      math.nextInt(255),
      math.nextInt(255),
      math.nextInt(255)
    ];
  }

  List<Widget> _buildServiceTiles(List<BluetoothService> services) {
    return services
        .map(
          (s) => ServiceTile(
            service: s,
            characteristicTiles: s.characteristics
                .map(
                  (c) => CharacteristicTile(
                    characteristic: c,
                    onReadPressed: () => c.read(),
                    onWritePressed: () async {
                      await c.write(_getRandomBytes(), withoutResponse: true);
                      await c.read();
                    },
                    onNotificationPressed: () async {
                      await c.setNotifyValue(!c.isNotifying);
                      await c.read();
                    },
                    descriptorTiles: c.descriptors
                        .map(
                          (d) => DescriptorTile(
                            descriptor: d,
                            onReadPressed: () => d.read(),
                            onWritePressed: () => d.write(_getRandomBytes()),
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(deviceName ?? device.name),
        actions: <Widget>[
          StreamBuilder<BluetoothDeviceState>(
            stream: device.state,
            initialData: BluetoothDeviceState.connecting,
            builder: (c, snapshot) {
              VoidCallback? onPressed;
              String text;
              switch (snapshot.data) {
                case BluetoothDeviceState.connected:
                  onPressed = () => device.disconnect();
                  text = 'DISCONNECT';
                  break;
                case BluetoothDeviceState.disconnected:
                  onPressed = () => device.connect();
                  text = 'CONNECT';
                  break;
                default:
                  onPressed = null;
                  text = snapshot.data.toString().substring(21).toUpperCase();
                  break;
              }
              return TextButton(
                  onPressed: onPressed,
                  child: Text(
                    text,
                    style: Theme.of(context)
                        .primaryTextTheme
                        .button
                        ?.copyWith(color: Colors.white),
                  ));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            StreamBuilder<BluetoothDeviceState>(
              stream: device.state,
              initialData: BluetoothDeviceState.connecting,
              builder: (c, snapshot) => ListTile(
                leading: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    snapshot.data == BluetoothDeviceState.connected
                        ? const Icon(Icons.bluetooth_connected)
                        : const Icon(Icons.bluetooth_disabled),
                    snapshot.data == BluetoothDeviceState.connected
                        ? StreamBuilder<int>(
                            stream: rssiStream(),
                            builder: (context, snapshot) {
                              return Text(
                                  snapshot.hasData ? '${snapshot.data}dBm' : '',
                                  style: Theme.of(context).textTheme.caption);
                            })
                        : Text('', style: Theme.of(context).textTheme.caption),
                  ],
                ),
                title: Text(
                    'Device is ${snapshot.data.toString().split('.')[1]}.'),
                subtitle: Text('${device.id}'),
                trailing: StreamBuilder<bool>(
                  stream: device.isDiscoveringServices,
                  initialData: false,
                  builder: (c, snapshot) => IndexedStack(
                    index: snapshot.data! ? 1 : 0,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => device.discoverServices(),
                      ),
                      const IconButton(
                        icon: SizedBox(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Colors.grey),
                          ),
                          width: 18.0,
                          height: 18.0,
                        ),
                        onPressed: null,
                      )
                    ],
                  ),
                ),
              ),
            ),
            StreamBuilder<int>(
              stream: device.mtu,
              initialData: 0,
              builder: (c, snapshot) => ListTile(
                title: const Text('MTU Size'),
                subtitle: Text('${snapshot.data} bytes'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => device.requestMtu(223),
                ),
              ),
            ),
            StreamBuilder<List<BluetoothService>>(
              stream: device.services,
              initialData: const [],
              builder: (c, snapshot) {
                return Column(
                  children: _buildServiceTiles(snapshot.data!),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Stream<int> rssiStream() async* {
    var isConnected = true;
    final subscription = device.state.listen((state) {
      isConnected = state == BluetoothDeviceState.connected;
    });
    while (isConnected) {
      yield await device.readRssi();
      await Future.delayed(Duration(seconds: 1));
    }
    subscription.cancel();
    // Device disconnected, stopping RSSI stream
  }
}
