import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class SelfieChangeStatus {
  final bool hasPendingRequest;
  final String? requestId;
  final String? status;
  final DateTime? createdAt;

  SelfieChangeStatus({
    required this.hasPendingRequest,
    this.requestId,
    this.status,
    this.createdAt,
  });

  factory SelfieChangeStatus.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final request = data['request'] as Map<String, dynamic>?;
    return SelfieChangeStatus(
      hasPendingRequest: data['hasPendingRequest'] as bool? ?? false,
      requestId: request?['id'] as String?,
      status: request?['status'] as String?,
      createdAt: request?['createdAt'] != null
          ? DateTime.tryParse(request!['createdAt'] as String)
          : null,
    );
  }
}

class SelfieChangeService {
  Future<SelfieChangeStatus> getStatus() async {
    final response = await authService.authenticatedGet(
      ApiConfig.selfieChangeStatusEndpoint,
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return SelfieChangeStatus.fromJson(data);
    }
    throw Exception(data['message']?.toString() ?? 'Failed to fetch status');
  }

  Future<void> submitRequest(File imageFile) async {
    final token = await authService.getToken();
    if (token == null) throw Exception('Not authenticated');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConfig.selfieChangeRequestEndpoint),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data['message'];
      if (message is List) {
        throw Exception(message.join(', '));
      }
      throw Exception(message?.toString() ?? 'Failed to submit selfie change request');
    }
  }
}

final selfieChangeService = SelfieChangeService();
