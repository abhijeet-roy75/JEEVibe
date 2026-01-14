// Cached Image Widget
//
// Displays images with offline support.
// Attempts to load from local cache first, then falls back to network.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../providers/offline_provider.dart';
import '../../services/offline/image_cache_service.dart';
import '../../theme/app_colors.dart';

class CachedImageWidget extends StatefulWidget {
  final String? imageUrl;
  final String? localImagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedImageWidget({
    super.key,
    this.imageUrl,
    this.localImagePath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<CachedImageWidget> createState() => _CachedImageWidgetState();
}

class _CachedImageWidgetState extends State<CachedImageWidget> {
  final ImageCacheService _imageCacheService = ImageCacheService();
  String? _resolvedUrl;
  File? _cachedFile;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(CachedImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.localImagePath != widget.localImagePath) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _cachedFile = null;
      _resolvedUrl = null;
    });

    // Try local path first
    if (widget.localImagePath != null && widget.localImagePath!.isNotEmpty) {
      final file = File(widget.localImagePath!);
      if (await file.exists()) {
        if (mounted) {
          setState(() {
            _cachedFile = file;
            _isLoading = false;
          });
        }
        return;
      }
    }

    // Try to get from cache or network
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      try {
        // Resolve gs:// URLs
        String? url = widget.imageUrl;
        if (widget.imageUrl!.startsWith('gs://')) {
          url = await _imageCacheService.resolveGsUrl(widget.imageUrl!);
        }

        if (url != null && mounted) {
          setState(() {
            _resolvedUrl = url;
            _isLoading = false;
          });
        } else if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_isLoading) {
      content = widget.placeholder ?? _buildLoadingPlaceholder();
    } else if (_hasError) {
      content = widget.errorWidget ?? _buildErrorWidget();
    } else if (_cachedFile != null) {
      // Load from local file
      content = Image.file(
        _cachedFile!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          return widget.errorWidget ?? _buildErrorWidget();
        },
      );
    } else if (_resolvedUrl != null) {
      // Load from network with caching
      content = CachedNetworkImage(
        imageUrl: _resolvedUrl!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        placeholder: (context, url) =>
            widget.placeholder ?? _buildLoadingPlaceholder(),
        errorWidget: (context, url, error) =>
            widget.errorWidget ?? _buildErrorWidget(),
      );
    } else {
      content = widget.errorWidget ?? _buildErrorWidget();
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: content,
      );
    }

    return content;
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height ?? 200,
      color: AppColors.backgroundLight,
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryPurple,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Consumer<OfflineProvider>(
      builder: (context, offlineProvider, child) {
        final isOffline = offlineProvider.isOffline;

        return Container(
          width: widget.width,
          height: widget.height ?? 150,
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: widget.borderRadius,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isOffline ? Icons.cloud_off : Icons.broken_image,
                  color: AppColors.textLight,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  isOffline ? 'Image not cached' : 'Failed to load image',
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Simplified image widget that just shows cached or network image
class OfflineAwareImage extends StatelessWidget {
  final String? imageUrl;
  final String? localPath;
  final double? width;
  final double? height;
  final BoxFit fit;

  const OfflineAwareImage({
    super.key,
    this.imageUrl,
    this.localPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    // If we have a local path and it exists, use it
    if (localPath != null && localPath!.isNotEmpty) {
      final file = File(localPath!);
      return FutureBuilder<bool>(
        future: file.exists(),
        builder: (context, snapshot) {
          if (snapshot.data == true) {
            return Image.file(
              file,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (_, __, ___) => _buildFallback(context),
            );
          }
          // Fall through to network image
          return _buildNetworkImage(context);
        },
      );
    }

    return _buildNetworkImage(context);
  }

  Widget _buildNetworkImage(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallback(context);
    }

    // Handle gs:// URLs
    if (imageUrl!.startsWith('gs://')) {
      return _buildGsImage(context);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => _buildLoading(),
      errorWidget: (context, url, error) => _buildFallback(context),
    );
  }

  Widget _buildGsImage(BuildContext context) {
    return FutureBuilder<String?>(
      future: ImageCacheService().resolveGsUrl(imageUrl!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _buildFallback(context);
        }
        return CachedNetworkImage(
          imageUrl: snapshot.data!,
          width: width,
          height: height,
          fit: fit,
          placeholder: (context, url) => _buildLoading(),
          errorWidget: (context, url, error) => _buildFallback(context),
        );
      },
    );
  }

  Widget _buildLoading() {
    return Container(
      width: width,
      height: height ?? 150,
      color: AppColors.backgroundLight,
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryPurple,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    return Container(
      width: width,
      height: height ?? 150,
      color: AppColors.backgroundLight,
      child: const Center(
        child: Icon(
          Icons.image_not_supported,
          color: AppColors.textLight,
          size: 32,
        ),
      ),
    );
  }
}
