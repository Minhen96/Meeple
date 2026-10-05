import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/network/connectivity_service.dart';
import 'package:meeple_hearth/core/network/upload_repository.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/library/data/collection_repository.dart';
import 'package:meeple_hearth/features/library/domain/user_game_model.dart';
import 'package:meeple_hearth/features/profile/data/user_repository.dart';
import 'package:meeple_hearth/features/social/domain/social_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_provider.g.dart';

/// Another user's profile (404 when blocked either way).
@riverpod
Future<User> userProfile(Ref ref, String userId) =>
    ref.read(userRepositoryProvider).getUser(userId);

@riverpod
Future<UserStats> userStats(Ref ref, String userId) =>
    ref.read(userRepositoryProvider).getStats(userId);

/// A user's owned games (profile Collection tab).
@riverpod
Future<List<UserGame>> userCollection(Ref ref, String userId) =>
    ref.read(collectionRepositoryProvider).getUserCollection(userId);

/// A user's favourites (profile "Favorite Games" row).
@riverpod
Future<List<UserGame>> userFavorites(Ref ref, String userId) => ref
    .read(collectionRepositoryProvider)
    .getUserCollection(userId, filter: CollectionFilter.favorited);

/// Editing the signed-in user's profile.
@riverpod
ProfileActions profileActions(Ref ref) => ProfileActions(ref);

final class ProfileActions {
  ProfileActions(this._ref);

  final Ref _ref;

  Future<User> update(ProfileUpdate update) async {
    ensureOnline(_ref);
    final user = await _ref.read(userRepositoryProvider).updateMe(update);
    _ref.read(authNotifierProvider.notifier).updateUser(user);
    return user;
  }

  /// Uploads a (cropped, compressed) avatar and saves its URL.
  Future<User> updateAvatar(File file) async {
    ensureOnline(_ref);
    final uploaded = await _ref.read(uploadRepositoryProvider).uploadImage(file);
    return update(ProfileUpdate(avatarUrl: uploaded.publicUrl));
  }
}
