import 'package:chat_interface/controller/conversation/message_provider.dart';
import 'package:chat_interface/util/vertical_spacing.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:liphium_bridge/liphium_bridge.dart';
import 'package:path/path.dart' as path;

enum FileTypes {
  image,
  video,
  audio,
  document,
  unidentified,
}

const extensionToType = {
  "png": FileTypes.image,
  "jpg": FileTypes.image,
  "jpeg": FileTypes.image,
  "gif": FileTypes.image,
  "mp3": FileTypes.audio,
  "ogg": FileTypes.audio,
  "wav": FileTypes.audio,
  "mp4": FileTypes.video,
  "mov": FileTypes.video,
  "avi": FileTypes.video,
  "mkv": FileTypes.video,
  "pdf": FileTypes.document,
  "doc": FileTypes.document,
  "docx": FileTypes.document,
};

IconData getIconForFileName(String name) {
  final extension = name.split(".").last;
  final type = extensionToType[extension] ?? FileTypes.unidentified;
  return getIconForType(type);
}

IconData getIconForType(FileTypes type) {
  switch (type) {
    case FileTypes.image:
      return Icons.image;
    case FileTypes.video:
      return Icons.video_collection;
    case FileTypes.audio:
      return Icons.library_music;
    case FileTypes.document:
      return Icons.text_snippet;
    case FileTypes.unidentified:
      return Icons.insert_drive_file;
  }
}

class FilePreview extends StatelessWidget {
  final XFile file;
  const FilePreview({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    final extension = path.basename(file.path).split(".").last;
    final type = extensionToType[extension] ?? FileTypes.unidentified;

    switch (type) {
      case FileTypes.image:
        return XImage(
          file: file,
          fit: BoxFit.cover,
        );

      case FileTypes.audio:
        return const Center(
          child: Icon(
            size: 50,
            Icons.library_music,
          ),
        );

      case FileTypes.document:
        return const Center(
          child: Icon(
            size: 50,
            Icons.text_snippet,
          ),
        );

      case FileTypes.video:
      case FileTypes.unidentified:
        return const Center(
          child: Icon(
            size: 50,
            Icons.insert_drive_file,
          ),
        );
    }
  }
}

class SquareFileRenderer extends StatefulWidget {
  final UploadData file;
  final VoidCallback? onRemove;

  const SquareFileRenderer({super.key, required this.file, required this.onRemove});
  @override
  State<SquareFileRenderer> createState() => _SquareFileRendererState();
}

class _SquareFileRendererState extends State<SquareFileRenderer> {
  final duration = 250.ms;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: defaultSpacing * 0.5),
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(defaultSpacing),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(defaultSpacing),
          child: Stack(
            children: [
              Container(color: Get.theme.colorScheme.primaryContainer, width: 200, height: 200, child: FilePreview(file: widget.file.file)),
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(defaultSpacing),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(defaultSpacing),
                      color: Get.theme.colorScheme.inverseSurface,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        horizontalSpacing(defaultSpacing),
                        Expanded(
                          child: Text(
                            path.basename(widget.file.file.path),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        horizontalSpacing(defaultSpacing),
                        Obx(
                          () => Visibility(
                            visible: widget.file.progress.value == 0,
                            replacement: Padding(
                              padding: const EdgeInsets.all(defaultSpacing),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  value: widget.file.progress.value,
                                  strokeWidth: 3,
                                  color: Get.theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
                            child: IconButton(
                              onPressed: () {
                                widget.onRemove?.call();
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
