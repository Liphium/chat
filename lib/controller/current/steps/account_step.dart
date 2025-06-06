import 'package:chat_interface/connection/encryption/symmetric_sodium.dart';
import 'package:chat_interface/controller/account/friends/friend_controller.dart';
import 'package:chat_interface/controller/current/connection_controller.dart';
import 'package:chat_interface/controller/current/status_controller.dart';
import 'package:chat_interface/controller/current/steps/key_step.dart';
import 'package:chat_interface/controller/current/steps/stored_actions_step.dart';
import 'package:chat_interface/pages/status/setup/instance_setup.dart';
import 'package:chat_interface/standards/server_stored_information.dart';
import 'package:chat_interface/util/logging_framework.dart';
import 'package:chat_interface/util/web.dart';
import 'package:get/get.dart';
import 'package:sodium_libs/sodium_libs.dart';

late SecureKey vaultKey;
late SecureKey profileKey;

class AccountStep extends ConnectionStep {
  AccountStep() : super('loading.account');

  @override
  Future<SetupResponse> load() async {
    // Get account from database
    final body = await postAuthorizedJSON("/account/me", <String, dynamic>{});
    final account = body["account"];

    if (!body["success"]) {
      return SetupResponse(error: body["error"]);
    }

    // Set all account data
    StatusController controller = Get.find();
    final uNameChanged = controller.name.value != account["username"];
    final dNameChanged = controller.displayName.value != account["display_name"];

    // Set the account id if there isn't one
    if (StatusController.ownAccountId == "" || uNameChanged || dNameChanged || StatusController.ownAccountId != account["id"]) {
      sendLog("setting account id");
      await setEncryptedValue("cache_account_id", account["id"]);
      await setEncryptedValue("cache_account_uname", account["username"]);
      await setEncryptedValue("cache_account_dname", account["display_name"]);

      // Restart to migrate to the new account id
      return SetupResponse(
        restart: true,
      );
    }

    // Set all permissions
    StatusController.permissions = List<String>.from(body["permissions"]);
    for (var rankJson in body["ranks"]) {
      StatusController.ranks.add(RankData.fromJson(rankJson));
    }

    // Decrypt the profile and vault key
    final vaultInfo = ServerStoredInfo.untransform(body["vault"]);
    final profileInfo = ServerStoredInfo.untransform(body["profile"]);
    if (profileInfo.error || vaultInfo.error) {
      return SetupResponse(error: "keys.invalid");
    }
    profileKey = unpackageSymmetricKey(profileInfo.text);
    vaultKey = unpackageSymmetricKey(vaultInfo.text);
    storedActionKey = body["actions"];

    // Set own key pair as cached (in the friend that represents this account)
    Get.find<FriendController>().friends[StatusController.ownAddress]!.keyStorage =
        KeyStorage(asymmetricKeyPair.publicKey, signatureKeyPair.publicKey, profileKey, "");

    return SetupResponse();
  }
}
