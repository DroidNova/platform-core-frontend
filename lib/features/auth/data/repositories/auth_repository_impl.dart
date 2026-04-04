import 'package:platform_core_frontend/core/errors/app_exception.dart';
import 'package:platform_core_frontend/core/network/api_result.dart';
import 'package:platform_core_frontend/core/storage/token_storage.dart';
import 'package:platform_core_frontend/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:platform_core_frontend/features/auth/data/models/auth_tokens_model.dart';
import 'package:platform_core_frontend/features/auth/domain/entities/auth_tokens.dart';
import 'package:platform_core_frontend/features/auth/domain/entities/current_user.dart';
import 'package:platform_core_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:platform_core_frontend/features/session/data/models/app_session_model.dart';
import 'package:platform_core_frontend/features/session/domain/entities/app_session.dart';
import 'package:platform_core_frontend/shared/types/json_types.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required TokenStorage tokenStorage,
  })  : _remoteDataSource = remoteDataSource,
        _tokenStorage = tokenStorage;

  final AuthRemoteDataSource _remoteDataSource;
  final TokenStorage _tokenStorage;

  @override
  Future<ApiResult<AppSession>> register({required JsonMap payload}) async {
    final result = await _remoteDataSource.register(payload: payload);
    return _persistSession(result);
  }

  @override
  Future<ApiResult<AppSession>> login({required JsonMap payload}) async {
    final result = await _remoteDataSource.login(payload: payload);
    return _persistSession(result);
  }

  @override
  Future<ApiResult<AuthTokens>> refreshToken({String? refreshToken}) async {
    final token = refreshToken ?? await _tokenStorage.getRefreshToken();
    if (token == null || token.isEmpty) {
      return const ApiFailure<AuthTokens>(
        UnknownException('Missing refresh token'),
      );
    }

    final result = await _remoteDataSource.refreshToken(refreshToken: token);
    return _persistTokens(result);
  }

  @override
  Future<ApiResult<void>> logout() async {
    final result = await _remoteDataSource.logout();
    await _tokenStorage.clearTokens();
    return result;
  }

  @override
  Future<ApiResult<CurrentUser>> getCurrentUser() async {
    final result = await _remoteDataSource.getCurrentUser();
    return result.mapData((model) => model.toEntity());
  }

  Future<ApiResult<AuthTokens>> _persistTokens(
    ApiResult<AuthTokensModel> result,
  ) async {
    final entityResult = result.mapData((model) => model.toEntity());

    switch (entityResult) {
      case ApiSuccess<AuthTokens>(:final data):
        await _tokenStorage.saveAccessToken(data.accessToken);
        await _tokenStorage.saveRefreshToken(data.refreshToken);
        return ApiSuccess<AuthTokens>(data);
      case ApiFailure<AuthTokens>(:final exception):
        return ApiFailure<AuthTokens>(exception);
    }
  }

  Future<ApiResult<AppSession>> _persistSession(
    ApiResult<AppSessionModel> result,
  ) async {
    final entityResult = result.mapData((model) => model);

    switch (entityResult) {
      case ApiSuccess<AppSession>(:final data):
        final tokens = data.tokens;
        if (tokens == null) {
          return const ApiFailure<AppSession>(
            UnknownException('Authentication tokens missing from response'),
          );
        }
        await _tokenStorage.saveAccessToken(tokens.accessToken);
        await _tokenStorage.saveRefreshToken(tokens.refreshToken);
        return ApiSuccess<AppSession>(data);
      case ApiFailure<AppSession>(:final exception):
        return ApiFailure<AppSession>(exception);
    }
  }
}
