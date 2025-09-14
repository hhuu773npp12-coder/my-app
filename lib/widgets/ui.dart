// lib/widgets/ui.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

/// =====================
/// 1) حقل نص مع عنوان
/// =====================
class LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ],
    );
  }
}

/// =====================
/// 2) حقل رقم هاتف عراقي
/// =====================
class PhoneField extends StatelessWidget {
  final TextEditingController controller;
  const PhoneField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: "رقم الهاتف (عراقي)",
      controller: controller,
      keyboardType: TextInputType.phone,
    );
  }
}

/// =====================
/// 3) زر رئيسي يغطي العرض
/// =====================
Widget primaryButton(String text, VoidCallback onTap, {Color? color}) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? Colors.blue, // اللون الافتراضي أزرق
      ),
      onPressed: onTap,
      child: Text(text),
    ),
  );
}

/// =====================
/// 4) زر ثانوي (رمادي)
/// =====================
Widget secondaryButton(String text, VoidCallback onTap) => SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        child: Text(text, style: const TextStyle(color: Colors.black)),
      ),
    );

/// =====================
/// 5) دالة inputField (مثل LabeledField)
/// =====================
Widget inputField(String label, TextEditingController controller,
        {TextInputType inputType = TextInputType.text}) =>
    LabeledField(
      label: label,
      controller: controller,
      keyboardType: inputType,
    );

/// =====================
/// 6) رفع صور (يدعم صور متعددة)
/// =====================
class ImagePickerField extends StatefulWidget {
  final String label;
  final int maxImages;
  const ImagePickerField({super.key, required this.label, this.maxImages = 1});

  @override
  State<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends State<ImagePickerField> {
  final List<XFile> _images = [];

  Future<void> _pickImage() async {
    if (_images.length >= widget.maxImages) return;
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _images.add(image));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          children: _images
              .map((img) => Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Image.file(
                      File(img.path),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ))
              .toList(),
        ),
        TextButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.add_a_photo),
          label: const Text("إضافة صورة"),
        ),
      ],
    );
  }
}

/// =====================
/// 7) إدخال كود (٤ خانات)
/// =====================
class CodeInput extends StatelessWidget {
  final List<TextEditingController> controllers;
  const CodeInput({super.key, required this.controllers});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        4,
        (i) => SizedBox(
          width: 50,
          child: TextField(
            controller: controllers[i],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            decoration: const InputDecoration(counterText: ""),
          ),
        ),
      ),
    );
  }
}

/// =====================
/// 8) زر تحديد الموقع
/// =====================
class LocationPickerButton extends StatelessWidget {
  final VoidCallback onPick;
  const LocationPickerButton({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPick,
      icon: const Icon(Icons.location_on),
      label: const Text("تحديد الموقع"),
    );
  }
}
