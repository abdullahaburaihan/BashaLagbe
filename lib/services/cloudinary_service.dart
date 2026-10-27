import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:basha_lagbe/post_property_screen.dart';

/// Supported image format with canonical file extension and MIME type.
enum ImageFormat {
  jpeg(extension: 'jpg', mimeType: 'image/jpeg'),
  png(extension: 'png', mimeType: 'image/png'),
  webp(extension: 'webp', mimeType: 'image/webp');

  const ImageFormat({
    required this.extension,
    required this.mimeType,
  });

  final String extension;
  final String mimeType;
}

/// Exception thrown when a response from Cloudinary fails security or format validation.
class CloudinaryResponseValidationException implements Exception {
  CloudinaryResponseValidationException(this.message);
  final String message;

  @override
  String toString() => 'CloudinaryResponseValidationException: $message';
}

/// Signature parameters obtained from a trusted backend for a signed Cloudinary upload.
class CloudinaryUploadSignature {
  const CloudinaryUploadSignature({
    required this.signature,
    required this.timestamp,
    required this.apiKey,
    required this.cloudName,
    required this.folder,
    this.uploadPreset,
    this.tags,
  });

  final String signature;
  final int timestamp;
  final String apiKey;
  final String cloudName;
  final String folder;
  final String? uploadPreset;
  final String? tags;
}

/// Provider function for fetching a signed upload authorization from a trusted backend.
typedef CloudinarySignatureProvider = Future<CloudinaryUploadSignature> Function({
  required String propertyId,
});

/// Result from a successful Cloudinary image upload.
class CloudinaryUploadResult {
  const CloudinaryUploadResult({
    required this.secureUrl,
    required this.publicId,
    this.deleteToken,
    this.format,
    this.resourceType,
    this.bytes,
    this.width,
    this.height,
  });

  /// Permanent HTTPS CDN URL.
  final String secureUrl;

  /// Cloudinary public asset identifier.
  final String publicId;

  /// Temporary delete token (returned if upload preset has "Return delete token = Yes").
  /// Valid for 10 minutes from upload time.
  final String? deleteToken;

  /// Asset format (e.g. 'jpg', 'png', 'webp').
  final String? format;

  /// Resource type (e.g. 'image').
  final String? resourceType;

  /// File size in bytes as stored on Cloudinary.
  final int? bytes;

  /// Pixel width of uploaded image.
  final int? width;

  /// Pixel height of uploaded image.
  final int? height;
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

/// Service managing image uploads to Cloudinary for BashaLagbe.
///
/// Features:
/// - Client-side validation: max 5 MB, allows strictly valid JPG, PNG, and WebP signatures.
/// - Unsigned or signed upload modes: supports unsigned preset as well as trusted backend signatures.
/// - Strict response validation: verifies HTTPS delivery URL on res.cloudinary.com for the target cloud.
/// - Rollback on failure: uses Cloudinary delete tokens (when returned) to safely
///   clean up newly uploaded files if validation fails or batch upload fails.
class CloudinaryService {
  CloudinaryService({
    String? cloudName,
    String? uploadPreset,
    http.Client? client,
    this.signatureProvider,
    this.requireSignedUploads = false,
  })  : cloudName = cloudName ?? defaultCloudName,
        uploadPreset = uploadPreset ?? defaultUploadPreset,
        client = client ?? http.Client();

  static const String defaultCloudName = 'sgbsxxtm';
  static const String defaultUploadPreset = 'bashalagbe_properties';
  static const String defaultSignedUploadPreset = 'bashalagbe_properties_signed';
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB
  static const Duration uploadTimeout = Duration(seconds: 30);

  /// Default signature provider connecting to the Firebase Cloud Function getCloudinaryUploadSignature.
  ///
  /// Guarantees that the caller identity is established by Firebase Auth and that
  /// the upload folder is strictly bound to `properties/<uid>/<propertyId>`.
  static Future<CloudinaryUploadSignature> defaultSignatureProvider({
    required String propertyId,
    FirebaseFunctions? customFunctions,
  }) async {
    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase has not been initialized. Cannot request upload signature.');
    }
    final functions = customFunctions ?? FirebaseFunctions.instance;
    final callable = functions.httpsCallable('getCloudinaryUploadSignature');
    final response = await callable.call<Map<dynamic, dynamic>>({
      'propertyId': propertyId,
    });
    final data = Map<String, dynamic>.from(response.data);
    return CloudinaryUploadSignature(
      signature: data['signature'] as String,
      timestamp: (data['timestamp'] as num).toInt(),
      apiKey: data['apiKey'] as String,
      cloudName: data['cloudName'] as String,
      folder: data['folder'] as String,
      uploadPreset: data['uploadPreset'] as String?,
      tags: data['tags'] as String?,
    );
  }

  /// Default singleton instance used in the active application.
  /// Pre-configured with the server signature provider and strict signed upload enforcement.
  static CloudinaryService instance = CloudinaryService(
    signatureProvider: defaultSignatureProvider,
    requireSignedUploads: true,
  );

  final String cloudName;
  final String uploadPreset;
  final http.Client client;
  final CloudinarySignatureProvider? signatureProvider;
  final bool requireSignedUploads;

  /// Detects the image format (JPEG, PNG, or WebP) from magic byte signatures.
  ///
  /// Returns null if the byte signature does not match any supported format.
  static ImageFormat? detectImageFormat(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return ImageFormat.jpeg;
    }

    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return ImageFormat.png;
    }

    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return ImageFormat.webp;
    }

    return null;
  }

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

    if (detectImageFormat(bytes) == null) {
      return 'Unsupported image format. Only JPG, PNG, and WebP are allowed.';
    }

    return null;
  }

  /// Uploads a single image to Cloudinary via unsigned upload preset or backend signature.
  Future<CloudinaryUploadResult> uploadImage({
    required Uint8List bytes,
    required String fileName,
    String? folder,
    String? propertyId,
  }) async {
    // 1. Client-side validation (enforces magic bytes and size strictly)
    final validationError = validateImageBytes(bytes, fileName: fileName);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    // 2. Derive canonical image format, extension, and MIME type from validated bytes
    final format = detectImageFormat(bytes)!;
    final mimeParts = format.mimeType.split('/');
    final contentType = MediaType(mimeParts[0], mimeParts[1]);

    // Ensure filename ends with the derived format extension
    String effectiveFileName = fileName.trim();
    if (effectiveFileName.isEmpty) {
      effectiveFileName = 'photo.${format.extension}';
    } else if (!effectiveFileName.toLowerCase().endsWith('.${format.extension}')) {
      final dotIndex = effectiveFileName.lastIndexOf('.');
      if (dotIndex != -1) {
        effectiveFileName = '${effectiveFileName.substring(0, dotIndex)}.${format.extension}';
      } else {
        effectiveFileName = '$effectiveFileName.${format.extension}';
      }
    }

    // 3. Obtain signature from backend if a signature provider is configured or required
    final provider = signatureProvider;
    CloudinaryUploadSignature? signature;
    if (provider != null) {
      if (propertyId == null || propertyId.trim().isEmpty) {
        throw ArgumentError('propertyId is required for signed Cloudinary upload.');
      }
      try {
        signature = await provider(propertyId: propertyId.trim());
      } catch (e) {
        throw Exception(
          'Failed to obtain signed upload authorization from server: $e. '
          'Please ensure Firebase Cloud Functions are deployed and Cloudinary credentials are configured.',
        );
      }
    } else if (requireSignedUploads) {
      throw StateError(
        'Signed uploads are strictly required, but no signatureProvider is configured. '
        'Refusing to upload via unsigned preset in production.',
      );
    }

    final targetCloudName = signature?.cloudName ?? cloudName;
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$targetCloudName/image/upload');
    final request = http.MultipartRequest('POST', uri);

    if (signature != null) {
      // Signed upload mode: attach API key, timestamp, and HMAC signature
      request.fields['api_key'] = signature.apiKey;
      request.fields['timestamp'] = signature.timestamp.toString();
      request.fields['signature'] = signature.signature;
      request.fields['folder'] = signature.folder;
      request.fields['tags'] = signature.tags ?? 'basha_lagbe,property';
      if (signature.uploadPreset != null && signature.uploadPreset!.isNotEmpty) {
        request.fields['upload_preset'] = signature.uploadPreset!;
      } else {
        request.fields['upload_preset'] = defaultSignedUploadPreset;
      }
    } else {
      // Unsigned upload mode
      final effectiveFolder = folder;
      if (effectiveFolder != null && effectiveFolder.trim().isNotEmpty) {
        request.fields['folder'] = effectiveFolder.trim();
      }
      request.fields['tags'] = 'basha_lagbe,property';
      request.fields['upload_preset'] = uploadPreset;
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: effectiveFileName,
        contentType: contentType,
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
      return await _validateAndParseResponse(responseBody, targetCloudName);
    } else {
      String errorMessage = 'Upload failed with HTTP ${streamedResponse.statusCode}';
      try {
        final decoded = jsonDecode(responseBody);
        if (decoded is Map<String, dynamic> &&
            decoded.containsKey('error') &&
            decoded['error'] is Map) {
          final errorMap = decoded['error'] as Map;
          errorMessage = errorMap['message'] as String? ?? errorMessage;
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  /// Parses and strictly validates a Cloudinary HTTP 200 response payload.
  ///
  /// Enforces:
  /// - Valid JSON map object.
  /// - Non-empty `secure_url` with strictly valid HTTPS scheme on `res.cloudinary.com`
  ///   matching the [expectedCloudName].
  /// - Non-empty `public_id`.
  /// - `resource_type` (if present) must equal 'image'.
  /// - `format` (if present) must be one of 'jpg', 'jpeg', 'png', 'webp'.
  /// - If validation fails, automatically attempts cleanup via `deleteByToken` when
  ///   a valid delete token was returned.
  Future<CloudinaryUploadResult> _validateAndParseResponse(
    String responseBody,
    String expectedCloudName,
  ) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(responseBody);
    } catch (e) {
      throw CloudinaryResponseValidationException('Cloudinary returned malformed JSON: $e');
    }

    if (decoded is! Map<String, dynamic>) {
      throw CloudinaryResponseValidationException('Cloudinary response is not a valid JSON object.');
    }

    // Extract delete token early so cleanup can be attempted if subsequent checks fail
    final rawDeleteToken = decoded['delete_token'];
    final String? deleteToken = (rawDeleteToken is String && rawDeleteToken.trim().isNotEmpty)
        ? rawDeleteToken.trim()
        : null;

    Future<Never> failValidation(String reason) async {
      if (deleteToken != null) {
        try {
          await deleteByToken(deleteToken);
        } catch (_) {}
      }
      throw CloudinaryResponseValidationException(reason);
    }

    // 1. Validate secure_url
    final rawUrl = decoded['secure_url'];
    if (rawUrl is! String || rawUrl.trim().isEmpty) {
      await failValidation('Missing or empty secure_url in Cloudinary response.');
    }
    final secureUrl = rawUrl.trim();

    final uri = Uri.tryParse(secureUrl);
    if (uri == null ||
        !uri.hasScheme ||
        uri.scheme.toLowerCase() != 'https' ||
        !uri.hasAuthority ||
        uri.host.toLowerCase() != 'res.cloudinary.com' ||
        uri.pathSegments.isEmpty ||
        uri.pathSegments.first.toLowerCase() != expectedCloudName.toLowerCase()) {
      await failValidation(
        'Invalid or unverified delivery URL in Cloudinary response: must be HTTPS on res.cloudinary.com for cloud "$expectedCloudName".',
      );
    }

    // 2. Validate public_id
    final rawPublicId = decoded['public_id'];
    if (rawPublicId is! String || rawPublicId.trim().isEmpty) {
      await failValidation('Missing or empty public_id in Cloudinary response.');
    }
    final publicId = rawPublicId.trim();

    // 3. Validate resource_type (when present, must be 'image')
    final rawResourceType = decoded['resource_type'];
    String? resourceType;
    if (rawResourceType != null) {
      if (rawResourceType is! String) {
        await failValidation('Incorrect type for resource_type in Cloudinary response.');
      }
      resourceType = rawResourceType.toLowerCase().trim();
      if (resourceType != 'image') {
        await failValidation('Unexpected resource_type "$resourceType": only "image" is supported.');
      }
    }

    // 4. Validate format (when present, must be an allowed image format)
    final rawFormat = decoded['format'];
    String? format;
    if (rawFormat != null) {
      if (rawFormat is! String) {
        await failValidation('Incorrect type for format in Cloudinary response.');
      }
      format = rawFormat.toLowerCase().trim();
      const allowedFormats = {'jpg', 'jpeg', 'png', 'webp'};
      if (!allowedFormats.contains(format)) {
        await failValidation('Unsupported asset format "$format" returned by Cloudinary.');
      }
    }

    // 5. Optional metadata fields
    int? bytes;
    final rawBytes = decoded['bytes'];
    if (rawBytes is num) {
      bytes = rawBytes.toInt();
    }

    int? width;
    final rawWidth = decoded['width'];
    if (rawWidth is num) {
      width = rawWidth.toInt();
    }

    int? height;
    final rawHeight = decoded['height'];
    if (rawHeight is num) {
      height = rawHeight.toInt();
    }

    return CloudinaryUploadResult(
      secureUrl: secureUrl,
      publicId: publicId,
      deleteToken: deleteToken,
      format: format,
      resourceType: resourceType,
      bytes: bytes,
      width: width,
      height: height,
    );
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
          final validationError = validateImageBytes(item.bytes!);
          if (validationError != null) {
            throw ArgumentError(validationError);
          }
          final format = detectImageFormat(item.bytes!)!;
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = 'photo_${timestamp}_$i.${format.extension}';
          final folder = 'properties/$ownerId/$propertyId';

          final uploadResult = await uploadImage(
            bytes: item.bytes!,
            fileName: fileName,
            folder: folder,
            propertyId: propertyId,
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
