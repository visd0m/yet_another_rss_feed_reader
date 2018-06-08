import 'dart:async';

import 'package:feedparser/feedparser.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yet_another_rss_feed_reader/feeder.dart';
import 'package:yet_another_rss_feed_reader/subscriper.dart';

void main() => runApp(new MyApp());

// ========================= APP

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
        theme: new ThemeData(
          primarySwatch: Colors.indigo,
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
  String _currentUrl;
  List<Widget> _feedItemViews = [];
  Map<String, dynamic> _tagsByUrls = {};

  Subscriber subscriptionService = new Subscriber();
  Feeder feeder = new Feeder();

  @override
  void initState() {
    super.initState();

    subscriptionService.loadSubscriptions().then((value) {
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
            title: new Text(_currentUrl != null
                ? _tagsByUrls[_currentUrl]
                : "No feed selected")),
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
            onPressed: () async => await _getAddSubscriptionDialog(context),
          );
        }));
  }

  // ========================= DRAWER

  List<Widget> _getDrawerEntries(BuildContext context) {
    List<Widget> drawerEntries = [
      new DrawerHeader(
        padding: new EdgeInsets.only(bottom: 16.0, left: 16.0),
        curve: Curves.elasticIn,
        child: new Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            new Text(
              'Subscriptions',
              style: new TextStyle(fontSize: 18.0, color: Colors.white),
            ),
          ],
        ),
        decoration: new BoxDecoration(
          color: Colors.indigo,
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

  // ========================= FEEDS

  Future _selectSubscription(String u) async {
    _currentUrl = u;
    await _reloadFeedItems();
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

  Future<Null> _reloadFeedItems() async {
    if (_currentUrl == null) return null;

    setState(() {
      _feedItemViews.clear();
    });

    Feed feed = await feeder.getFeed(_currentUrl);

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

  // ========================= SUBSCRIPTIONS

  void _addSubscription(
      _url, _tag, Future onSuccess(String url), BuildContext context) {
    if (_url != null && _tag != null) {
      feeder
          .getFeed(_url)
          .then((feed) => setState(() {
                _tagsByUrls[_url] = _tag;
              }))
          .then((_) => subscriptionService.saveSubscriptions(_tagsByUrls))
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
      if (u == _currentUrl) {
        _currentUrl = null;
        _feedItemViews.clear();
      }
      _tagsByUrls.remove(u);
    });
    await subscriptionService.saveSubscriptions(_tagsByUrls);
  }

  // ========================= DIALOGS

  _getAddSubscriptionDialog(BuildContext scaffoldContext) async {
    var _tag;
    var _url;

    await showDialog(
        context: scaffoldContext,
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
                    _addSubscription(
                        _url, _tag, _selectSubscription, scaffoldContext);
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
