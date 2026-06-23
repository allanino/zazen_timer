import 'dart:io' show Platform, File;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ZazenTopBar extends StatefulWidget {
  const ZazenTopBar({super.key});

  @override
  State<ZazenTopBar> createState() => _ZazenTopBarState();
}

class _ZazenTopBarState extends State<ZazenTopBar> {
  bool _isInstalling = false;
  static const MethodChannel _channel = MethodChannel('session_service');

  Future<void> _installWatchApp() async {
    if (!Platform.isAndroid) return;

    setState(() {
      _isInstalling = true;
    });

    try {
      final response = await http.get(Uri.parse(
          'https://api.github.com/repos/allanino/zazen_timer/releases/latest'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final assets = data['assets'] as List;
        String? apkUrl;

        for (var asset in assets) {
          if (asset['name'].toString().contains('wear') &&
              asset['name'].toString().endsWith('.apk')) {
            apkUrl = asset['browser_download_url'];
            break;
          }
        }

        if (apkUrl != null) {
          // Download the APK to a local file
          final apkResponse = await http.get(Uri.parse(apkUrl));
          if (apkResponse.statusCode == 200) {
            final tempDir = await getTemporaryDirectory();
            final file = File('${tempDir.path}/zazen-timer-wear-os.apk');
            await file.writeAsBytes(apkResponse.bodyBytes);

            // Transfer to watch via Native Channel
            await _channel
                .invokeMethod('installOnWatch', {'apkPath': file.path});

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Transferring to watch... Please check your watch to confirm installation.')),
              );
            }
          } else {
            throw Exception('Failed to download APK.');
          }
        } else {
          throw Exception('Wear APK not found in latest release.');
        }
      } else {
        throw Exception('Failed to fetch release info.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInstalling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const SizedBox(width: 48),
            Center(
              child: Image.asset(
                'assets/images/logo_transparent.png',
                height: 64,
              ),
            ),
            if (Platform.isAndroid)
              IconButton(
                icon: _isInstalling
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.watch),
                onPressed: _isInstalling ? null : _installWatchApp,
                tooltip: 'Install on Watch',
                color: Colors.white70,
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}
