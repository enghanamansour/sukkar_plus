import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sukkar_core/sukkar_core.dart';

/// Thrown when an optional backend service cannot be used. [code] is stable;
/// [messageAr] is shown to the user.
class ServiceUnavailable implements Exception {
  ServiceUnavailable(this.code, this.messageAr);
  final String code;
  final String messageAr;
  @override
  String toString() => 'ServiceUnavailable($code)';
}

String _messageForCode(String code) => switch (code) {
      'ai_not_configured' => 'خدمة الذكاء الاصطناعي غير مُعدّة على الخادم. استُخدمت القراءة المحلية فقط.',
      'consent_required' => 'يلزم موافقتك على المعالجة الخارجية قبل إرسال الملف للذكاء الاصطناعي.',
      'ai_unavailable' => 'خدمة الذكاء الاصطناعي غير متاحة حاليًا. استُخدمت القراءة المحلية فقط.',
      'forbidden' => 'لا تملك صلاحية تنفيذ هذا الإجراء.',
      'invalid_transition' => 'حالة الطلب تغيّرت؛ حدّث الصفحة وحاول مجددًا.',
      _ => 'تعذّر الاتصال بالخادم.',
    };

ServiceUnavailable _fromFunctionException(FunctionException e) {
  final details = e.details;
  final code = details is Map && details['error'] is String ? details['error'] as String : 'http_${e.status}';
  return ServiceUnavailable(code, _messageForCode(code));
}

// --------------------------------------------------------------- extraction

abstract class AiExtractionClient {
  bool get isAvailable;
  String get label;
  Future<AiExtraction> extract(Uint8List pdfBytes);
}

class NoAiExtraction implements AiExtractionClient {
  const NoAiExtraction();
  @override
  bool get isAvailable => false;
  @override
  String get label => 'غير مفعّل (وضع العرض أو دون إعداد)';
  @override
  Future<AiExtraction> extract(Uint8List pdfBytes) =>
      Future.error(ServiceUnavailable('ai_not_configured', _messageForCode('ai_not_configured')));
}

/// Calls the `extract-report` Edge Function. The function holds the Gemini
/// key; the app re-validates the response with [AiExtractionValidator].
class EdgeAiExtraction implements AiExtractionClient {
  EdgeAiExtraction(this.client);
  final SupabaseClient client;

  @override
  bool get isAvailable => true;
  @override
  String get label => 'Gemini عبر الخادم (Edge Function)';

  @override
  Future<AiExtraction> extract(Uint8List pdfBytes) async {
    try {
      final res = await client.functions.invoke('extract-report', body: {'pdf_base64': base64Encode(pdfBytes)});
      return const AiExtractionValidator().validate(res.data);
    } on FunctionException catch (e) {
      throw _fromFunctionException(e);
    } catch (_) {
      throw ServiceUnavailable('network', _messageForCode('network'));
    }
  }
}

// ------------------------------------------------------------- explanation

/// Calls the `explain` Edge Function; wrapped by [GuardedExplainer], which
/// re-checks the text and falls back to the local template.
class EdgeExplanationProvider implements ExplanationProvider {
  EdgeExplanationProvider(this.client);
  final SupabaseClient client;

  @override
  String get name => 'gemini-edge';
  @override
  bool get isLive => true;

  @override
  Future<Explanation> explain(ExplanationContext ctx) async {
    try {
      final res = await client.functions.invoke('explain', body: {'context': ctx.toJson()});
      final data = res.data;
      if (data is Map && data['text'] is String) {
        return Explanation(text: data['text'] as String, source: ExplanationSource.ai);
      }
      throw ServiceUnavailable('ai_unavailable', _messageForCode('ai_unavailable'));
    } on FunctionException catch (e) {
      throw _fromFunctionException(e);
    }
  }
}

// ---------------------------------------------------------------- dispatch

class DispatchOutcome {
  const DispatchOutcome(this.dispatch, {this.newStatus});
  final IntegrationDispatch dispatch;
  final FollowUpStatus? newStatus;
}

/// Submits a follow-up request and notifies automation.
abstract class FollowUpDispatcher {
  String get label;
  bool get isMock;

  /// Demo: the caller already applied the transition locally; only notify.
  /// Live: the Edge Function performs the submit RPC and the notification.
  Future<DispatchOutcome> submit(FollowUpRequest request, {String? noteAr});
  Future<DispatchOutcome> retry(FollowUpRequest request);
}

class MockDispatcher implements FollowUpDispatcher {
  MockDispatcher(this.notifier);
  final MockFollowUpNotifier notifier;

  @override
  String get label => 'محاكي محلي (Mock) — لا يُرسل أي شيء خارج الجهاز';
  @override
  bool get isMock => true;

  int _submissionNumber(FollowUpRequest r) => r.history.where((h) => h.to == FollowUpStatus.awaitingReview).length;

  Future<DispatchOutcome> _send(FollowUpRequest r) async {
    final payload = buildFollowUpEventPayload(r, demo: true);
    final key = '${r.id}:followup.submitted:${_submissionNumber(r)}';
    final res = await notifier.notify(payload, idempotencyKey: key);
    return DispatchOutcome(IntegrationDispatch(
      state: res.state,
      adapterName: res.adapterName,
      isMock: true,
      attempts: r.dispatch.attempts + (res.duplicate ? 0 : 1),
      lastError: res.errorAr,
      lastAttemptAt: DateTime.now(),
    ));
  }

  @override
  Future<DispatchOutcome> submit(FollowUpRequest request, {String? noteAr}) => _send(request);
  @override
  Future<DispatchOutcome> retry(FollowUpRequest request) => _send(request);
}

class EdgeDispatcher implements FollowUpDispatcher {
  EdgeDispatcher(this.client);
  final SupabaseClient client;

  @override
  String get label => 'الخادم ← Make.com (أو محاكي الخادم إن لم يُعدّ Make)';
  @override
  bool get isMock => false;

  Future<DispatchOutcome> _call(FollowUpRequest r, String action, String? note) async {
    try {
      final res = await client.functions.invoke('followup-dispatch', body: {'request_id': r.id, 'action': action, 'note': note});
      final data = res.data as Map;
      final d = data['dispatch'] as Map;
      final state = switch (d['state']) {
        'sent' => DispatchState.sent,
        'mock_recorded' => DispatchState.mockRecorded,
        'failed' => DispatchState.failed,
        _ => DispatchState.notSent,
      };
      return DispatchOutcome(
        IntegrationDispatch(
          state: state,
          adapterName: d['adapter'] == 'make_webhook' ? 'make-webhook' : 'server-mock',
          isMock: d['adapter'] != 'make_webhook',
          attempts: (d['attempts'] as num?)?.toInt() ?? 0,
          lastError: d['error'] as String?,
          lastAttemptAt: DateTime.now(),
        ),
        newStatus: followUpStatusFromWire('${data['status']}'),
      );
    } on FunctionException catch (e) {
      throw _fromFunctionException(e);
    }
  }

  @override
  Future<DispatchOutcome> submit(FollowUpRequest request, {String? noteAr}) => _call(request, 'submit', noteAr);
  @override
  Future<DispatchOutcome> retry(FollowUpRequest request) => _call(request, 'retry', null);
}
