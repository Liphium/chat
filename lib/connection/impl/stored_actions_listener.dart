import 'dart:convert';
import 'dart:typed_data';

import 'package:chat_interface/connection/connection.dart';
import 'package:chat_interface/connection/encryption/asymmetric_sodium.dart';
import 'package:chat_interface/connection/encryption/symmetric_sodium.dart';
import 'package:chat_interface/connection/impl/setup_listener.dart';
import 'package:chat_interface/controller/account/friend_controller.dart';
import 'package:chat_interface/controller/account/requests_controller.dart';
import 'package:chat_interface/controller/conversation/conversation_controller.dart';
import 'package:chat_interface/controller/conversation/member_controller.dart';
import 'package:chat_interface/database/conversation/conversation.dart' as model;
import 'package:chat_interface/pages/status/setup/account/vault_setup.dart';
import 'package:chat_interface/pages/status/setup/encryption/key_setup.dart';
import 'package:chat_interface/util/web.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../controller/current/status_controller.dart';
import '../../util/logging_framework.dart';

part 'stored_actions_util.dart';

void setupStoredActionListener() {
  connector.listen("s_a", (event) async {
    try {
      await processStoredAction(event.data);
    } catch (e) {
      sendLog("something weird happened: error while processing stored action payload");
      sendLog(e);
    }
  });
}

Future<bool> processStoredAction(Map<String, dynamic> action) async {
  // Decrypt stored action payload
  final payload = decryptAsymmetricAnonymous(asymmetricKeyPair.publicKey, asymmetricKeyPair.secretKey, action["payload"]);
  if (payload == "") {
    // Delete the action (invalid)
    sendLog("invalid stored action: couldn't decrypt payload (DELETED)");
    final response = await deleteStoredAction(action["id"]);
    if (!response) {
      sendLog("WARNING: couldn't delete stored action");
    }
    return true;
  }

  final json = jsonDecode(payload);
  switch (json["a"]) {
    // Handle friend requests
    case "fr_rq":
      sendLog("handling friend request");
      await _handleFriendRequestAction(action["id"], json);
      break;

    // Handle conversation opening
    case "conv":
      sendLog("handling conversation opening");
      await _handleConversationOpening(action["id"], json);
      break;
  }

  return true;
}

//* Friend requests
Future<bool> _handleFriendRequestAction(String actionId, Map<String, dynamic> json) async {
  // Delete the action (it doesn't need to be handled twice)
  final response = await deleteStoredAction(actionId);
  if (!response) {
    sendLog("WARNING: couldn't delete stored action");
  }

  // Get friend by name (only works on current server)
  final resJson = await postAuthorizedJSON("/account/stored_actions/details", {"username": json["name"]});

  if (!resJson["success"]) {
    sendLog("invalid friend request: ${json["error"]}");
    return true;
  }

  // Check "signature"
  final publicKey = unpackagePublicKey(resJson["key"]);
  final signatureKey = unpackagePublicKey(resJson["sg"]);
  final statusController = Get.find<StatusController>();
  final signedMessage = statusController.name.value;
  final result = decryptAsymmetricAuth(publicKey, asymmetricKeyPair.secretKey, json["s"]);
  if (!result.success || result.message != signedMessage) {
    sendLog("invalid friend request: invalid signature");
    return true;
  }

  // Check if the current account already sent this account a friend request (-> add friend)
  final id = resJson["account"];
  var request = Get.find<RequestController>().requestsSent.firstWhere((element) => element.id == id, orElse: () => Request.mock("hi"));
  sendLog("${request.id} | $id");

  if (request.id != "hi") {
    // This request doesn't have the right key storage yet
    request.keyStorage.publicKey = publicKey;
    request.keyStorage.profileKey = unpackageSymmetricKey(json["pf"]);
    request.keyStorage.storedActionKey = json["sa"];

    // Add friend
    final controller = Get.find<FriendController>();
    await controller.addFromRequest(request);

    return true;
  }

  // Check if the request is already in the list
  if (Get.find<RequestController>().requests.any((element) => element.id == id)) {
    sendLog("invalid friend request: already in list");
    return true;
  }

  // Check if the guy is already a friend
  if (Get.find<FriendController>().friends.values.any((element) => element.id == id)) {
    sendLog("invalid friend request: already a friend");
    return true;
  }

  // Add friend request to vault
  final profileKey = unpackageSymmetricKey(json["pf"]);
  request = Request(id, json["name"], "", actionId, KeyStorage(publicKey, signatureKey, profileKey, json["sa"]), DateTime.now().millisecondsSinceEpoch);

  final vaultId = await storeInFriendsVault(request.toStoredPayload(false));
  if (vaultId == null) {
    sendLog("couldn't store in vault: something happened");
    return true;
  }

  // Add friend request
  request.vaultId = vaultId;
  Get.find<RequestController>().addRequest(request);

  return true;
}

//* Conversation opening
Future<bool> _handleConversationOpening(String actionId, Map<String, dynamic> actionJson) async {
  // Delete the action (it doesn't need to be handled twice)
  final response = await deleteStoredAction(actionId);
  if (!response) {
    sendLog("WARNING: couldn't delete stored action");
  }

  sendLog("opening conversation with ${actionJson["s"]}");
  final friend = Get.find<FriendController>().friends[actionJson["s"]];
  if (friend == null) {
    sendLog("invalid conversation opening: friend doesn't exist");
    return true;
  }

  final token = jsonDecode(actionJson["token"]);
  final json = await postNodeJSON("/conversations/activate", <String, dynamic>{"id": token["id"], "token": token["token"]});
  if (!json["success"]) {
    sendLog("couldn't activate conversation: ${json["error"]}");
    // TODO: Could also mean it has been activated on another device
    Future.delayed(500.ms, () async {
      await refreshVault();
    });
    return true;
  }
  token["token"] = json["token"]; // Set new token (from activation request)

  final key = unpackageSymmetricKey(actionJson["key"]);
  final members = <Member>[];
  for (var memberData in json["members"]) {
    sendLog(memberData);
    final memberContainer = MemberContainer.decrypt(memberData["data"], key);
    members.add(Member(memberData["id"], memberContainer.id, MemberRole.fromValue(memberData["rank"])));
  }

  final container = ConversationContainer.decrypt(json["data"], key);
  final convToken = ConversationToken.fromJson(token);
  await Get.find<ConversationController>().addCreated(
    Conversation(
      actionJson["id"],
      "",
      model.ConversationType.values[json["type"]],
      convToken,
      container,
      key,
      DateTime.now().millisecondsSinceEpoch,
    ),
    members,
  );
  final statusController = Get.find<StatusController>();
  subscribeToConversation(statusController.statusJson(), statusController.generateFriendId(), convToken, deletions: false);

  return true;
}
