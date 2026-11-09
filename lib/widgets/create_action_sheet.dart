import 'package:flutter/material.dart';

enum CreateActionType { task, habit }

Future<CreateActionType?> showCreateActionSheet(BuildContext context) {
  return showModalBottomSheet<CreateActionType>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.task_alt_rounded),
                ),
                title: const Text(
                  'Công việc mới',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Việc cần làm có hạn định hoặc thời gian cụ thể',
                ),
                onTap: () => Navigator.pop(context, CreateActionType.task),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.repeat_rounded)),
                title: const Text(
                  'Thói quen mới',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Lặp lại hàng ngày để duy trì chuỗi streak',
                ),
                onTap: () => Navigator.pop(context, CreateActionType.habit),
              ),
            ],
          ),
        ),
      );
    },
  );
}
