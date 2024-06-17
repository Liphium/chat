import 'package:chat_interface/connection/connection.dart';
import 'package:chat_interface/controller/account/friends/friend_controller.dart';
import 'package:chat_interface/controller/conversation/townsquare_controller.dart';
import 'package:chat_interface/database/database.dart';
import 'package:chat_interface/pages/status/setup/app/policy_setup.dart';
import 'package:chat_interface/src/rust/api/interaction.dart' as api;
import 'package:chat_interface/main.dart';
import 'package:chat_interface/pages/chat/chat_page_desktop.dart';
import 'package:chat_interface/pages/status/setup/account/friends_setup.dart';
import 'package:chat_interface/pages/status/setup/account/stored_actions_setup.dart';
import 'package:chat_interface/pages/status/setup/app/instance_setup.dart';
import 'package:chat_interface/pages/status/setup/app/settings_setup.dart';
import 'package:chat_interface/pages/status/setup/connection/cluster_setup.dart';
import 'package:chat_interface/pages/status/setup/connection/connection_setup.dart';
import 'package:chat_interface/pages/status/setup/account/profile_setup.dart';
import 'package:chat_interface/pages/status/setup/app/server_setup.dart';
import 'package:chat_interface/pages/status/setup/app/updates_setup.dart';
import 'package:chat_interface/pages/status/starting_page.dart';
import 'package:chat_interface/theme/components/transitions/transition_controller.dart';
import 'package:chat_interface/util/logging_framework.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../error/error_page.dart';
import 'account/account_setup.dart';
import 'account/vault_setup.dart';
import 'account/key_setup.dart';

abstract class Setup {
  final String name;
  final bool once;
  bool executed = false;

  Setup(this.name, this.once);

  Future<Widget?> load();
}

SetupManager setupManager = SetupManager();

class SetupManager {
  static bool setupFinished = false;
  final _steps = <Setup>[];
  int current = -1;
  final message = 'setup.loading'.obs;

  SetupManager() {
    // Initialize setups

    // Setup app
    _steps.add(PolicySetup());
    if (GetPlatform.isMobile || GetPlatform.isMacOS) {
      _steps.add(UpdateSetup());
    }
    _steps.add(InstanceSetup());
    _steps.add(ServerSetup());

    // Setup account
    _steps.add(ProfileSetup());
    _steps.add(AccountSetup());

    // Setup encryption
    _steps.add(KeySetup());

    // Fetch data
    _steps.add(SettingsSetup());
    _steps.add(FriendsSetup());

    // Setup connection
    _steps.add(ClusterSetup());
    _steps.add(ConnectionSetup());

    // Setup conversations
    _steps.add(VaultSetup());

    // Handle new stored actions
    _steps.add(StoredActionsSetup());
  }

  void restart() {
    current = -1;
    if (!configDisableRust) {
      api.stop();
    }
    Get.find<FriendController>().onReload();
    Get.find<TransitionController>().modelTransition(const StartingPage());
    db.close();
  }

  void next({bool open = true}) async {
    if (_steps.isEmpty) return;
    setupFinished = false;

    if (open) {
      Get.find<TransitionController>().modelTransition(const StartingPage());
    }

    current++;
    if (current < _steps.length) {
      final setup = _steps[current];
      if (setup.executed && setup.once) {
        next(open: false);
        return;
      }

      message.value = setup.name;
      sendLog("Setup: ${setup.name}");

      Widget? ready;
      if (isDebug) {
        ready = await setup.load();
      } else {
        try {
          ready = await setup.load();
        } catch (e) {
          error(e.toString());
          return;
        }
      }

      if (ready != null) {
        Get.find<TransitionController>().modelTransition(ready);
        return;
      }

      setup.executed = true;
      next(open: false);
    } else {
      // Finish the setup and go to the chat page
      setupFinished = true;
      connector.runAfterSetupQueue();
      Get.find<TownsquareController>().updateEnabledState();
      Get.offAll(getChatPage(), transition: Transition.fade, duration: const Duration(milliseconds: 500));
    }
  }

  void error(String error) {
    Get.find<TransitionController>().modelTransition(ErrorPage(title: error));
  }
}
