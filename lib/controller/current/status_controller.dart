import 'dart:async';
import 'dart:convert';

import 'package:chat_interface/connection/connection.dart';
import 'package:chat_interface/connection/encryption/hash.dart';
import 'package:chat_interface/connection/encryption/symmetric_sodium.dart';
import 'package:chat_interface/connection/messaging.dart';
import 'package:chat_interface/controller/account/friend_controller.dart';
import 'package:chat_interface/controller/conversation/attachment_controller.dart';
import 'package:chat_interface/controller/conversation/conversation_controller.dart';
import 'package:chat_interface/controller/conversation/townsquare_controller.dart';
import 'package:chat_interface/database/database.dart';
import 'package:chat_interface/pages/status/setup/account/stored_actions_setup.dart';
import 'package:chat_interface/pages/status/setup/encryption/key_setup.dart';
import 'package:chat_interface/pages/status/setup/setup_manager.dart';
import 'package:drift/drift.dart';
import 'package:get/get.dart';

class StatusController extends GetxController {
  static String ownAccountId = "";
  static List<String> permissions = [];

  Timer? _timer;
  StatusController() {
    if (_timer != null) _timer!.cancel();

    // Update status every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (connector.isConnected()) {
        setStatus();
      }
    });
  }

  final name = 'test'.obs;
  final id = '0'.obs;

  // Status message
  final statusLoading = true.obs;
  final status = '-'.obs; // "-" = status disabled
  final type = 1.obs;

  // Shared content by friends
  final sharedContent = RxMap<String, ShareContainer>();

  // Current shared content (by this account)
  final ownContainer = Rx<ShareContainer?>(null);

  void setName(String value) => name.value = value;
  void setId(String value) {
    id.value = value;
    StatusController.ownAccountId = value;
  }

  String statusJson() => jsonEncode(<String, dynamic>{
        "s": status.value,
        "t": type.value,
      });

  String newStatusJson(String status, int type) => jsonEncode(<String, dynamic>{
        "s": status,
        "t": type,
      });

  void fromStatusJson(String json) {
    final data = jsonDecode(json);
    try {
      status.value = utf8.decode(base64Decode(data["s"]));
    } catch (e) {
      status.value = "-";
    }
    type.value = data["t"];
  }

  String generateFriendId() {
    return hashSha(id.value + name.value + storedActionKey);
  }

  String statusPacket(String statusJson) {
    return "${generateFriendId()}:${encryptSymmetric(statusJson, profileKey)}";
  }

  String sharedContentPacket() {
    if (ownContainer.value == null) {
      return "";
    }
    return encryptSymmetric(ownContainer.value!.toJson(), profileKey);
  }

  Future<bool> share(ShareContainer container) async {
    if (ownContainer.value != null) return false;
    ownContainer.value = container;
    await setStatus();
    return true;
  }

  void stopSharing() {
    if (ownContainer.value == null) {
      return;
    }
    ownContainer.value = null;
    setStatus();
  }

  Future<bool> setStatus({String? message, int? type, Function()? success}) async {
    if (statusLoading.value) return false;
    statusLoading.value = true;
    if (message != null) {
      message = base64Encode(utf8.encode(message));
    }

    final tokens = <Map<String, dynamic>>[];
    for (var conversation in Get.find<ConversationController>().conversations.values) {
      if (conversation.members.length == 2) {
        tokens.add(conversation.token.toMap());
      }
    }

    connector.sendAction(
        Message("st_send", <String, dynamic>{
          "status": statusPacket(newStatusJson(message ?? status.value, type ?? this.type.value)),
          "tokens": tokens,
          "data": sharedContentPacket(),
        }), handler: (event) {
      statusLoading.value = false;
      success?.call();
      if (event.data["success"] == true) {
        if (message != null) status.value = utf8.decode(base64Decode(message));
        if (type != null) this.type.value = type;
        Get.find<TownsquareController>().updateEnabledState();
      }
    });

    return true;
  }

  // Log out of this account
  void logOut({deleteEverything = false, deleteFiles = false}) async {
    // Delete the session information
    db.setting.deleteWhere((tbl) => tbl.key.equals("profile"));

    // Delete all data
    if (deleteEverything) {
      for (var table in db.allTables) {
        await table.deleteAll();
      }
    }

    // Delete all files
    if (deleteFiles) {
      await Get.find<AttachmentController>().deleteAllFiles();
    }

    // Go back to login
    setupManager.restart();
  }
}

String friendId(Friend friend) {
  return hashSha(friend.id + friend.name + friend.tag + friend.keyStorage.storedActionKey);
}

enum ShareType { space }

abstract class ShareContainer {
  final Friend? sender;
  final ShareType type;

  ShareContainer(this.sender, this.type);

  Map<String, dynamic> toMap();

  String toJson() {
    final map = toMap();
    map["type"] = type.index;
    return jsonEncode(map);
  }

  void onDrop() {}
}
