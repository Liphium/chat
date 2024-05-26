import 'dart:convert';

import 'package:chat_interface/connection/encryption/asymmetric_sodium.dart';
import 'package:chat_interface/controller/account/friends/friend_controller.dart';
import 'package:chat_interface/controller/current/status_controller.dart';
import 'package:chat_interface/database/database.dart';
import 'package:chat_interface/pages/status/setup/account/key_setup.dart';
import 'package:chat_interface/standards/unicode_string.dart';
import 'package:chat_interface/util/web.dart';
import 'package:drift/drift.dart';
import 'package:get/get.dart';

class UnknownController extends GetxController {
  final cache = <String, UnknownAccount>{};

  Future<UnknownAccount?> loadUnknownProfile(String id) async {
    if (id == StatusController.ownAccountId) {
      return UnknownAccount(id, "", UTFString(""), signatureKeyPair.publicKey, asymmetricKeyPair.publicKey);
    }

    final controller = Get.find<FriendController>();
    if (controller.friends[id] != null) {
      return UnknownAccount.fromFriend(controller.friends[id]!);
    }

    if (cache[id] != null) {
      if (cache[id]!.lastFetch != null && DateTime.now().difference(cache[id]!.lastFetch!) < const Duration(minutes: 5)) {
        return cache[id];
      }
    }

    final json = await postAuthorizedJSON("/account/get", {
      "id": id,
    });

    if (!json["success"]) {
      return null;
    }

    final profile = UnknownAccount(
      id,
      json["name"],
      UTFString.untransform(json["display_name"]),
      unpackagePublicKey(json["sg"]),
      unpackagePublicKey(json["pub"]),
    );

    db.unknownProfile.insertOnConflictUpdate(profile.toData());
    cache[id] = profile;
    return profile;
  }
}

class UnknownAccount {
  final String id;
  final String? name;
  final UTFString? displayName;

  final Uint8List signatureKey;
  final Uint8List publicKey;
  DateTime? lastFetch;

  UnknownAccount(this.id, this.name, this.displayName, this.signatureKey, this.publicKey);

  factory UnknownAccount.fromData(UnknownProfileData data) {
    final keys = jsonDecode(data.keys);
    return UnknownAccount(
      data.id,
      data.name == "" ? null : data.name,
      data.displayName == "" ? null : UTFString.untransform(data.displayName),
      unpackagePublicKey(keys["sg"]),
      unpackagePublicKey(keys["pub"]),
    );
  }

  factory UnknownAccount.fromFriend(Friend friend) {
    return UnknownAccount(
      friend.id,
      friend.name,
      friend.displayName.value,
      friend.keyStorage.signatureKey,
      friend.keyStorage.publicKey,
    );
  }

  UnknownProfileData toData() => UnknownProfileData(
        id: id,
        name: name ?? "",
        displayName: displayName?.transform() ?? "",
        keys: jsonEncode({
          "sg": packagePublicKey(signatureKey),
          "pub": packagePublicKey(publicKey),
        }),
      );
}
