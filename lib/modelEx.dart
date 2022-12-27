//Modelの継承クラス
//
//model.dartのスニペットと比較してください。
// import 'package:pytorch_mobile/enums/dtype.dart';
//
// const TORCHVISION_NORM_MEAN_RGB = [0.485, 0.456, 0.406];
// const TORCHVISION_NORM_STD_RGB = [0.229, 0.224, 0.225];
//


import 'dart:io';

import 'package:pytorch_mobile/model.dart';

// class ModelEx extends Model{
//   ModelEx(int index) : super(index);
//   Future<String> getImagePrediction(
//       List image, int width, int height, String labelPath,
//       {List<double> mean = TORCHVISION_NORM_MEAN_RGB,
//       List<double> std = TORCHVISION_NORM_STD_RGB}) async {
//     // Assert mean std
//     assert(mean.length == 3, "mean should have size of 3");
//     assert(std.length == 3, "std should have size of 3");

//     List<String> labels = await _getLabels(labelPath);
//     List byteArray = image.readAsBytesSync();
//     final List? prediction = await _channel.invokeListMethod("predictImage", {
//       "index": _index,
//       "image": byteArray,
//       "width": width,
//       "height": height,
//       "mean": mean,
//       "std": std
//     });
//     double maxScore = double.negativeInfinity;
//     int maxScoreIndex = -1;
//     for (int i = 0; i < prediction!.length; i++) {
//       if (prediction[i] > maxScore) {
//         maxScore = prediction[i];
//         maxScoreIndex = i;
//       }
//     }
//     return labels[maxScoreIndex];
//   }
// }

