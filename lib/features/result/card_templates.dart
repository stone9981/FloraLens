import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/plant.dart';
import '../../data/models/plant_profile.dart';

/// 卡片渲染所需的数据。
class ShareCardData {
  const ShareCardData({
    required this.imagePath,
    required this.candidate,
    required this.profile,
    required this.watermark,
    required this.date,
    this.onNameTap,
  });

  final String imagePath;
  final PlantCandidate candidate;
  final PlantProfile profile;
  final String watermark;
  final DateTime date;

  /// 花名被点击时的回调（分享卡片实时预览时设置，用于跳转百度百科）。
  /// 导出成图片时这个回调无意义，始终为 null。
  final VoidCallback? onNameTap;

  ShareCardData copyWith({
    String? imagePath,
    PlantCandidate? candidate,
    PlantProfile? profile,
    String? watermark,
    DateTime? date,
    VoidCallback? onNameTap,
  }) =>
      ShareCardData(
        imagePath: imagePath ?? this.imagePath,
        candidate: candidate ?? this.candidate,
        profile: profile ?? this.profile,
        watermark: watermark ?? this.watermark,
        date: date ?? this.date,
        onNameTap: onNameTap ?? this.onNameTap,
      );
}

/// 卡片基准宽度（逻辑像素）。导出时按 pixelRatio 放大，
/// 3x 下正好是 1080px，符合朋友圈/小红书的推荐尺寸。
const double cardWidth = 360;

/// 卡片上展示的花名：优先用档案标题，回落到识别出的中文名。
String _titleOf(ShareCardData data) =>
    data.profile.title.isNotEmpty ? data.profile.title : data.candidate.displayName;

/// 花名可点击：实时预览里点一下跳百度百科，并带个「↗」小标记提示可点。
///
/// [iconColor] 跟随各模板主色，避免夜色卡（白字）上看不清。
Widget _tappableName(
  ShareCardData data, {
  required TextStyle style,
  required Color iconColor,
  TextAlign textAlign = TextAlign.start,
}) {
  final onTap = data.onNameTap;
  final text = Text(
    _titleOf(data),
    style: style,
    textAlign: textAlign,
    overflow: TextOverflow.ellipsis,
    maxLines: 2,
  );
  if (onTap == null) return text;
  return GestureDetector(
    onTap: onTap,
    child: Tooltip(
      message: AppStrings.openBaike,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Flexible(child: text),
          const SizedBox(width: 5),
          Icon(Icons.open_in_new_rounded, size: 15, color: iconColor),
        ],
      ),
    ),
  );
}

/// 根据模板枚举构造对应卡片。
Widget buildShareCard(CardTemplate template, ShareCardData data,
    {VoidCallback? onNameTap}) {
  final d =
      onNameTap == null ? data : data.copyWith(onNameTap: onNameTap);
  switch (template) {
    case CardTemplate.magazine:
      return _MagazineCard(data: d);
    case CardTemplate.minimal:
      return _MinimalCard(data: d);
    case CardTemplate.herbarium:
      return _HerbariumCard(data: d);
    case CardTemplate.night:
      return _NightCard(data: d);
  }
}

String _formatDate(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

Widget _photo(ShareCardData data,
    {double height = 360, BorderRadius? radius, BoxFit fit = BoxFit.cover}) {
  return ClipRRect(
    borderRadius: radius ?? BorderRadius.zero,
    child: data.imagePath.isEmpty
        ? Container(
            height: height,
            width: cardWidth,
            color: const Color(0xFFE8ECE9),
            child: const Icon(Icons.local_florist_outlined,
                size: 64, color: Colors.white),
          )
        : Image.file(
            File(data.imagePath),
            height: height,
            width: cardWidth,
            fit: fit,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => Container(
              height: height,
              width: cardWidth,
              color: const Color(0xFFE8ECE9),
            ),
          ),
  );
}

/// 模板一：杂志风 —— 大图压顶 + 强对比标题，最耐看。
class _MagazineCard extends StatelessWidget {
  const _MagazineCard({required this.data});

  final ShareCardData data;

  @override
  Widget build(BuildContext context) {
    final p = data.profile;
    return Container(
      width: cardWidth,
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _photo(data, height: 330),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (p.latinName != null && p.latinName!.isNotEmpty)
                  Text(
                    p.latinName!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF8A968F),
                      letterSpacing: 0.4,
                    ),
                  ),
                const SizedBox(height: 6),
                _tappableName(
                  data,
                  iconColor: const Color(0xFF8A968F),
                  style: const TextStyle(
                    fontSize: 30,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17211D),
                    letterSpacing: -0.5,
                  ),
                ),
                if (data.candidate.familyGenus.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    data.candidate.familyGenus,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF6B7A74),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(height: 1, color: const Color(0xFFE4E9E6)),
                const SizedBox(height: 16),
                if (p.summary.isNotEmpty)
                  Text(
                    p.summary,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.65,
                      color: Color(0xFF33403A),
                    ),
                  ),
                if (p.language.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 3,
                        height: 13,
                        color: AppTheme.brandGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '花语 · ${p.language}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.brandGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (p.poemLine != null && p.poemLine!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  Text(
                    p.poemLine!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.7,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF7A8580),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    const Icon(Icons.local_florist_rounded,
                        size: 13, color: Color(0xFF9AA5A0)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        data.watermark,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9AA5A0),
                        ),
                      ),
                    ),
                    Text(
                      _formatDate(data.date),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9AA5A0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 模板二：极简白 —— 大量留白，适合配干净的花卉特写。
class _MinimalCard extends StatelessWidget {
  const _MinimalCard({required this.data});

  final ShareCardData data;

  @override
  Widget build(BuildContext context) {
    final p = data.profile;
    return Container(
      width: cardWidth,
      color: const Color(0xFFFCFCFB),
      padding: const EdgeInsets.fromLTRB(26, 30, 26, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: _photo(data, height: 300),
          ),
          const SizedBox(height: 26),
          _tappableName(
            data,
            textAlign: TextAlign.center,
            iconColor: const Color(0xFFA3ACA7),
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A201D),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          if (p.latinName != null && p.latinName!.isNotEmpty)
            Text(
              p.latinName!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                color: Color(0xFFA3ACA7),
              ),
            ),
          if (p.summary.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            Text(
              p.summary,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.75,
                color: Color(0xFF4B564F),
              ),
            ),
          ],
          if (p.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: p.tags
                  .take(3)
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F3F1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          t,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF5E6B64),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          Container(height: 1, width: 44, color: const Color(0xFFDDE3E0)),
          const SizedBox(height: 12),
          Text(
            '${data.watermark} · ${_formatDate(data.date)}',
            style: const TextStyle(fontSize: 10.5, color: Color(0xFFA8B1AC)),
          ),
        ],
      ),
    );
  }
}

/// 模板三：标本馆 —— 米黄纸感 + 边框，像博物馆的物种标签。
class _HerbariumCard extends StatelessWidget {
  const _HerbariumCard({required this.data});

  final ShareCardData data;

  @override
  Widget build(BuildContext context) {
    final p = data.profile;
    return Container(
      width: cardWidth,
      color: const Color(0xFFF6F2E7),
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFC9BF9E), width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: <Widget>[
                  const Text(
                    'FLORA SPECIMEN',
                    style: TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 2.2,
                      color: Color(0xFF9C9075),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(data.date),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9C9075),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _photo(
                data,
                height: 270,
                radius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _tappableName(
                    data,
                    iconColor: const Color(0xFF9C9075),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3B3627),
                    ),
                  ),
                  if (p.latinName != null && p.latinName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        p.latinName!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF7C7357),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Container(height: 1, color: const Color(0xFFDCD3B8)),
                  const SizedBox(height: 12),
                  if (data.candidate.familyGenus.isNotEmpty)
                    _HerbRow('科属', data.candidate.familyGenus),
                  if (p.bloomTime.isNotEmpty) _HerbRow('花期', p.bloomTime),
                  if (p.origin.isNotEmpty) _HerbRow('产地', p.origin),
                  if (p.language.isNotEmpty) _HerbRow('花语', p.language),
                  if (p.poemLine != null && p.poemLine!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      p.poemLine!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.7,
                        color: Color(0xFF6E664C),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    data.watermark,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFFA79A78),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HerbRow extends StatelessWidget {
  const _HerbRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 34,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF9C9075)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Color(0xFF4A4433),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 模板四：夜色 —— 深绿渐变，适合深色花卉或夜拍。
class _NightCard extends StatelessWidget {
  const _NightCard({required this.data});

  final ShareCardData data;

  @override
  Widget build(BuildContext context) {
    final p = data.profile;
    return Container(
      width: cardWidth,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF0F2A23), Color(0xFF173A31)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 26),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: <Widget>[
                const Icon(Icons.local_florist_rounded,
                    size: 15, color: Color(0xFF7FD8B4)),
                const SizedBox(width: 7),
                Text(
                  data.watermark,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF7FD8B4),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _photo(data, height: 268),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _tappableName(
                  data,
                  iconColor: const Color(0xFF8FA79B),
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                if (p.latinName != null && p.latinName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      p.latinName!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF8FA79B),
                      ),
                    ),
                  ),
                if (p.language.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '花语 · ${p.language}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFFB7E4CE),
                      ),
                    ),
                  ),
                ],
                if (p.summary.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(
                    p.summary,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.7,
                      color: Color(0xFFC4D4CC),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    if (p.bloomTime.isNotEmpty)
                      _NightMeta(Icons.calendar_month_outlined, p.bloomTime),
                    if (p.bloomTime.isNotEmpty) const SizedBox(width: 14),
                    if (data.candidate.family != null &&
                        data.candidate.family!.isNotEmpty)
                      _NightMeta(Icons.park_outlined, data.candidate.family!),
                    const Spacer(),
                    Text(
                      _formatDate(data.date),
                      style: const TextStyle(
                          fontSize: 10.5, color: Color(0xFF7A9086)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NightMeta extends StatelessWidget {
  const _NightMeta(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 12, color: const Color(0xFF8FB7A4)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 11, color: Color(0xFF8FB7A4)),
        ),
      ],
    );
  }
}
