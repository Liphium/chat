import 'package:chat_interface/connection/connection.dart';
import 'package:chat_interface/main.dart';
import 'package:chat_interface/pages/status/error/error_page.dart';
import 'package:chat_interface/pages/status/setup/setup_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../util/web.dart';
import 'cluster_setup.dart';

class ConnectionSetup extends Setup {
  ConnectionSetup() : super('loading.connection', false);

  @override
  Future<Widget?> load() async {
    final body = await postAuthorizedJSON("/node/connect", <String, dynamic>{
      "cluster": connectedCluster.id,
      "tag": appTag,
      "token": refreshToken,
    });

    if (!body["success"]) {
      return ErrorPage(title: body["error"]);
    }

    nodeId = body["id"];
    nodeDomain = body["domain"];

    // Start connection
    final res = await startConnection(body["domain"], body["token"]);
    if (!res) {
      return const ErrorPage(title: "node.error");
    }

    await Future.delayed(500.ms);

    return null;
  }
}
