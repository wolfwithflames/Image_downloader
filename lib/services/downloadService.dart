import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:image_downloader/utils/taskInfo.dart';

class DownloadModel extends ChangeNotifier {
  List<ItemHolder> _items = [];
  final _images = [
    {'name': 'Random One', 'link': 'https://picsum.photos/400/300?random=1'},
    {'name': 'Random Two', 'link': 'https://picsum.photos/400/300?random=2'},
    {'name': 'Random Three', 'link': 'https://picsum.photos/400/300?random=3'},
    {'name': 'Random Four', 'link': 'https://picsum.photos/400/300?random=4'},
    {'name': 'Random Five', 'link': 'https://picsum.photos/400/300?random=5'},
    {'name': 'Random Six', 'link': 'https://picsum.photos/400/300?random=6'},
    {'name': 'Random Seven', 'link': 'https://picsum.photos/400/300?random=7'},
    {'name': 'Random Eight', 'link': 'https://picsum.photos/400/300?random=8'},
    {'name': 'Random Nine', 'link': 'https://picsum.photos/400/300?random=9'},
    {'name': 'Random Ten', 'link': 'https://picsum.photos/400/300?random=10'},
    {
      'name': 'Random Eleven',
      'link': 'https://picsum.photos/200/300?random=11'
    },
    {
      'name': 'Random Twelve',
      'link': 'https://picsum.photos/200/300?random=12'
    },
  ];

  Future<List<ItemHolder>> getDownloadList() async {
    final tasks = await FlutterDownloader.loadTasks();

    int count = 0;
    List<TaskInfo>? _tasks = [];

    _tasks.addAll(_images
        .map((image) => TaskInfo(name: image['name'], link: image['link'])));
    _items = [];
    _items.add(ItemHolder(name: 'Images'));
    for (int i = count; i < _tasks.length; i++) {
      _items.add(ItemHolder(name: _tasks[i].name, task: _tasks[i]));
      count++;
    }

    tasks!.forEach((task) {
      for (TaskInfo info in _tasks) {
        if (info.link == task.url) {
          info.taskId = task.taskId;
          info.status = task.status;
          info.progress = task.progress;
        }
      }
    });

    return _items;
  }

  onActionClick(TaskInfo task, String path) {
    if (task.status == DownloadTaskStatus.undefined) {
      _requestDownload(task, path);
    } else if (task.status == DownloadTaskStatus.running) {
      _pauseDownload(task);
    } else if (task.status == DownloadTaskStatus.paused) {
      _resumeDownload(task);
    } else if (task.status == DownloadTaskStatus.complete) {
      _delete(task);
    } else if (task.status == DownloadTaskStatus.failed) {
      _retryDownload(task);
    }
    notifyListeners();
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

  void _delete(TaskInfo task) async {
    await FlutterDownloader.remove(
        taskId: task.taskId!, shouldDeleteContent: true);
  }

  void _requestDownload(TaskInfo task, String path) async {
    task.taskId = await FlutterDownloader.enqueue(
      url: task.link!,
      headers: {"auth": "test_for_sql_encoding"},
      savedDir: path,
      showNotification: true,
      openFileFromNotification: true,
      saveInPublicStorage: true,
    );
  }
}
