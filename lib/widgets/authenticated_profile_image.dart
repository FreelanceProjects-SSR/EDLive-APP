import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:school_app/services/profile_image_service.dart';

/// Fetches bytes with authorization so protected images also work on web,
/// where browser image elements cannot attach a Bearer header.
class AuthenticatedProfileImage extends StatefulWidget {
  const AuthenticatedProfileImage({
    super.key,
    required this.imageUrl,
    required this.placeholder,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
  });

  final String imageUrl;
  final Widget placeholder;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;

  @override
  State<AuthenticatedProfileImage> createState() =>
      _AuthenticatedProfileImageState();
}

class _AuthenticatedProfileImageState extends State<AuthenticatedProfileImage> {
  late Future<Uint8List> _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedProfileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) _load();
  }

  void _load() {
    _image = const ProfileImageService().load(widget.imageUrl);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    height: widget.height,
    child: FutureBuilder<Uint8List>(
      future: _image,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            snapshot.hasError ||
            !snapshot.hasData) {
          return widget.placeholder;
        }
        return Image.memory(
          snapshot.data!,
          width: widget.width,
          height: widget.height,
          fit: BoxFit.cover,
          cacheWidth: widget.cacheWidth,
          cacheHeight: widget.cacheHeight,
          gaplessPlayback: false,
          errorBuilder: (_, _, _) => widget.placeholder,
        );
      },
    ),
  );
}
