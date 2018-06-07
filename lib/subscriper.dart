import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class Subscriber {
  saveSubscriptions(Map<String, dynamic> subscriptions) async {
    print("saving subscriptions: $subscriptions");

    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;

    File file = new File("$appDocPath/subscriptions.txt");
    file.writeAsString(json.encode(subscriptions));
  }

  Future<Map<String, dynamic>> loadSubscriptions() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    String filePath = "$appDocPath/subscriptions.txt";

    Map<String, dynamic> subscriptions = {
      "https://hnrss.org/frontpage": "HN",
      "http://www.ansa.it/sito/ansait_rss.xml": "ANSA",
      "https://feedpress.me/saggiamente": "SAGGIAMENTE",
      "https://www.everyeye.it/feed_news_rss.asp": "EVERYEYE"
    };

    if (FileSystemEntity.typeSync(filePath) != FileSystemEntityType.notFound) {
      print("saved subscriptions found");

      File file = new File(filePath);
      String jsonSubscriptions = await file.readAsString();
      subscriptions = json.decode(jsonSubscriptions);
    } else {
      saveSubscriptions(subscriptions);
    }

    print("loaded subscriptions: $subscriptions");
    return subscriptions;
  }
}
