// // lib/screens/room_detail_screen.dart
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:smart_home_animation/core/shared/domain/entities/room.dart';

// import '../widgets/device_control.dart';

// class RoomDetailScreen extends StatelessWidget {
//   final Room room;

//   const RoomDetailScreen({super.key, required this.room});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         title: Text(room.name),
//         backgroundColor: Colors.transparent,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: Column(
//         children: [
//           if (room.wallpaperUrl != null)
//             Container(
//               height: 200,
//               width: double.infinity,
//               decoration: BoxDecoration(
//                 image: DecorationImage(
//                   image: AssetImage(room.wallpaperUrl!),
//                   fit: BoxFit.cover,
//                 ),
//               ),
//             ),
//           Expanded(
//             child: ListView.builder(
//               padding: const EdgeInsets.all(16),
//               itemCount: room.devices.length,
//               itemBuilder: (context, index) {
//                 return DeviceControl(device: room.devices[index]);
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
