import 'dart:io';

import 'package:chat_interface/theme/components/fj_button.dart';
import 'package:chat_interface/theme/components/fj_textfield.dart';
import 'package:chat_interface/theme/components/transitions/transition_container.dart';
import 'package:chat_interface/util/logging_framework.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../../../database/database.dart';
import '../../../../main.dart';
import '../../../../util/vertical_spacing.dart';
import '../setup_manager.dart';

class InstanceSetup extends Setup {
  InstanceSetup() : super('loading.instance', true);

  @override
  Future<Widget?> load() async {
    // Get list of instances
    sendLog((await getApplicationSupportDirectory()).path);
    final instanceFolder = path.join((await getApplicationSupportDirectory()).path, "instances");
    final dir = Directory(instanceFolder);

    await dir.create();
    final instances = await dir.list().toList();

    if (instances.isEmpty || !isDebug) {
      await setupInstance("default");
      return null;
    }

    // Open instance selection page
    return InstanceSelectionPage(instances: instances);
  }
}

Future<bool> setupInstance(String name, {bool next = false}) async {
  // Initialize database
  if (databaseInitialized) {
    await db.close();
  }
  final dbFolder = path.join((await getApplicationSupportDirectory()).path, "instances");
  final file = File(path.join(dbFolder, '$name.db'));
  db = Database(NativeDatabase.createInBackground(file, logStatements: driftLogger));

  sendLog("going on");

  // Create tables
  var _ = await (db.select(db.setting)).get();

  if (next) {
    setupManager.next(open: true);
  }

  return true;
}

class InstanceSelectionPage extends StatefulWidget {
  final List<FileSystemEntity> instances;

  const InstanceSelectionPage({super.key, required this.instances});

  @override
  State<InstanceSelectionPage> createState() => _InstanceSelectionPageState();
}

class _InstanceSelectionPageState extends State<InstanceSelectionPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Get.theme.colorScheme.background,
      body: Center(
        child: TransitionContainer(
          tag: "login",
          borderRadius: BorderRadius.circular(modelBorderRadius),
          width: 370,
          child: Padding(
            padding: const EdgeInsets.all(modelPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'setup.choose.instance'.tr,
                  style: Get.textTheme.headlineMedium,
                ),
                verticalSpacing(sectionSpacing),
                Text("If you don't know what this is, just click on default and you'll be fine.", style: Get.textTheme.bodyMedium),
                verticalSpacing(sectionSpacing),
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.instances.length,
                  itemBuilder: (context, index) {
                    var instance = widget.instances[index];
                    final base = path.basename(path.withoutExtension(instance.path));

                    return Padding(
                      padding: EdgeInsets.only(top: index == 0 ? 0 : defaultSpacing),
                      child: Material(
                        borderRadius: BorderRadius.circular(defaultSpacing),
                        color: Get.theme.colorScheme.primary,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(defaultSpacing),
                          onTap: () => setupInstance(path.basename(path.withoutExtension(instance.path)), next: true),
                          child: Padding(
                            padding: const EdgeInsets.all(elementSpacing),
                            child: Row(
                              children: [
                                horizontalSpacing(elementSpacing),
                                Text(base, style: Get.textTheme.labelLarge),
                                const Spacer(),
                                IconButton(
                                  onPressed: () async {
                                    await File(instance.path).delete();
                                    setupManager.restart();
                                  },
                                  icon: const Icon(Icons.delete),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                verticalSpacing(sectionSpacing),
                FJTextField(
                  controller: _controller,
                  hintText: 'setup.instance.name'.tr,
                ),
                verticalSpacing(defaultSpacing),
                FJElevatedButton(
                  onTap: () => setupInstance(_controller.text, next: true),
                  child: Center(child: Text("create".tr, style: Get.textTheme.labelLarge)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
