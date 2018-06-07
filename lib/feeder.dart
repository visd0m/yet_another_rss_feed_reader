import 'dart:async';

import 'package:feedparser/feedparser.dart';
import 'package:http/http.dart';

class Feeder {
  Future getFeed(String url) async {
    print("fetching $url ... ");
    var response = await get(url);
    print("fetched with code: ${response.statusCode}");
    return parse(response.body);
  }
}
