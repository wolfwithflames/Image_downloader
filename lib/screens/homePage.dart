import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:device_info/device_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:image_downloader/services/downloadService.dart';
import 'package:image_downloader/utils/taskInfo.dart';
import 'package:image_downloader/widget/imageThumb.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../main.dart';

class MyHomePage extends StatefulWidget with WidgetsBindingObserver {
  final TargetPlatform? platform;

  MyHomePage({Key? key, this.title, this.platform}) : super(key: key);

  final String? title;

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // final _images = [
  //   {
  //     'name': 'Arches National Park',
  //     'link':
  //         'https://upload.wikimedia.org/wikipedia/commons/6/60/The_Organ_at_Arches_National_Park_Utah_Corrected.jpg'
  //   },
  //   {
  //     'name': 'Canyonlands National Park',
  //     'link':
  //         'https://upload.wikimedia.org/wikipedia/commons/7/78/Canyonlands_National_Park%E2%80%A6Needles_area_%286294480744%29.jpg'
  //   },
  //   {
  //     'name': 'Death Valley National Park',
  //     'link':
  //         'https://upload.wikimedia.org/wikipedia/commons/b/b2/Sand_Dunes_in_Death_Valley_National_Park.jpg'
  //   },
  //   {
  //     'name': 'Gates of the Arctic National Park and Preserve',
  //     'link':
  //         'https://upload.wikimedia.org/wikipedia/commons/e/e4/GatesofArctic.jpg'
  //   }
  // ];

  List<TaskInfo>? _tasks;
  late List<ItemHolder> _items;
  late bool _isLoading;
  late bool _permissionReady;
  late String _localPath;
  ReceivePort _port = ReceivePort();

  @override
  void initState() {
    super.initState();

    _bindBackgroundIsolate();

    FlutterDownloader.registerCallback(downloadCallback);

    _isLoading = false;
    _permissionReady = false;

    // _prepare();
  }

  @override
  void dispose() {
    _unbindBackgroundIsolate();
    super.dispose();
  }

  void _bindBackgroundIsolate() {
    bool isSuccess = IsolateNameServer.registerPortWithName(
        _port.sendPort, 'downloader_send_port');
    if (!isSuccess) {
      _unbindBackgroundIsolate();
      _bindBackgroundIsolate();
      return;
    }
    _port.listen((dynamic data) {
      if (debug) {
        print('UI Isolate Callback: $data');
      }
      String? id = data[0];
      DownloadTaskStatus? status = data[1];
      int? progress = data[2];

      if (_tasks != null && _tasks!.isNotEmpty) {
        final task = _tasks!.firstWhere((task) => task.taskId == id);
        setState(() {
          task.status = status;
          task.progress = progress;
        });
      }
    });
  }

  void _unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
  }

  static void downloadCallback(
      String id, DownloadTaskStatus status, int progress) {
    if (debug) {
      print(
          'Background Isolate Callback: task ($id) is in status ($status) and process ($progress)');
    }
    final SendPort send =
        IsolateNameServer.lookupPortByName('downloader_send_port')!;
    send.send([id, status, progress]);
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(widget.title!),
      ),
      body: Builder(
        builder: (context) => _isLoading
            ? new Center(
                child: new CircularProgressIndicator(),
              )
            : _permissionReady
                ? _buildDownloadList()
                : _buildNoPermissionWarning(),
      ),
    );
  }

  Widget _buildDownloadList() {
    return ChangeNotifierProvider(
      create: (context) => DownloadModel(),
      child: Container(
        child: Consumer<DownloadModel>(
          builder: (context, downloadData, _) =>
              FutureBuilder<List<ItemHolder>>(
            future: downloadData.getDownloadList(),
            builder: (BuildContext context,
                AsyncSnapshot<List<ItemHolder>> snapshot) {
              if (snapshot.hasError) {
                return Text("${snapshot.error}");
              }
              if (snapshot.hasData) {
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  children: snapshot.data!
                      .map(
                        (item) => item.task == null
                            ? _buildListSection(item.name!)
                            : Padding(
                                padding: EdgeInsets.all(20),
                                child: DownloadItem(
                                  data: item,
                                  onItemClick: (task) {
                                    _openDownloadedFile(task).then(
                                      (success) {
                                        if (!success) {
                                          Scaffold.of(context).showSnackBar(
                                            SnackBar(
                                              content:
                                                  Text('Cannot open this file'),
                                            ),
                                          );
                                        }
                                      },
                                    );
                                  },
                                  onActionClick: (task) {
                                    downloadData.onActionClick(
                                        task, _localPath);
                                  },
                                  // onActionClick: (task) {
                                  //   if (task.status ==
                                  //       DownloadTaskStatus.undefined) {
                                  //     _requestDownload(task);
                                  //   } else if (task.status ==
                                  //       DownloadTaskStatus.running) {
                                  //     _pauseDownload(task);
                                  //   } else if (task.status ==
                                  //       DownloadTaskStatus.paused) {
                                  //     _resumeDownload(task);
                                  //   } else if (task.status ==
                                  //       DownloadTaskStatus.complete) {
                                  //     _delete(task);
                                  //   } else if (task.status ==
                                  //       DownloadTaskStatus.failed) {
                                  //     _retryDownload(task);
                                  //   }
                                  // },
                                ),
                              ),
                      )
                      .toList(),
                );
              }
              return CircularProgressIndicator();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildListSection(String title) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Text(
          title,
          style: TextStyle(
              fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 18.0),
        ),
      );

  Widget _buildNoPermissionWarning() => Container(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'Please grant accessing storage permission to continue -_-',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blueGrey, fontSize: 18.0),
                ),
              ),
              SizedBox(
                height: 32.0,
              ),
              TextButton(
                onPressed: () {
                  _retryRequestPermission();
                },
                child: Text(
                  'Retry',
                  style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 20.0),
                ),
              )
            ],
          ),
        ),
      );

  Future<void> _retryRequestPermission() async {
    final hasGranted = await _checkPermission();

    if (hasGranted) {
      await _prepareSaveDir();
    }

    setState(() {
      _permissionReady = hasGranted;
    });
  }

  void _requestDownload(TaskInfo task) async {
    task.taskId = await FlutterDownloader.enqueue(
      url: task.link!,
      headers: {"auth": "test_for_sql_encoding"},
      savedDir: _localPath,
      showNotification: true,
      openFileFromNotification: true,
      saveInPublicStorage: true,
    );
  }

  void _cancelDownload(TaskInfo task) async {
    await FlutterDownloader.cancel(taskId: task.taskId!);
  }

  void _pauseDownload(TaskInfo task) async {
    await FlutterDownloader.pause(taskId: task.taskId!);
  }

  void _resumeDownload(TaskInfo task) async {
    String? newTaskId = await FlutterDownloader.resume(taskId: task.taskId!);
    task.taskId = newTaskId;
  }

  void _retryDownload(TaskInfo task) async {
    String? newTaskId = await FlutterDownloader.retry(taskId: task.taskId!);
    task.taskId = newTaskId;
  }

  Future<bool> _openDownloadedFile(TaskInfo? task) {
    if (task != null) {
      return FlutterDownloader.open(taskId: task.taskId!);
    } else {
      return Future.value(false);
    }
  }

  void _delete(TaskInfo task) async {
    await FlutterDownloader.remove(
        taskId: task.taskId!, shouldDeleteContent: true);
    // await _prepare();
    setState(() {});
  }

  Future<bool> _checkPermission() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    if (widget.platform == TargetPlatform.android &&
        androidInfo.version.sdkInt <= 28) {
      final status = await Permission.storage.status;
      if (status != PermissionStatus.granted) {
        final result = await Permission.storage.request();
        if (result == PermissionStatus.granted) {
          return true;
        }
      } else {
        return true;
      }
    } else {
      return true;
    }
    return false;
  }

  // Future<Null> _prepare() async {
  //   final tasks = await FlutterDownloader.loadTasks();

  //   int count = 0;
  //   _tasks = [];
  //   _items = [];

  //   _tasks!.addAll(_images
  //       .map((image) => TaskInfo(name: image['name'], link: image['link'])));

  //   _items.add(ItemHolder(name: 'Images'));
  //   for (int i = count; i < _tasks!.length; i++) {
  //     _items.add(ItemHolder(name: _tasks![i].name, task: _tasks![i]));
  //     count++;
  //   }

  //   tasks!.forEach((task) {
  //     for (TaskInfo info in _tasks!) {
  //       if (info.link == task.url) {
  //         info.taskId = task.taskId;
  //         info.status = task.status;
  //         info.progress = task.progress;
  //       }
  //     }
  //   });

  //   _permissionReady = await _checkPermission();

  //   if (_permissionReady) {
  //     await _prepareSaveDir();
  //   }

  //   setState(() {
  //     _isLoading = false;
  //   });
  // }

  Future<void> _prepareSaveDir() async {
    _localPath = (await _findLocalPath())!;
    final savedDir = Directory(_localPath);
    bool hasExisted = await savedDir.exists();
    if (!hasExisted) {
      savedDir.create();
    }
  }

  Future<String?> _findLocalPath() async {
    var externalStorageDirPath;
    if (Platform.isAndroid) {
      // try {
      //   externalStorageDirPath = await AndroidPathProvider.downloadsPath;
      // } catch (e) {
      final directory = await getExternalStorageDirectory();
      externalStorageDirPath = directory?.path;
      // }
    } else if (Platform.isIOS) {
      externalStorageDirPath =
          (await getApplicationDocumentsDirectory()).absolute.path;
    }
    return externalStorageDirPath;
  }
}
