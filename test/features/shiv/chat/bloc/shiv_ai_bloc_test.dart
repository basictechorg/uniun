import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/enum/message_role.dart';
import 'package:uniun/domain/entities/shiv/shiv_conversation_entity.dart';
import 'package:uniun/domain/entities/shiv/shiv_message_entity.dart';
import 'package:uniun/domain/usecases/knowledge_usecases.dart';
import 'package:uniun/domain/usecases/llm_usecases.dart';
import 'package:uniun/domain/usecases/shiv_usecases.dart';
import 'package:uniun/features/shiv/chat/bloc/shiv_ai_bloc.dart';
import 'package:uniun/features/shiv/rag/pipeline/rag_pipeline.dart';

class _MGetConversations extends Mock implements GetConversationsUseCase {}

class _MWatchConversations extends Mock implements WatchConversationsUseCase {}

class _MCreateConversation extends Mock implements CreateConversationUseCase {}

class _MDeleteConversation extends Mock implements DeleteConversationUseCase {}

class _MGetMessages extends Mock implements GetMessagesUseCase {}

class _MSaveMessage extends Mock implements SaveMessageUseCase {}

class _MUpdateMessageContent extends Mock
    implements UpdateMessageContentUseCase {}

class _MUpdateConversationTitle extends Mock
    implements UpdateConversationTitleUseCase {}

class _MUpdateActiveLeaf extends Mock implements UpdateActiveLeafUseCase {}

class _MHasModel extends Mock implements HasActiveLlmModelUseCase {}

class _MOpenConv extends Mock implements OpenLlmConversationUseCase {}

class _MCloseConv extends Mock implements CloseLlmConversationUseCase {}

class _MSendChatStream extends Mock implements SendChatStreamUseCase {}

class _MPreempt extends Mock implements PreemptBackgroundWorkUseCase {}

class _MResume extends Mock implements ResumeBackgroundWorkUseCase {}

class _MRag extends Mock implements RagPipeline {}

class _MDrainPending extends Mock implements DrainPendingExtractionsUseCase {}

/// Covers: the `createConversation` event no longer persists a Isar row (a
/// draft lives only in bloc state) — a real row is only written by
/// `sendMessage` on the first turn. Regression coverage for issue #159
/// ("new chat is created even without a single message").
void main() {
  setUpAll(() {
    registerFallbackValue(ShivMessageEntity(
      messageId: 'fallback',
      conversationId: 'fallback',
      role: MessageRole.user,
      content: '',
      createdAt: DateTime(2026, 1, 1),
    ));
    registerFallbackValue(const SendChatStreamInput(message: ''));
    registerFallbackValue(('', ''));
  });

  late _MGetConversations getConversations;
  late _MWatchConversations watchConversations;
  late _MCreateConversation createConversation;
  late _MDeleteConversation deleteConversation;
  late _MGetMessages getMessages;
  late _MSaveMessage saveMessage;
  late _MUpdateMessageContent updateMessageContent;
  late _MUpdateConversationTitle updateConversationTitle;
  late _MUpdateActiveLeaf updateActiveLeaf;
  late _MHasModel hasModel;
  late _MOpenConv openConv;
  late _MCloseConv closeConv;
  late _MSendChatStream sendChatStream;
  late _MPreempt preempt;
  late _MResume resume;
  late _MRag rag;
  late _MDrainPending drainPending;

  ShivAIBloc build() => ShivAIBloc(
        getConversations,
        watchConversations,
        createConversation,
        deleteConversation,
        getMessages,
        saveMessage,
        updateMessageContent,
        updateConversationTitle,
        updateActiveLeaf,
        hasModel,
        openConv,
        closeConv,
        sendChatStream,
        preempt,
        resume,
        rag,
        drainPending,
      );

  final persistedConv = ShivConversationEntity(
    conversationId: 'persisted-1',
    title: 'first message text',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    getConversations = _MGetConversations();
    watchConversations = _MWatchConversations();
    createConversation = _MCreateConversation();
    deleteConversation = _MDeleteConversation();
    getMessages = _MGetMessages();
    saveMessage = _MSaveMessage();
    updateMessageContent = _MUpdateMessageContent();
    updateConversationTitle = _MUpdateConversationTitle();
    updateActiveLeaf = _MUpdateActiveLeaf();
    hasModel = _MHasModel();
    openConv = _MOpenConv();
    closeConv = _MCloseConv();
    sendChatStream = _MSendChatStream();
    preempt = _MPreempt();
    resume = _MResume();
    rag = _MRag();
    drainPending = _MDrainPending();

    when(() => watchConversations.call()).thenAnswer((_) => const Stream.empty());
    when(() => hasModel.call()).thenAnswer((_) async => true);
    when(() => openConv.call()).thenAnswer((_) async => const Right(unit));
    when(() => closeConv.call()).thenAnswer((_) async => const Right(unit));
    when(() => rag.buildSystemInstruction()).thenAnswer((_) async => 'sys');
    when(() => updateMessageContent.call(any()))
        .thenAnswer((_) async => const Right(unit));
    when(() => preempt.call()).thenAnswer((_) async => const Right(unit));
    when(() => resume.call()).thenAnswer((_) async => const Right(unit));
    when(() => drainPending.call()).thenAnswer((_) async {});
  });

  blocTest<ShivAIBloc, ShivAIState>(
    'createConversation only sets an in-memory draft — no persistence call, '
    'and the drawer list stays empty',
    build: build,
    act: (b) => b.add(const ShivAIEvent.createConversation()),
    verify: (b) {
      expect(b.state.activeConversation, isNotNull);
      expect(b.state.activeConversation!.title, 'New conversation');
      expect(b.state.conversations, isEmpty);
      verifyNever(() => createConversation.call(any()));
    },
  );

  blocTest<ShivAIBloc, ShivAIState>(
    'createConversation guarded by no active model — no draft, no crash',
    build: build,
    setUp: () => when(() => hasModel.call()).thenAnswer((_) async => false),
    act: (b) => b.add(const ShivAIEvent.createConversation()),
    verify: (b) {
      expect(b.state.activeConversation, isNull);
      verifyNever(() => createConversation.call(any()));
    },
  );

  group('sendMessage on a draft conversation persists it lazily', () {
    setUp(() {
      when(() => createConversation.call(any()))
          .thenAnswer((_) async => Right(persistedConv));
      when(() => saveMessage.call(any()))
          .thenAnswer((i) async => Right(i.positionalArguments.first));
      when(() => rag.buildMessage(
            userQuestion: any(named: 'userQuestion'),
            manasIds: any(named: 'manasIds'),
          )).thenAnswer((_) async => const RagMessage(
            userMessage: 'q',
            contextCount: 0,
          ));
      when(() => sendChatStream.call(any()))
          .thenAnswer((_) => const Stream.empty());
    });

    blocTest<ShivAIBloc, ShivAIState>(
      'first send on a draft calls CreateConversationUseCase with the '
      'message-derived title and adds it to the conversation list exactly once',
      build: build,
      act: (b) async {
        b.add(const ShivAIEvent.createConversation());
        await Future<void>.delayed(Duration.zero);
        b.add(const ShivAIEvent.sendMessage('first message text'));
      },
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        verify(() => createConversation.call('first message text')).called(1);
        expect(b.state.activeConversation?.conversationId, 'persisted-1');
        expect(
          b.state.conversations.where((c) => c.conversationId == 'persisted-1'),
          hasLength(1),
        );
      },
    );

    blocTest<ShivAIBloc, ShivAIState>(
      'sending a second message on an already-persisted conversation does '
      'NOT call CreateConversationUseCase again',
      build: build,
      act: (b) async {
        b.add(const ShivAIEvent.createConversation());
        await Future<void>.delayed(Duration.zero);
        b.add(const ShivAIEvent.sendMessage('first message text'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        b.add(const ShivAIEvent.sendMessage('second message'));
      },
      wait: const Duration(milliseconds: 40),
      verify: (b) {
        verify(() => createConversation.call(any())).called(1);
        verifyNever(() => updateConversationTitle.call(any()));
      },
    );

    // ── Edge cases ──────────────────────────────────────────────────────

    blocTest<ShivAIBloc, ShivAIState>(
      'whitespace-only first message is a no-op — draft is never persisted',
      build: build,
      act: (b) async {
        b.add(const ShivAIEvent.createConversation());
        await Future<void>.delayed(Duration.zero);
        b.add(const ShivAIEvent.sendMessage('   \t\n  '));
      },
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        verifyNever(() => createConversation.call(any()));
        expect(b.state.conversations, isEmpty);
      },
    );

    blocTest<ShivAIBloc, ShivAIState>(
      'sendMessage with no active conversation at all is a no-op',
      build: build,
      act: (b) => b.add(const ShivAIEvent.sendMessage('hello')),
      verify: (b) {
        verifyNever(() => createConversation.call(any()));
        expect(b.state.activeConversation, isNull);
      },
    );

    blocTest<ShivAIBloc, ShivAIState>(
      'persistence failure on first send surfaces an error and does not '
      'save any message',
      build: build,
      setUp: () => when(() => createConversation.call(any())).thenAnswer(
          (_) async => const Left(Failure.errorFailure('db error'))),
      act: (b) async {
        b.add(const ShivAIEvent.createConversation());
        await Future<void>.delayed(Duration.zero);
        b.add(const ShivAIEvent.sendMessage('hello'));
      },
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(b.state.status, ShivChatStatus.error);
        verifyNever(() => saveMessage.call(any()));
      },
    );

    blocTest<ShivAIBloc, ShivAIState>(
      'createConversationSeeded creates the draft then persists it via the '
      'same lazy path as a normal first send',
      build: build,
      act: (b) => b.add(const ShivAIEvent.createConversationSeeded('seed text')),
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        verify(() => createConversation.call('seed text')).called(1);
        expect(b.state.activeConversation?.conversationId, 'persisted-1');
      },
    );
  });

  group('mid-stream interruption never leaves a permanently blank bubble', () {
    late StreamController<String> tokenController;

    setUp(() {
      tokenController = StreamController<String>();
      when(() => createConversation.call(any()))
          .thenAnswer((_) async => Right(persistedConv));
      when(() => saveMessage.call(any()))
          .thenAnswer((i) async => Right(i.positionalArguments.first));
      when(() => rag.buildMessage(
            userQuestion: any(named: 'userQuestion'),
            manasIds: any(named: 'manasIds'),
          )).thenAnswer((_) async => const RagMessage(
            userMessage: 'q',
            contextCount: 0,
          ));
      when(() => sendChatStream.call(any()))
          .thenAnswer((_) => tokenController.stream);
    });

    // Not `await tokenController.close()`: a single-subscription controller
    // that was never listened to (the "idle, no sendMessage" test below)
    // has a `.close()` future that never completes without a subscriber —
    // fire-and-forget avoids hanging tearDown.
    tearDown(() {
      unawaited(tokenController.close());
    });

    blocTest<ShivAIBloc, ShivAIState>(
      'tapping Stop mid-stream persists the partial tokens generated so far',
      build: build,
      act: (b) async {
        b.add(const ShivAIEvent.createConversation());
        await Future<void>.delayed(Duration.zero);
        b.add(const ShivAIEvent.sendMessage('question'));
        await Future<void>.delayed(Duration.zero);
        tokenController.add('partial answer');
        await Future<void>.delayed(const Duration(milliseconds: 60));
        b.add(const ShivAIEvent.stopStreaming());
      },
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(b.state.status, ShivChatStatus.chatIdle);
        expect(b.state.streamingContent, isNull);
        final captured =
            verify(() => updateMessageContent.call(captureAny())).captured;
        final lastCall = captured.last as (String, String);
        expect(lastCall.$2, 'partial answer');
      },
    );

    blocTest<ShivAIBloc, ShivAIState>(
      'tapping Stop before any token has arrived persists the "(stopped)" '
      'fallback, not an empty string',
      build: build,
      act: (b) async {
        b.add(const ShivAIEvent.createConversation());
        await Future<void>.delayed(Duration.zero);
        b.add(const ShivAIEvent.sendMessage('question'));
        await Future<void>.delayed(Duration.zero);
        b.add(const ShivAIEvent.stopStreaming());
      },
      verify: (b) {
        final captured =
            verify(() => updateMessageContent.call(captureAny())).captured;
        final lastCall = captured.last as (String, String);
        expect(lastCall.$2, '(stopped)');
      },
    );

    blocTest<ShivAIBloc, ShivAIState>(
      'closing the conversation mid-stream — the real issue #159 follow-on — '
      'persists the "(interrupted)" fallback instead of leaving the '
      'assistant placeholder blank forever',
      build: build,
      act: (b) async {
        b.add(const ShivAIEvent.createConversation());
        await Future<void>.delayed(Duration.zero);
        b.add(const ShivAIEvent.sendMessage('question'));
        await Future<void>.delayed(Duration.zero);
        b.add(const ShivAIEvent.closeConversation());
      },
      verify: (b) {
        expect(b.state.activeConversation, isNull);
        final captured =
            verify(() => updateMessageContent.call(captureAny())).captured;
        final lastCall = captured.last as (String, String);
        expect(lastCall.$2, '(interrupted)');
      },
    );

    blocTest<ShivAIBloc, ShivAIState>(
      'closing the conversation mid-stream AFTER some tokens arrived '
      'persists those tokens, not the fallback',
      build: build,
      act: (b) async {
        b.add(const ShivAIEvent.createConversation());
        await Future<void>.delayed(Duration.zero);
        b.add(const ShivAIEvent.sendMessage('question'));
        await Future<void>.delayed(Duration.zero);
        tokenController.add('half ');
        await Future<void>.delayed(const Duration(milliseconds: 60));
        b.add(const ShivAIEvent.closeConversation());
      },
      verify: (b) {
        final captured =
            verify(() => updateMessageContent.call(captureAny())).captured;
        final lastCall = captured.last as (String, String);
        expect(lastCall.$2, 'half');
      },
    );

    blocTest<ShivAIBloc, ShivAIState>(
      'closing an idle (non-streaming) conversation never calls '
      'updateMessageContent at all',
      build: build,
      act: (b) async {
        b.add(const ShivAIEvent.createConversation());
        await Future<void>.delayed(Duration.zero);
        b.add(const ShivAIEvent.closeConversation());
      },
      verify: (b) {
        verifyNever(() => updateMessageContent.call(any()));
      },
    );

    blocTest<ShivAIBloc, ShivAIState>(
      'a stream error surfaces as state.status == error with the error '
      'text, and persists that same error text into the assistant bubble '
      '(never a silent blank)',
      build: build,
      act: (b) async {
        b.add(const ShivAIEvent.createConversation());
        await Future<void>.delayed(Duration.zero);
        b.add(const ShivAIEvent.sendMessage('question'));
        await Future<void>.delayed(Duration.zero);
        tokenController.addError(Exception('model crashed'));
      },
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(b.state.status, ShivChatStatus.error);
        expect(b.state.errorMessage, contains('model crashed'));
        final captured =
            verify(() => updateMessageContent.call(captureAny())).captured;
        final lastCall = captured.last as (String, String);
        expect(lastCall.$2, contains('model crashed'));
      },
    );
  });
}
