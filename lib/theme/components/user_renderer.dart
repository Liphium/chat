import 'package:chat_interface/controller/account/friend_controller.dart';
import 'package:chat_interface/controller/current/status_controller.dart';
import 'package:chat_interface/theme/ui/profile/status_renderer.dart';
import 'package:chat_interface/util/vertical_spacing.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class UserAvatar extends StatefulWidget {
  final String id;
  final double? size;
  final FriendController? controller;
  final Friend? user;

  const UserAvatar({super.key, required this.id, this.size, this.controller, this.user});

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  @override
  void initState() {
    var friend = getFriend();
    friend.loadProfilePicture();
    super.initState();
  }

  @override
  void dispose() {
    getFriend().disposeProfilePicture();
    super.dispose();
  }

  Friend getFriend() {
    return (widget.user ?? (widget.controller ?? Get.find<FriendController>()).friends[widget.id]) ?? Friend.unknown(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    var friend = getFriend();

    return SizedBox(
      width: widget.size ?? 45,
      height: widget.size ?? 45,
      child: Obx(
        () {
          if (friend.profilePictureImage.value != null) {
            final image = friend.profilePictureImage.value!;
            final scale = friend.profilePictureData.scaleFactor * (300 / (widget.size ?? 45));
            return ClipOval(
              child: RawImage(
                fit: BoxFit.none,
                scale: scale,
                image: image,
                alignment: Alignment(friend.profilePictureData.moveX, friend.profilePictureData.moveY),
              ),
            );
          }

          return CircleAvatar(
            backgroundColor: Get.theme.colorScheme.primaryContainer,
            radius: widget.size ?? 45,
            child: SelectionContainer.disabled(
              child: Text(
                friend.name.substring(0, 1),
                style: Get.theme.textTheme.labelMedium!.copyWith(
                  fontSize: (widget.size ?? 45) * 0.5,
                  fontWeight: FontWeight.bold,
                  color: widget.id == StatusController.ownAccountId ? Get.theme.colorScheme.tertiary : Get.theme.colorScheme.onPrimary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class UserRenderer extends StatelessWidget {
  final String id;
  final FriendController? controller;

  const UserRenderer({super.key, required this.id, this.controller});

  @override
  Widget build(BuildContext context) {
    var friend = (controller ?? Get.find<FriendController>()).friends[id];
    final own = id == StatusController.ownAccountId;
    StatusController? statusController = own ? Get.find<StatusController>() : null;
    if (own) friend = Friend.me(statusController);
    friend ??= Friend.unknown(id);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        UserAvatar(id: friend.id, size: 40),
        horizontalSpacing(defaultSpacing),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(friend.name, overflow: TextOverflow.ellipsis, style: Get.theme.textTheme.bodyMedium),
                  horizontalSpacing(defaultSpacing),
                  Obx(() => StatusRenderer(status: own ? statusController!.type.value : friend!.statusType.value)),
                ],
              ),
              Obx(
                () => Visibility(
                  visible: own ? statusController!.status.value != "-" : friend!.status.value != "-",
                  child: Text(
                    own ? statusController!.status.value : friend!.status.value,
                    style: Get.theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
            ],
          ),
        )
      ],
    );
  }
}
