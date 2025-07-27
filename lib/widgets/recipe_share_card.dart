
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:palette_generator/palette_generator.dart';

class RecipeShareCard extends StatefulWidget {
  final Map<String, dynamic> recipe;
  const RecipeShareCard({super.key, required this.recipe});
  @override
  State<RecipeShareCard> createState() => _RecipeShareCardState();
}

class _RecipeShareCardState extends State<RecipeShareCard> {
  Color _themeColor = const Color(0xFF6D8A7A);
  bool _hasImage = false;

  @override
  void initState() {
    super.initState();
    _hasImage = widget.recipe['image'] != null && widget.recipe['image'].startsWith('http');
    _updatePalette();
  }

  Future<void> _updatePalette() async {
    if (!_hasImage) return;
    try {
      final provider = NetworkImage(widget.recipe['image']);
      final generator = await PaletteGenerator.fromImageProvider(provider, size: const Size(100, 100));
      if (mounted) {
        setState(() {
          _themeColor = generator.vibrantColor?.color ?? generator.dominantColor?.color ?? const Color(0xFF6D8A7A);
        });
      }
    } catch (e) {
      // Keep default color
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 640,
      decoration: _buildAuraBackground(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 20), // Adjusted padding
        child: Column(
          children: [
            // Section 1: Asymmetrical Header (Image on left, info on right)
            _buildHeader(),
            const SizedBox(height: 20),
            // Section 2: Content Card (Takes all remaining space)
            Expanded(child: _buildGlassCard()),
            // Section 3: Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  BoxDecoration _buildAuraBackground() {
    return BoxDecoration(
      gradient: RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [_themeColor.withOpacity(0.7), _themeColor],
      ),
    );
  }

  Widget _buildHeader() {
    final isDarkTheme = _themeColor.computeLuminance() < 0.4;
    final textColor = isDarkTheme ? Colors.white : Colors.black.withOpacity(0.85);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left: Circular Image
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 15, spreadRadius: 2)],
            border: Border.all(color: Colors.white.withOpacity(0.7), width: 3),
          ),
          child: ClipOval(
            child: _hasImage
                ? Image.network(widget.recipe['image']!, fit: BoxFit.cover, errorBuilder: (c, e, s) => _buildFallbackIcon())
                : _buildFallbackIcon(),
          ),
        ),
        const SizedBox(width: 15),
        // Right: Title and Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.recipe['name'] ?? '鸡尾酒',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.playfairDisplay(fontSize: 26, fontWeight: FontWeight.bold, color: textColor, height: 1.2),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.category_outlined, widget.recipe['category'] ?? '经典', textColor),
              const SizedBox(height: 5),
              _buildInfoRow(Icons.local_bar_outlined, widget.recipe['glass'] ?? '鸡尾酒杯', textColor),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackIcon() {
    return Container(color: Colors.white.withOpacity(0.7), child: Icon(Icons.local_bar, size: 50, color: _themeColor));
  }
  
  Widget _buildInfoRow(IconData icon, String text, Color textColor) {
    return Row(
      children: [
        Icon(icon, color: textColor.withOpacity(0.7), size: 13),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.lato(fontSize: 12, color: textColor.withOpacity(0.8), fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard() {
    final isDarkTheme = _themeColor.computeLuminance() < 0.4;
    final cardColor = isDarkTheme ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.4);
    final textColor = isDarkTheme ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.8);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('配料', textColor),
                const SizedBox(height: 8),
                _buildContentList(widget.recipe['ingredients'], textColor),
                const SizedBox(height: 15),
                _buildSectionTitle('调制步骤', textColor),
                const SizedBox(height: 8),
                _buildInstructions(textColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Text(title, style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w600, color: textColor));
  }

  Widget _buildContentList(List? items, Color textColor) {
    if (items == null || items.isEmpty) {
      return Text('暂无信息', style: GoogleFonts.lato(fontSize: 13, color: textColor));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        final text = '· ${item['name'] ?? ''} ${item['amount']?.toString() ?? ''} ${item['unit'] ?? ''}'.trim();
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(text, style: GoogleFonts.lato(fontSize: 13, color: textColor, height: 1.5)),
        );
      }).toList(),
    );
  }

  Widget _buildInstructions(Color textColor) {
    return Text(
      widget.recipe['instructions'] ?? '暂无步骤',
      style: GoogleFonts.lato(fontSize: 13, color: textColor.withOpacity(0.9), height: 1.6),
    );
  }

  Widget _buildFooter() {
    final isDarkTheme = _themeColor.computeLuminance() < 0.4;
    final qrColor = isDarkTheme ? _themeColor.withOpacity(0.9) : _themeColor;
    final textColor = isDarkTheme ? Colors.white : Colors.black.withOpacity(0.7);

    return Padding(
      padding: const EdgeInsets.only(top: 15.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(6)),
            child: QrImageView(
              data: 'onecup://recipe/${widget.recipe['id']}',
              version: QrVersions.auto,
              size: 50.0,
              gapless: true,
              padding: EdgeInsets.zero,
              eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: qrColor),
              dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: qrColor),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('OneCup', style: GoogleFonts.lato(fontSize: 15, color: textColor, fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text('扫码查看完整配方', style: GoogleFonts.lato(fontSize: 10, color: textColor.withOpacity(0.7))),
            ],
          ),
        ],
      ),
    );
  }
}
