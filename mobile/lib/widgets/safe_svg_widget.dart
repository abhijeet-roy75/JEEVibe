/// Safe SVG Widget
/// Wraps SvgPicture to handle SVG rendering with better error handling
/// 
/// Note: Console warnings about <metadata/> and <style/> elements are harmless
/// and come from the flutter_svg parser. The SVG will still render correctly.
/// These warnings are informational and don't affect functionality.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SafeSvgWidget extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final WidgetBuilder? placeholderBuilder;
  final Widget Function(BuildContext, Object, StackTrace)? errorBuilder;

  const SafeSvgWidget({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.placeholderBuilder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.network(
      url,
      fit: fit,
      width: width,
      height: height,
      placeholderBuilder: placeholderBuilder,
      errorBuilder: errorBuilder ?? (BuildContext context, Object error, StackTrace stackTrace) {
        // Log SVG errors to console but don't report to Crashlytics (handled gracefully)
        debugPrint('⚠️ SVG failed to load: $url');
        debugPrint('Error: $error');

        return Container(
          width: width ?? 200,
          height: height ?? 200,
          color: Colors.grey.shade200,
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.grey),
          ),
        );
      },
      allowDrawingOutsideViewBox: true,
      excludeFromSemantics: true,
      // Explicitly hide any title/desc elements that might be in the SVG
      theme: const SvgTheme(
        currentColor: Colors.transparent, // Don't affect colors
      ),
    );
  }
}
