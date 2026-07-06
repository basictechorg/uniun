import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/core/utils/llm_text_sanitizer.dart';

void main() {
  test('strips tool-call envelope', () {
    final out = LlmTextSanitizer.clean('publish_message(body="hello world")');
    expect(out, 'hello world');
  });

  test('decodes GPT-2 byte-encoded emoji 🌱', () {
    // ð=0xF0 Ł=U+0141 Į=U+012E ±=0xB1 — the encoding for 🌱 (UTF-8 F0 9F 8C B1)
    final input = 'lesson ${String.fromCharCodes([0x00F0, 0x0141, 0x012E, 0x00B1])}';
    final out = LlmTextSanitizer.clean(input);
    expect(out, contains('🌱'));
  });

  test('combined: envelope + emoji', () {
    final body = 'A life lesson: keep growing. ${String.fromCharCodes([0x00F0, 0x0141, 0x012E, 0x00B1])}';
    final out = LlmTextSanitizer.clean('publish_message(body="$body")');
    expect(out, 'A life lesson: keep growing. 🌱');
  });

  test('leaves clean text unchanged', () {
    expect(LlmTextSanitizer.clean('hello world'), 'hello world');
    expect(LlmTextSanitizer.clean('Hola, ¿cómo estás?'), 'Hola, ¿cómo estás?');
  });

  test('strips balanced <think>...</think> blocks', () {
    final out = LlmTextSanitizer.clean(
        '<think>Let me think about this...</think>The answer is 42.');
    expect(out, 'The answer is 42.');
  });

  test('returns empty when truncated mid-think', () {
    final out = LlmTextSanitizer.clean(
        '<think> Okay, the user wants a good motivation life lesson. Let me think abou');
    expect(out, '');
  });

  test('strips multiple think blocks', () {
    final out = LlmTextSanitizer.clean(
        '<think>step 1</think>Hi <think>step 2</think>there.');
    expect(out, contains('Hi'));
    expect(out, contains('there.'));
    expect(out, isNot(contains('<think>')));
  });
}
