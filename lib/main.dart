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
        title: 'Yet another rss feed reader',
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
  List<Widget> _feedItemViews = [];
  String _currentUrl;

  Map<String, String> _tagsByUrls;

  @override
  void initState() {
    super.initState();

    _tagsByUrls = _loadSubscriptions();

    _currentUrl = _tagsByUrls.keys.first;
    print("default main view url: $_currentUrl");

    _reloadFeedItems().then((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> drawerEntries = [
      new DrawerHeader(
        child: new Text('Feeds', style: new TextStyle(color: Colors.white)),
        decoration: new BoxDecoration(
          color: Colors.blue,
        ),
      )
    ];
    _tagsByUrls.keys.forEach((u) => drawerEntries.add(
          new ListTile(
            title: new Text(_tagsByUrls[u]),
            onTap: () async {
              _currentUrl = u;
//              _currentTitle = _tagsByUrls[u];
              Navigator.pop(context);
              await _reloadFeedItems();
            },
          ),
        ));

    return new Scaffold(
      drawer: new Drawer(
        child: new ListView(
          padding: EdgeInsets.zero,
          children: drawerEntries,
        ),
      ),
      appBar: new AppBar(title: new Text(widget.title)),
      body: new RefreshIndicator(
        child: getFeedListView(),
        onRefresh: _reloadFeedItems,
      ),
      floatingActionButton: new FloatingActionButton(
        child: new Icon(Icons.rss_feed),
        onPressed: () => {},
      ),
    );
  }

  Future<Null> _reloadFeedItems() async {
    setState(() {
      _feedItemViews.clear();
    });

    Feed feed = await _getFeed(_currentUrl);

    setState(() {
      feed.items.forEach((item) => _feedItemViews.add(_getFeedItemView(item)));
      print("updated #${_feedItemViews.length} items");
    });

    return null;
  }

  Widget getFeedListView() {
    print("building main view with #${_feedItemViews.length}");

    return new ListView.builder(
      itemCount: _feedItemViews.length,
      itemBuilder: (BuildContext context, int position) =>
          _feedItemViews[position],
    );
  }

  Widget _getFeedItemView(FeedItem feedItem) {
    return new ListTile(
      title: new Text(feedItem.title),
      subtitle: new Text(feedItem.pubDate),
      onTap: () => launch(feedItem.link),
    );
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
