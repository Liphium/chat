import 'package:chat_interface/connection/chat/stored_actions_listener.dart';
import 'package:chat_interface/controller/current/connection_controller.dart';
import 'package:chat_interface/util/web.dart';

late String storedActionKey;

class StoredActionsSetup extends ConnectionStep {
  StoredActionsSetup() : super('loading.stored_actions');

  @override
  Future<SetupResponse> load() async {
    // Get account from database
    final body = await postAuthorizedJSON("/account/stored_actions/list", <String, dynamic>{});
    if (!body["success"]) {
      return SetupResponse(error: "server.error");
    }

    final actions = body["actions"] as List<dynamic>;
    if (actions.isEmpty) {
      return SetupResponse();
    }

    for (var element in actions) {
      await processStoredAction(element);
    }

    return SetupResponse();
  }
}
