import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'dart:developer';
// Uint8List などの型を扱う場合があるので以下もインポートすると良いです

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'package:image/image.dart' as im;
import 'package:pytorch_mobile/model.dart';

import 'package:pytorch_mobile/pytorch_mobile.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';

import 'modelEx.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        snackBarTheme: const SnackBarThemeData(
            actionTextColor: Colors.blueAccent,
            contentTextStyle: TextStyle(color: Colors.white)),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<LinePoints> lines = <LinePoints>[];
  List<LinePoints> undoLines = <LinePoints>[];
  List<Offset> nowPoints = <Offset>[];
  List<Offset> queuePoints = <Offset>[];
  Offset? startPoint;
  bool isDrawing = false;
  bool isOldDrawing = false;
  bool showPallet = true;
  ui.Image? uiimage;
  Uint8List? drewUint8Image;
  String? result;
  // ジェスチャー移動を検知
  void moveGestureDetector(Offset localPosition) {
    if (!isDrawing) {
      return;
    }
    Offset p = Offset(localPosition.dx, localPosition.dy);
    if (isOldDrawing) {
      queuePoints.add(p);
    } else {
      setState(() {
        if (queuePoints.isNotEmpty) {
          nowPoints.addAll(queuePoints);
          queuePoints.clear();
        }
        nowPoints.add(p);
      });
    }
  }

  // 描画開始イベント
  Future<void> newGestureDetector(
      Offset globalPosition, Offset localPosition) async {
    int margin = 20;
    // 画面上下端からのスタートは無視する
    if (globalPosition.dy < margin ||
        globalPosition.dy > (MediaQuery.of(context).size.height - margin)) {
      isDrawing = false;
      return;
    }
    isDrawing = true;
    isOldDrawing = true;
    if (nowPoints.isNotEmpty) {
      LinePoints l = LinePoints(List<Offset>.from(nowPoints));
      lines.add(l);
      await setOldImage();
      nowPoints.clear();
    }
    Offset p = Offset(localPosition.dx, localPosition.dy);
    setState(() {
      undoLines.clear();
      queuePoints.add(p);
    });
    isOldDrawing = false;
  }

  // 線を Image にして保存
  Future<void> setOldImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.black, BlendMode.color);
    final p = Paint()
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 25.0; // 線の太さ
    if (uiimage != null) {
      canvas.drawImage(uiimage!, const Offset(0, 0), p);
    }
    for (int i = 1; i < nowPoints.length; i++) {
      Offset p1 = nowPoints[i - 1];
      Offset p2 = nowPoints[i];
      p.color = Colors.white;
      canvas.drawLine(p1, p2, p);
    }
    final picture = recorder.endRecording();
    var canvasSize = 280;
    int w = canvasSize.toInt();
    int h = canvasSize.toInt();
    ui.Image tmp = await picture.toImage(w, h);
    //tmpの解像度を28*28に変更
    ui.Image tmp2 = await resizeImage(tmp);
    setState(() {
      uiimage = tmp;
    });
  }

  // undo, redo 用に全て描き直し
  Future<void> setAllImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.black, BlendMode.color);
    final p = Paint()
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 25.0;

    for (int i = 0; i < lines.length; i++) {
      LinePoints l = lines[i];
      for (int j = 1; j < l.points.length; j++) {
        Offset p1 = l.points[j - 1];
        Offset p2 = l.points[j];
        p.color = Colors.white;
        canvas.drawLine(p1, p2, p);
      }
    }

    final picture = recorder.endRecording();
    var canvasSize = 280;
    int w = canvasSize.toInt();
    int h = canvasSize.toInt();
    ui.Image tmp = await picture.toImage(w, h);
    //tmpの解像度を28*28に変更
    ui.Image tmp2 = await resizeImage(tmp);
    setState(() {
      uiimage = tmp;
    });
  }

  // 色変更
  Future<void> changeColor(Color c) async {
    if (nowPoints.isNotEmpty) {
      LinePoints l = LinePoints(List<Offset>.from(nowPoints));
      lines.add(l);
      await setOldImage();
    }
    setState(() {
      nowPoints.clear();
    });
  }

  List<MaterialAccentColor> colors = Colors.accents;

  // 描画を全てクリアする
  void _tapClear() {
    setState(() {
      uiimage = null;
      lines.clear();
      nowPoints.clear();
      undoLines.clear();
    });
  }

  // 描画リストから取り除き、取り除いたものリストへ入れる
  Future<void> _undo() async {
    if (nowPoints.isNotEmpty) {
      LinePoints l = LinePoints(List<Offset>.from(nowPoints));
      setState(() {
        undoLines.add(l);
        nowPoints.clear();
      });
      await setAllImage();
      return;
    }
    if (lines.isEmpty) {
      return;
    }
    setState(() {
      undoLines.add(lines.last);
      lines.removeLast();
    });
    await setAllImage();
  }

  // 取り除いたものリストから描画リストへセット
  Future<void> _redo() async {
    if (undoLines.isEmpty) {
      return;
    }
    setState(() {
      lines.add(undoLines.last);
      undoLines.removeLast();
    });
    await setAllImage();
  }

  // 描画データがあるかどうか
  // 保存ボタンと削除ボタンの有効無効判定
  bool isWriteData() {
    return lines.isNotEmpty || nowPoints.isNotEmpty || undoLines.isNotEmpty;
  }

  // Undo できるかどうか
  bool canUndo() {
    return lines.isNotEmpty || nowPoints.isNotEmpty;
  }

  // Redo できるかどうか
  bool canRedo() {
    return undoLines.isNotEmpty;
  }

  //====================================ページ部分===================================
  @override
  Widget build(BuildContext context) {
    var canvasSize = 280.0;
    return Scaffold(
      primary: false,
      appBar: AppBar(
        title: const Text('MNIST'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: canUndo() ? _undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: canRedo() ? _redo : null,
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: isWriteData() ? _tapClear : null,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: canvasSize,
            height: canvasSize,
            margin: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10.0),
              boxShadow: const [
                BoxShadow(
                  color: Colors.grey,
                  offset: Offset(2.0, 2.0),
                  blurRadius: 10.0,
                ),
              ],
            ),
            child: GestureDetector(
              onPanDown: (DragDownDetails details) {
                newGestureDetector(
                    details.globalPosition, details.localPosition);
              },
              onPanUpdate: (DragUpdateDetails details) {
                moveGestureDetector(details.localPosition);
              },
              child: CustomPaint(
                painter: PaintCanvas(lines, nowPoints, uiimage),
              ),
            ),
          ),
          Row(
            children: [
              Column(
                children: [
                  Text("描いた画像"),
                  Container(
                    child: drewUint8Image==null?null:Image.memory(drewUint8Image!),
                  ),
                ],
              ),
              Column(
                children: [
                  Text("予測結果"),
                  Container(
                    child: Text(result??""),
                  ),
                ],
              ),
            ],
          ),
          //予測ボタン
          ElevatedButton(
            child: const Text('予測'),
            onPressed: () async {
              //ボタンを押したらキャンバスの画像を取得
              if (nowPoints.isNotEmpty) {
                LinePoints l = LinePoints(List<Offset>.from(nowPoints));
                lines.add(l);
                await setOldImage(); // 画像を更新
              }
              setState(() {
                nowPoints.clear();
              });
              await setAllImage();
              if (uiimage == null) {
                return;
              }

              // io.image→Uint8のList→image.imageに変換
              var pngBytes =
                  await uiimage!.toByteData(format: ImageByteFormat.png);
              Uint8List pngUint8List = pngBytes!.buffer.asUint8List();
              im.Image? imImage = im.decodeImage(pngUint8List);
              //編集
              imImage = im.copyResize(imImage!, width: 28, height: 28);
              //image.image→Uint8のListに変換(表示用,モデルに渡す用)
              pngUint8List = Uint8List.fromList(im.encodePng(imImage));
              setState(() {
                drewUint8Image = pngUint8List;
              });

              print("予測");
              // 予測
              String res = await predictPngData(pngUint8List);
              //var res = 0;
              print("終了");
              // 予測結果を表示
              setState(() {
                result = res;
              });
            },
          ),
        ],
      ),
    );
  }

  Future<File> getImageFileFromAssets(String path) async {
    final byteData = await rootBundle.load('assets/mnistdata/$path');

    final file =
        File('${(await getApplicationDocumentsDirectory()).path}/$path');
    await file.writeAsBytes(byteData.buffer
        .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));

    return file;
  }

  resizeImage(ui.Image image) async {
    // 画像をリサイズ
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint()..isAntiAlias = true;
    canvas.drawImage(image, Offset.zero, paint);
    final ui.Picture picture = recorder.endRecording();
    final ui.Image resizedImage = await picture.toImage(28, 28);
    return resizedImage;
  }

  predictPngData(Uint8List pngUint8List) async {
    //pytorch model
    Model imageModel = await PyTorchMobile.loadModel('assets/models/test.pt');
    //PytorchMobileのデフォルトの引数は画像のパスだが、中身のpngDataのUint8Listを渡せるように変更している。
    var imagePrediction = imageModel.getImagePrediction(
        pngUint8List, 28, 28, "assets/labels/labels.csv");
    return imagePrediction;
  }

}

// 実際に描画するキャンバス
class PaintCanvas extends CustomPainter {
  final List<LinePoints> lines;
  final List<Offset> nowPoints;
  final ui.Image? image;

  PaintCanvas(this.lines, this.nowPoints, this.image);

  @override
  void paint(Canvas canvas, Size size) {
    Paint p = Paint()
      ..isAntiAlias = true
      ..color = Colors.redAccent
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 25.0;

    if (image != null) {
      canvas.drawImage(image!, const Offset(0, 0), p);
    }
    for (int i = 1; i < nowPoints.length; i++) {
      Offset p1 = nowPoints[i - 1];
      Offset p2 = nowPoints[i];
      p.color = Colors.white;
      canvas.drawLine(p1, p2, p);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

// 一筆書き分の座標を持つClass
class LinePoints {
  final List<Offset> points;
  LinePoints(this.points);
}
