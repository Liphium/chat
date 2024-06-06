import 'package:chat_interface/pages/settings/components/list_selection.dart';
import 'package:chat_interface/pages/settings/data/entities.dart';
import 'package:chat_interface/pages/settings/data/settings_manager.dart';
import 'package:chat_interface/pages/settings/settings_page_base.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LanguageSettings {
  static const String language = "language";
  static final languages = [
    LanguageSelection("Device", Icons.computer, Get.deviceLocale ?? const Locale("en", "US")),
    const LanguageSelection("English", Icons.language, Locale("en", "US")),
    //const LanguageSelection("Deutsch", Icons.language, Locale("de", "DE")), FUTURE STUFF
  ];
}

class LanguageSelection extends SelectableItem {
  final Locale locale;
  const LanguageSelection(super.label, super.icon, this.locale);
}

void addLanguageSettings(SettingController controller) {
  controller.settings[LanguageSettings.language] = Setting<int>(LanguageSettings.language, 0);
}

class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPageBase(
      label: "language",
      child: Column(
        children: [
          ListSelectionSetting(
            settingName: "language",
            items: LanguageSettings.languages,
            callback: (language) {
              Get.updateLocale((language as LanguageSelection).locale);
            },
          )
        ],
      ),
    );
  }
}
