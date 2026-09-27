import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start Firebase before the first frame so the rest of the app can assume
  // an initialised SDK. Failures are handled by [BootstrapGate] instead of
  // crashing, so the user always sees an explanation.
  final FirebaseStartupResult startup = await FirebaseBootstrap.start();

  runApp(ThaiOtopApp(startup: startup));
}
