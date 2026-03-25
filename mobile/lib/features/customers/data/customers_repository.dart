import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

final customersRepositoryProvider = Provider<CustomersRepository>((ref) {
  return CustomersRepository(ref.read(dioProvider));
});

class CustomerModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? documentType;
  final String? documentNumber;
  final String? address;
  final String? notes;
  final DateTime createdAt;

  const CustomerModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.documentType,
    this.documentNumber,
    this.address,
    this.notes,
    required this.createdAt,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        documentType: json['documentType'] as String?,
        documentNumber: json['documentNumber'] as String?,
        address: json['address'] as String?,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class CustomersRepository {
  final Dio _dio;

  CustomersRepository(this._dio);

  Future<List<CustomerModel>> getCustomers(
    String teamId, {
    String? search,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (search != null && search.isNotEmpty) params['search'] = search;

      final response = await _dio.get(
        '/teams/$teamId/customers',
        queryParameters: params,
      );
      return (response.data as List)
          .map((e) => CustomerModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<CustomerModel> createCustomer(
    String teamId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post('/teams/$teamId/customers', data: data);
      return CustomerModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<CustomerModel> updateCustomer(
    String teamId,
    String customerId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.patch(
        '/teams/$teamId/customers/$customerId',
        data: data,
      );
      return CustomerModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
