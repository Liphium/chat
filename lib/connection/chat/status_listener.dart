import 'dart:convert';

import 'package:chat_interface/connection/connection.dart';
import 'package:chat_interface/connection/encryption/symmetric_sodium.dart';
import 'package:chat_interface/connection/messaging.dart';
import 'package:chat_interface/controller/account/friends/friend_controller.dart';
import 'package:chat_interface/controller/conversation/conversation_controller.dart';
import 'package:chat_interface/controller/conversation/member_controller.dart';
import 'package:chat_interface/controller/spaces/space_container.dart';
import 'package:chat_interface/controller/current/status_controller.dart';
import 'package:chat_interface/controller/current/steps/account_step.dart';
import 'package:chat_interface/util/logging_framework.dart';
import 'package:chat_interface/util/web.dart';
import 'package:get/get.dart';
import 'package:sodium_libs/sodium_libs.dart';

void setupStatusListener() {
  // Handle friend status change
  connector.listen("acc_st", (event) async {
    final friend = handleStatus(event, false);
    if (friend == null) return;
    if (!friend.answerStatus) return;
    friend.answerStatus = false;

    // Send back status
    final controller = Get.find<StatusController>();

    // Get dm with friend
    final dm = Get.find<ConversationController>().conversations.values.firstWhere(
          (element) => element.members.length == 2 && element.members.values.any((element) => element.address == friend.id),
        );

    sendLog("sending status answer");
    await postNodeJSON("/conversations/answer_status", {
      "token": dm.token.toMap(),
      "data": {
        "status": controller.statusPacket(),
        "data": controller.sharedContentPacket(),
      }
    });
  }, afterSetup: true);

  // Don't send back when it's an answer
  connector.listen("acc_st:a", (event) {
    sendLog("received status answer");
    handleStatus(event, false);
  }, afterSetup: true);

  // Receive status changes from other devices
  connector.listen("acc_st:o", (event) {
    sendLog("received status change from other device");
    handleStatus(event, true);
  }, afterSetup: true);
}

Friend? handleStatus(Event event, bool own) {
  final message = event.data["st"] as String;

  // Load own status when the packet specifies it
  final statusController = Get.find<StatusController>();
  final controller = Get.find<FriendController>();
  if (own) {
    controller.friends[StatusController.ownAddress]!.loadStatus(message);
    statusController.fromStatusJson(decryptSymmetric(message, profileKey));
    // Load own shared content
    final (container, shouldUpdate) = _dataToContainer(statusController.ownContainer.value, event.data["d"], profileKey);
    if (shouldUpdate) {
      statusController.ownContainer.value = container;
    }

    return null;
  }

  // Get all the parameters for the actual status event
  final convId = LPHAddress.from(event.data["c"] as String);
  final owner = LPHAddress.from(event.data["o"] as String);

  // Get conversation from the status packet
  final convController = Get.find<ConversationController>();
  final conversation = convController.conversations[convId];
  if (conversation == null) {
    sendLog("conversation not found for status packet $convId");
    return null;
  }

  // Get the account id of the person sending the status packet
  final member = conversation.members.values.firstWhere(
    (mem) => mem.tokenId == owner,
    orElse: () => Member(LPHAddress.error(), LPHAddress.error(), MemberRole.user),
  );
  if (member.tokenId.isError()) {
    sendLog("member $owner not found in conversation $convId (status packet)");
    return null;
  }
  final friend = controller.friends[member.address];
  if (friend == null) {
    sendLog("account ${member.address.toString()} isn't a friend (status packet)");
    return null;
  }

  // Load the status
  friend.loadStatus(message);

  // Extract shared content
  final (container, shouldUpdate) = _dataToContainer(statusController.sharedContent[friend.id], event.data["d"], friend.keyStorage.profileKey);
  if (shouldUpdate) {
    if (container == null) {
      final container = statusController.sharedContent.remove(friend.id);
      container?.onDrop();
    } else {
      statusController.sharedContent[friend.id] = container;
    }
  }

  return friend;
}

/// Turn the shared data from a status into a share container (returns container (if existent) and if it has changed)
(ShareContainer?, bool) _dataToContainer(ShareContainer? existing, String data, SecureKey profileKey) {
  if (data != "") {
    final sharedJson = decryptSymmetric(data, profileKey);
    final shared = jsonDecode(sharedJson) as Map<String, dynamic>;
    switch (ShareType.values[shared["type"] as int]) {
      // Shared space
      case ShareType.space:
        final container = SpaceConnectionContainer.fromJson(shared);
        if (existing == null || existing is! SpaceConnectionContainer) {
          return (container, true);
        } else if (existing.roomId != container.roomId) {
          return (container, true);
        } else {
          return (container, false);
        }
    }
  }

  return (null, true);
}
