import 'package:flutter/material.dart';

/// Shared key for the Brahma (graph) page's [Scaffold], so the bottom-nav
/// handler in `HomePage` can call `openDrawer()` when the user taps the
/// Brahma icon a second time. The key is reset each time the page mounts to
/// match a fresh [Scaffold] state.
final brahmaScaffoldKey = GlobalKey<ScaffoldState>();
