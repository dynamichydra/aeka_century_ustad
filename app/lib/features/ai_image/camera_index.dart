import 'dart:io';

import 'package:century_ai/features/ai_image/simple_crop_page.dart';
import 'package:century_ai/utils/methods/image_picker_helper.dart';
import 'package:century_ai/utils/methods/temp_image_store.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dummy_data.dart';

class CameraIndex extends StatelessWidget {
  const CameraIndex({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Upload / Camera Card
            Card(
              color: const Color(0xFFF6F4FA),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      "Create your own",
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final File? image = await pickFromGallery();
                              if (image == null) return;

                              final File? cropped = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SimpleCropPage(imageFile: image),
                                ),
                              );

                              if (cropped == null) return;

                              const int tempId = -1;
                              TempImageStore.setImage(tempId, cropped);

                              context.push("/image_edit_page", extra: tempId);
                            },

                            borderRadius: BorderRadius.circular(12),
                            child: Card(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.folder, size: 48),
                                    SizedBox(height: 10),
                                    Text("Choose from Gallery"),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final File? image = await pickFromCamera();
                              if (image == null) return;

                              final File? cropped = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SimpleCropPage(imageFile: image),
                                ),
                              );

                              if (cropped == null) return;

                              const int tempId = -1;
                              TempImageStore.setImage(tempId, cropped);

                              context.push("/image_edit_page", extra: tempId);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Card(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.camera_alt, size: 48),
                                    SizedBox(height: 10),
                                    Text("Click a Photo"),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// Search
            TextField(
              decoration: InputDecoration(
                hintText: "Search furniture...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// Furniture List
            const Text(
              "Your Furniture",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 12),

            ListView.builder(
              itemCount: dummyFurnitureList.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final item = dummyFurnitureList[index];

                return InkWell(
                  onTap: () {
                    context.push("/image_edit_page", extra: item["id"]);
                  },
                  child: Card(
                    color: Color(0xFFF6F4FA),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(16),
                          ),
                          child: Image.asset(
                            item["image"],
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item["name"],
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item["category"],
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  item["details"],
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
