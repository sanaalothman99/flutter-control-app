import 'package:flutter/material.dart';

class HeaderSection extends StatelessWidget {
  final ValueNotifier<bool> isGridEnabled;

  const HeaderSection({super.key, required this.isGridEnabled});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // زر القائمة
              PopupMenuButton<String>(
                icon: const Icon(Icons.menu, color: Colors.black87),
                onSelected: (value) {
                  if (value == 'back') {
                    Navigator.of(context).maybePop();
                  } else if (value == 'exit') {
                    // ✅ الرجوع لأول صفحة
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: 'back',
                    child: Row(
                      children: [Icon(Icons.arrow_back), SizedBox(width: 8), Text('back')],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'exit',
                    child: Row(
                      children: [Icon(Icons.logout), SizedBox(width: 8), Text('exit')],
                    ),
                  ),
                ],
              ),

              // الشعار
              Image.asset(
                'assets/LogoDRD.png',
                height: screenWidth * 0.12,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),

        // خط فاصل
        const Divider(thickness: 1, color: Colors.grey),

      ],
    );
  }
}


