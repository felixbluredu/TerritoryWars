import 'package:flutter_test/flutter_test.dart';
import 'package:territory_wars/utils/nickname_validator.dart';

void main() {
  group('NicknameValidator', () {
    test('accepts normal nicknames', () {
      expect(NicknameValidator.validate('CoolPlayer'), isNull);
      expect(NicknameValidator.validate('walker_42'), isNull);
      expect(NicknameValidator.validate('Mia-99'), isNull);
    });

    test('rejects empty / too short / too long', () {
      expect(NicknameValidator.validate(''), isNotNull);
      expect(NicknameValidator.validate('   '), isNotNull);
      expect(NicknameValidator.validate('ab'), isNotNull);
      expect(NicknameValidator.validate('a' * 17), isNotNull);
    });

    test('rejects invalid characters', () {
      expect(NicknameValidator.validate('bad/name'), isNotNull);
      expect(NicknameValidator.validate('emoji😀'), isNotNull);
    });

    test('rejects direct profanity', () {
      expect(NicknameValidator.validate('fuck'), isNotNull);
      expect(NicknameValidator.validate('SomeBitch'), isNotNull);
    });

    test('rejects leetspeak workarounds', () {
      expect(NicknameValidator.validate('sh1t'), isNotNull);
      expect(NicknameValidator.validate('n1gger'), isNotNull);
      expect(NicknameValidator.validate('fu(k'), isNotNull);
    });

    test('rejects spacing / punctuation workarounds', () {
      expect(NicknameValidator.validate('f u c k'), isNotNull);
      expect(NicknameValidator.validate('f_u_c_k'), isNotNull);
    });

    test('rejects repeated-letter workarounds', () {
      expect(NicknameValidator.validate('shiiit'), isNotNull);
      expect(NicknameValidator.validate('fuuuck'), isNotNull);
    });

    test('rejects anatomical / sexual terms', () {
      expect(NicknameValidator.validate('penis'), isNotNull);
      expect(NicknameValidator.validate('BigPenis'), isNotNull);
      expect(NicknameValidator.validate('p3n1s'), isNotNull);
      expect(NicknameValidator.validate('vagina'), isNotNull);
      expect(NicknameValidator.validate('boobs'), isNotNull);
    });

    test('does not flag innocent words', () {
      expect(NicknameValidator.validate('assassin'), isNull);
      expect(NicknameValidator.validate('classic'), isNull);
      expect(NicknameValidator.validate('grasshopper'), isNull);
      expect(NicknameValidator.validate('document'), isNull);
      expect(NicknameValidator.validate('analysis'), isNull);
    });
  });
}
