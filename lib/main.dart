import 'dart:async';

import 'package:feedparser/feedparser.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:url_launcher/url_launcher.dart';

final Map<String, String> tagsByUrls = {
  "https://hnrss.org/frontpage": "HN",
  "http://www.ansa.it/sito/ansait_rss.xml": "ANSA",
//  "https://feedpress.me/saggiamente": "SAGGIAMENTE",
  "https://www.everyeye.it/feed_news_rss.asp": "EVERYEYE"
};

void main() => runApp(new MyApp());

// ========================= APP

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Yet another feeder',
      theme: new ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: new MyHomePage(title: 'Yet another rss feed reader'),
    );
  }
}

// ========================= HOME PAGE

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  State<StatefulWidget> createState() {
    return new _HomeState();
  }
}

// ========================= HOME STATE

class _HomeState extends State<MyHomePage> {
  var feeder;
  Map<String, List<Widget>> elemsByUrl = {};

  @override
  void initState() {
    super.initState();

    feeder = new Feeder();

    tagsByUrls.keys.forEach((u) => elemsByUrl.putIfAbsent(u, () => []));
    tagsByUrls.keys.forEach(
        (url) => feeder.getFeed(url).then((feed) => _fillList(feed, url)));
  }

  @override
  Widget build(BuildContext context) {
    List<RefreshIndicator> tabViews =
        tagsByUrls.keys.map((u) => _getTabView(u, _getRefresher(u))).toList();

    List<Tab> tabs =
        tagsByUrls.keys.map((u) => new Tab(text: tagsByUrls[u])).toList();

    return new DefaultTabController(
        length: tagsByUrls.keys.length,
        child: new Scaffold(
            appBar: new AppBar(
              title: new Text(widget.title),
              bottom: new TabBar(tabs: tabs),
            ),
            body: new TabBarView(children: tabViews)));
  }

  Future<Null> Function() _getRefresher(String url) {
    return () async {
      feeder.getFeed(url).then((feed) => _fillList(feed, url));
      return null;
    };
  }

  RefreshIndicator _getTabView(String url, Future<Null> refresher()) {
    return new RefreshIndicator(
        child: new ListView(
          children: elemsByUrl[url],
        ),
        onRefresh: refresher);
  }

  _fillList(Feed feed, String url) {
    List<Widget> widgets = [];

    feed.items.forEach(
        (feedItem) async => widgets.add(await _getFeedItemView(feedItem)));

    setState(() {
      elemsByUrl[url] = widgets;
    });
  }

  Future<Card> _getFeedItemView(FeedItem feedItem) async {
    return new Card(
        child: new InkWell(
            onTap: () async => await launch(feedItem.link),
            child: new Container(
                padding: EdgeInsets.all(8.0),
                child: new Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [new Text("${feedItem.title}")]))));
  }
}

// ========================= FEEDER

class Feeder {
  Future getFeed(String url) async {
    print("fetching $url ... ");
    var response = await get(url);
    print("fetched with code: ${response.statusCode}");
    return parse(response.body);
  }
}
