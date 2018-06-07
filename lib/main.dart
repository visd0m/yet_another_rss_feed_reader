import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:feedparser/feedparser.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

Uuid uuid = new Uuid();

void main() => runApp(new MyApp());

// ========================= APP

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
        theme: new ThemeData(
          primarySwatch: Colors.blueGrey,
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

  Map<String, dynamic> _tagsByUrls = {};

  @override
  void initState() {
    super.initState();

    _loadSubscriptions().then((value) {
      _tagsByUrls = value;

      _currentUrl = _tagsByUrls.keys.first;
      print("default main view url: $_currentUrl");

      _reloadFeedItems().then((_) => null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      drawer: new Drawer(
        child: new ListView(
          padding: EdgeInsets.zero,
          children: _getDrawerEntries(context),
        ),
      ),
      appBar: new AppBar(
          title: new Text(_currentUrl != null ? _tagsByUrls[_currentUrl] : "")),
      body: new Builder(builder: (BuildContext context) {
        return new RefreshIndicator(
          child: getFeedListView(),
          onRefresh: () async {
            await _safeReloadItems(context);
          },
        );
      }),
      floatingActionButton: new Builder(builder: (BuildContext context) {
        return new FloatingActionButton(
            child: new Icon(Icons.rss_feed),
            onPressed: () async => await _getAddSubscriptionDialog(context));
      }),
    );
  }

  Future _safeReloadItems(BuildContext context) async {
    try {
      await _reloadFeedItems();
    } catch (e) {
      print("error loading feed: $e");
      Scaffold.of(context).showSnackBar(
          new SnackBar(content: new Text("error loading feed: $e")));
    }
  }

  List<Widget> _getDrawerEntries(BuildContext context) {
    List<Widget> drawerEntries = [
      new DrawerHeader(
        child: new Text(
          'Subscriptions',
          style: new TextStyle(fontSize: 18.0, color: Colors.white),
        ),
        decoration: new BoxDecoration(
          color: Colors.blueGrey,
        ),
      ),
    ];
    _tagsByUrls.keys?.forEach((u) => drawerEntries.add(
          new ListTile(
            title: new Text(_tagsByUrls[u]),
            onTap: () async {
              Navigator.pop(context);
              await _selectSubscription(u);
            },
            onLongPress: () async =>
                await _getRemoveSubscriptionDialog(context, u),
          ),
        ));
    return drawerEntries;
  }

  Future _selectSubscription(String u) async {
    _currentUrl = u;
    await _reloadFeedItems();
  }

  Future<Null> _reloadFeedItems() async {
    if (_currentUrl == null) return null;

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

  // ========================= FEEDS

  Future _getFeed(String url) async {
    print("fetching $url ... ");
    var response = await get(url);
    print("fetched with code: ${response.statusCode}");
    return parse(response.body);
  }

  // ========================= SAVE/LOAD SUBSCRIPTIONS

  _saveSubscription(Map<String, dynamic> subscriptions) async {
    print("saving subscriptions: $subscriptions");

    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;

    File file = new File("$appDocPath/subscriptions.txt");
    file.writeAsString(json.encode(subscriptions));
  }

  Future<Map<String, dynamic>> _loadSubscriptions() async {
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
      _saveSubscription(subscriptions);
    }

    print("loaded subscriptions: $subscriptions");
    return subscriptions;
  }

  void _addSubscription(_url, _tag, Future onSuccess(String url)) {
    if (_url != null && _tag != null) {
      _getFeed(_url)
          .then((feed) => setState(() {
                _tagsByUrls[_url] = _tag;
              }))
          .then((_) => _saveSubscription(_tagsByUrls))
          .then((_) => onSuccess(_url))
          .catchError((error) {
        print("error fetching: $_url, abort saving subscription");
        Scaffold.of(context).showSnackBar(
            new SnackBar(content: new Text("error loading feed: $error")));
      });
    }
  }

  _deleteSubscription(String u) async {
    setState(() {
      _currentUrl = null;
      _feedItemViews.clear();
      _tagsByUrls.remove(u);
    });
    await _saveSubscription(_tagsByUrls);
  }

  // ========================= DIALOGS

  _getAddSubscriptionDialog(BuildContext context) async {
    var _tag;
    var _url;

    await showDialog(
        context: context,
        builder: (BuildContext context) {
          return new AlertDialog(
            title: new Text("Add subscription"),
            content: new Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  new TextField(
                    onChanged: (text) => _url = text,
                    autofocus: true,
                    decoration: new InputDecoration(
                      labelText: 'Url',
                      hintText: 'eg. https://hnrss.org/frontpage',
                    ),
                  ),
                  new TextField(
                    onChanged: (text) => _tag = text,
                    autofocus: true,
                    decoration: new InputDecoration(
                      labelText: 'Tag',
                      hintText: 'eg. HN',
                    ),
                  ),
                ]),
            actions: <Widget>[
              new FlatButton(
                  onPressed: () => Navigator.pop(context),
                  child: new Text("CANCEL")),
              new FlatButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    _addSubscription(_url, _tag, _selectSubscription);
                  },
                  child: new Text("ADD"))
            ],
          );
        });
  }

  _getRemoveSubscriptionDialog(BuildContext context, String url) async {
    await showDialog(
        context: context,
        builder: (BuildContext context) {
          return new AlertDialog(
            content: new Text("Delete subscription: ${_tagsByUrls[url]}?"),
            actions: <Widget>[
              new FlatButton(
                onPressed: () => Navigator.pop(context),
                child: new Text("JUST JOKING"),
              ),
              new FlatButton(
                onPressed: () async {
                  await _deleteSubscription(url);
                  Navigator.pop(context);
                },
                child: new Text("DO IT"),
              )
            ],
          );
        });
  }
}
