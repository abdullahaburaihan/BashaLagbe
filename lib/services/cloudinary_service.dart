import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:basha_lagbe/post_property_screen.dart';

/// Result from a successful Cloudinary image upload.
class CloudinaryUploadResult {
  const CloudinaryUploadResult({
    required this.secureUrl,
    required this.publicId,
    this.deleteToken,
  });

  /// Permanent HTTPS CDN URL.
  final String secureUrl;

  /// Cloudinary public asset identifier.
  final String publicId;

  /// Temporary delete token (returned if upload preset has "Return delete token = Yes").
  /// Valid for 10 minutes from upload time.
  final String? deleteToken;
}

/// Result of uploading a batch of property photos to Cloudinary.
class CloudinaryPhotosUploadResult {
  const CloudinaryPhotosUploadResult({
    required this.photos,
    required this.deleteTokens,
  });

  /// The serialized photos array ready for Firestore storage.
  final List<Map<String, dynamic>> photos;

  /// Temporary delete tokens for newly uploaded photos (used for rollback on failure).
  final List<String> deleteTokens;
}

/// Service managing unsigned image uploads to Cloudinary for BashaLagbe.
///
/// Features:
/// - Client-side validation: max 5 MB, allows strictly valid JPG, PNG, and WebP signatures.
/// - Unsigned upload preset: no Cloudinary API secret is ever exposed on the client.
/// - Rollback on failure: uses Cloudinary delete tokens (when returned) to safely
///   clean up newly uploaded files if a batch upload or Firestore document creation fails.
class CloudinaryService {
  CloudinaryService({
    String? cloudName,
    String? uploadPreset,
    http.Client? client,
  })  : cloudName = cloudName ?? defaultCloudName,
        uploadPreset = uploadPreset ?? defaultUploadPreset,
        client = client ?? http.Client();

  static const String defaultCloudName = 'sgbsxxtm';
  static const String defaultUploadPreset = 'bashalagbe_properties';
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB
  static const Duration uploadTimeout = Duration(seconds: 30);

  static final CloudinaryService instance = CloudinaryService();

  final String cloudName;
  final String uploadPreset;
  final http.Client client;

  /// Validates that [bytes] is non-empty, within the 5 MB limit,
  /// and conforms to strictly valid JPG, PNG, or WebP format based on magic bytes.
  ///
  /// Returns null if valid, or a descriptive user-facing error message if invalid.
  static String? validateImageBytes(Uint8List bytes, {String? fileName}) {
    if (bytes.isEmpty) {
      return 'Image file is empty.';
    }
    if (bytes.length > maxFileSizeBytes) {
      final sizeMb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      return 'Image is too large ($sizeMb MB). Maximum allowed size is 5 MB.';
    }

    // Check magic bytes for format verification
    final isJpg = bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;

    final isPng = bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;

    final isWebp = bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;

    if (!isJpg && !isPng && !isWebp) {
      return 'Unsupported image format. Only JPG, PNG, and WebP are allowed.';
    }

    return null;
  }

  /// Uploads a single image to Cloudinary via unsigned upload preset.
  Future<CloudinaryUploadResult> uploadImage({
    required Uint8List bytes,
    required String fileName,
    String? folder,
  }) async {
    // 1. Client-side validation (enforces magic bytes strictly)
    final validationError = validateImageBytes(bytes, fileName: fileName);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri);

    request.fields['upload_preset'] = uploadPreset;
    if (folder != null && folder.trim().isNotEmpty) {
      request.fields['folder'] = folder.trim();
    }
    request.fields['tags'] = 'basha_lagbe,property';

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ),
    );

    final streamedResponse = await client.send(request).timeout(
      uploadTimeout,
      onTimeout: () {
        throw TimeoutException('Cloudinary upload timed out after 30 seconds. Please check your internet connection.');
      },
    );
    final responseBody = await streamedResponse.stream.bytesToString().timeout(
      uploadTimeout,
      onTimeout: () {
        throw TimeoutException('Cloudinary response stream timed out. Please check your internet connection.');
      },
    );

    if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final secureUrl = json['secure_url'] as String?;
      final publicId = json['public_id'] as String?;
      final deleteToken = json['delete_token'] as String?;

      if (secureUrl == null || secureUrl.isEmpty) {
        throw Exception('Cloudinary upload succeeded but no secure_url returned.');
      }

      return CloudinaryUploadResult(
        secureUrl: secureUrl,
        publicId: publicId ?? '',
        deleteToken: deleteToken,
      );
    } else {
      String errorMessage = 'Upload failed with HTTP ${streamedResponse.statusCode}';
      try {
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        if (json.containsKey('error') && json['error'] is Map) {
          errorMessage = json['error']['message'] as String? ?? errorMessage;
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  /// Safely attempts to delete an uploaded image using [deleteToken].
  ///
  /// Cloudinary provides delete tokens valid for 10 minutes when configured on the preset.
  /// If [deleteToken] is null, this cleanly returns false without throwing.
  Future<bool> deleteByToken(String? deleteToken) async {
    if (deleteToken == null || deleteToken.trim().isEmpty) {
      return false;
    }
    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/delete_by_token');
      final response = await client.post(uri, body: {'token': deleteToken.trim()}).timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json['result'] == 'ok';
      }
      return false;
    } catch (e) {
      debugPrint('CloudinaryService.deleteByToken notice: $e');
      return false;
    }
  }

  /// Safely attempts to delete multiple uploaded images using their [deleteTokens].
  Future<void> deletePhotosByTokens(Iterable<String> deleteTokens) async {
    for (final token in deleteTokens) {
      if (token.trim().isNotEmpty) {
        try {
          await deleteByToken(token.trim());
        } catch (e) {
          debugPrint('CloudinaryService.deletePhotosByTokens cleanup notice: $e');
        }
      }
    }
  }

  /// Uploads new in-memory photos to Cloudinary and returns [CloudinaryPhotosUploadResult]
  /// containing the serialized photo list for Firestore and temporary delete tokens for rollback.
  ///
  /// - Skips existing photos that already have [networkUrl].
  /// - Uploads newly picked photos that have [bytes].
  /// - If any upload fails midway, attempts rollback of newly uploaded images
  ///   using their delete tokens (if returned by Cloudinary) to avoid leaving orphan files.
  Future<CloudinaryPhotosUploadResult> uploadPropertyPhotos({
    required String ownerId,
    required String propertyId,
    required List<WizardPhotoItem> photos,
  }) async {
    final newlyUploadedTokens = <String>[];
    final resultPhotos = <Map<String, dynamic>>[];

    try {
      for (var i = 0; i < photos.length; i++) {
        final item = photos[i];
        if (item.bytes != null && item.bytes!.isNotEmpty) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = 'photo_${timestamp}_$i.jpg';
          final folder = 'properties/$ownerId/$propertyId';

          final uploadResult = await uploadImage(
            bytes: item.bytes!,
            fileName: fileName,
            folder: folder,
          );

          if (uploadResult.deleteToken != null && uploadResult.deleteToken!.isNotEmpty) {
            newlyUploadedTokens.add(uploadResult.deleteToken!);
          }

          resultPhotos.add({
            'label': item.label,
            'imageUrl': uploadResult.secureUrl,
            'storagePath': uploadResult.publicId,
            'isCover': item.isCover,
            'order': i,
          });
        } else if (item.networkUrl != null && item.networkUrl!.isNotEmpty) {
          // Preserve existing photo during edit
          resultPhotos.add({
            'label': item.label,
            'imageUrl': item.networkUrl,
            'storagePath': item.storagePath,
            'isCover': item.isCover,
            'order': i,
          });
        }
      }
      return CloudinaryPhotosUploadResult(
        photos: resultPhotos,
        deleteTokens: newlyUploadedTokens,
      );
    } catch (e) {
      debugPrint('Cloudinary photo upload failed: $e');
      if (newlyUploadedTokens.isNotEmpty) {
        debugPrint('Rolling back ${newlyUploadedTokens.length} newly uploaded images via delete tokens...');
        await deletePhotosByTokens(newlyUploadedTokens);
      }
      rethrow;
    }
  }
}
