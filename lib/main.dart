import 'dart:async';

import 'package:feedparser/feedparser.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:url_launcher/url_launcher.dart';

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
        home: new MyHomePage(title: 'Yet another rss feed reader'));
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
  Map<String, List<Widget>> elemsByUrl = {};
  Map<String, String> tagsByUrls;

  @override
  void initState() {
    super.initState();

    tagsByUrls = _loadSubscriptions();

    tagsByUrls.keys.forEach((u) => elemsByUrl.putIfAbsent(u, () => []));
    tagsByUrls.keys
        .forEach((url) => _getFeed(url).then((feed) => _fillList(feed, url)));
  }

  @override
  Widget build(BuildContext context) {
    return new DefaultTabController(
        length: tagsByUrls.keys.length,
        child: new Scaffold(
            appBar: new AppBar(
              title: new Text(widget.title),
              bottom: new TabBar(
                  tabs: tagsByUrls.keys
                      .map((u) => new Tab(text: tagsByUrls[u]))
                      .toList()),
            ),
            body: new Builder(builder: (BuildContext context) {
              return new TabBarView(
                  children: tagsByUrls.keys
                      .map((u) => _getTabView(u, _getRefresher(u, context)))
                      .toList());
            })));
  }

  Future<Null> Function() _getRefresher(String url, BuildContext context) {
    return () async {
      _getFeed(url).then((feed) => _fillList(feed, url), onError: (error) {
        Scaffold.of(context).showSnackBar(new SnackBar(
            content: new Text("error fetching feed $url, error: $error")));
      });
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

  Future<Widget> _getFeedItemView(FeedItem feedItem) async {
    return new ListTile(
        title: new Text(feedItem.title),
        subtitle: new Text(feedItem.pubDate),
        onTap: () async => await launch(feedItem.link));
  }

  Map<String, String> _loadSubscriptions() {
    return {
      "https://hnrss.org/frontpage": "HN",
      "http://www.ansa.it/sito/ansait_rss.xml": "ANSA",
      "https://feedpress.me/saggiamente": "SAGGIAMENTE",
      "https://www.everyeye.it/feed_news_rss.asp": "EVERYEYE"
    };
  }

  Future _getFeed(String url) async {
    print("fetching $url ... ");
    var response = await get(url);
    print("fetched with code: ${response.statusCode}");
    return parse(response.body);
  }
}
