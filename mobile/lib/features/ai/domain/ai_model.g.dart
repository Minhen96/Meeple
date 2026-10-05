// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ConversationTurnImpl _$$ConversationTurnImplFromJson(
        Map<String, dynamic> json) =>
    _$ConversationTurnImpl(
      question: json['question'] as String,
      answer: json['answer'] as String,
    );

Map<String, dynamic> _$$ConversationTurnImplToJson(
        _$ConversationTurnImpl instance) =>
    <String, dynamic>{
      'question': instance.question,
      'answer': instance.answer,
    };

_$AiAnswerImpl _$$AiAnswerImplFromJson(Map<String, dynamic> json) =>
    _$AiAnswerImpl(
      answer: json['answer'] as String,
      sourceMode: json['sourceMode'] as String?,
      disclaimer: json['disclaimer'] as String?,
      cached: json['cached'] as bool? ?? false,
    );

Map<String, dynamic> _$$AiAnswerImplToJson(_$AiAnswerImpl instance) =>
    <String, dynamic>{
      'answer': instance.answer,
      'sourceMode': instance.sourceMode,
      'disclaimer': instance.disclaimer,
      'cached': instance.cached,
    };
