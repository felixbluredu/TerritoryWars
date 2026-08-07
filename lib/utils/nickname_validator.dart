import 'dart:convert';

import 'package:crypto/crypto.dart';

// Nickname rules: length + allowed characters, plus a blocklist that also
// catches the usual workarounds: digit-for-letter swaps, padding the word out
// with punctuation or spaces, and repeating letters.
//
// The blocked words are stored as SHA-256 hashes rather than plain text, so
// the list isn't sitting in the repo in readable form. Matching works by
// hashing every substring of the nickname and looking it up, which is why the
// word lengths are recorded below - it keeps the scan to a sensible range.
//
// Short/mild words are left out on purpose, otherwise names like "assassin"
// or "classic" get blocked too.
class NicknameValidator {
  static const int minLength = 3;
  static const int maxLength = 16;

  static const String _rejectedMessage =
      "That nickname isn't allowed. Please choose another.";

  // Shortest and longest entry in the blocklist.
  static const int _minBannedLength = 3;
  static const int _maxBannedLength = 10;

  static const Set<String> _bannedHashes = {
    '0508a634445d401652d06013cdcc95183ab78c58e406cfec6dc58a395958ef2b',
    '08a841e996781e9e77d30a4e4420a8f501a280b00624e6d1224bf54aaff73eba',
    '0a3ab406419b5c697b9707ba440a634cf4f05ca4696ebac4c1be10cf0b475730',
    '0f28c4960d96647e77e7ab6d13b85bd16c7ca56f45df802cdc763a5e5c0c7863',
    '120f6e5b4ea32f65bda68452fcfaaef06b0136e1d0e4a6f60bc3771fa0936dd6',
    '13a465fc6616da8d2afacaf00a8276aa841662820f9337de127f815ee71cc55d',
    '158869a97379229b7681efae9d7f9c9214134e836d649ba53477c0c111414d59',
    '16ea09fc78ca83ca502cbcf2377acdf280bf18f61e259153f0868405eedab5ef',
    '1d0864b81a8a857bdbcb3f1e4f7fb6ac710d528a07855463f08b7fe226899846',
    '27099f42b6c43d031f0cd833cb903cd665e0ef91da13de0f15f41dfc29af8218',
    '2a6937d721b14cdd7331c1ad1caf6a3cfa37a266650807101d44cdcd0acb132f',
    '2b3240970c71346b98e00c5c83e8070484e9a1ac3d04d4488dedc85f454e6180',
    '2c32c156cf1a3222050eef93084b4790d961fb6b054990ff85b3f7af4ae147ec',
    '4dc9418555a26aa694ef4c4b4d02137070a537d7786d4b337245a54304e7824e',
    '566f532d486c947709d3d0e6b7575af8380248db66dada211d58eb00ad585297',
    '59cc3cb8a42973019cddacdee59e0aa7746ba6c203af78cefb453cb3a1b6610d',
    '6556c1a58444e10f074e59b510fc392d61dd39d04227671272a61617dcecc094',
    '665cb762e3bc03d078dea6bd624f49ac355ed3389d977f6e320792111961421d',
    '6ac3c336e4094835293a3fed8a4b5fedde1b5e2626d9838fed50693bba00af0e',
    '701d6943ae042badbeb77d1951d502dd589f91601662a73319edaf04adf2572b',
    '796e43a5a8cdb73b92b5f59eb50610cea3efa8ce229cd7f0557983091b2b4552',
    '82e695c9e75f5bc67deea8c67acb1c7bce3f633d533f9785804b500206348b89',
    '83621b34ec5955e56c07c5b2ed2c87ed8050c3884cd89a1527d06579711e8906',
    '83ebccea9fff4079ead732d05b9a762edbcda1cf3eab78bc7f3512abed918ab0',
    '85fc17f7069acd39a5c636cd0a6530651096128da447959f5e250824857dc559',
    '886d51e97ad7931d0d2af8439ca6d9e4887e3c2b469ed247cbd68ceb3649ccde',
    '89133bc00e9b3eb8698d9b7660f45f0eb060a8d7272db6c99af712699bfcc71f',
    '8c5c04391361cbf4afd74c5ed8101ea4af881c4ee3b3df1d5b3716a19b1a834d',
    '8f5083e3e5c7dc8932f2bf58212f963f3a44752618c96297f82623f736c52738',
    '98b52c4b6b7d1f48e7477a5ccc10955dd195d0ac5a38c8281bfeb08762634909',
    '9ae315a94e428a7ee3b5e48adae6541965d93b86acf10ffa1c45b93b6fe577b4',
    'a6ee0e6b8b6a6ba1287f6d14dd0e97b37db9e1c1be07072c344957af0fa07506',
    'a76d588d0047e3b043406060ba6170e2313f46f15a084d680464f881f1efeeb9',
    'ab26f6966ee37fdf3b66775bf6d4f5541ae62ba85301ca534723a68cc7bfeba6',
    'ad505b0be8a49b89273e307106fa42133cbd804456724c5e7635bd953215d92a',
    'b04a8a40063584477f690200cb4262563f36068984ab4f53a51f26bf8e120215',
    'b14c8b304b800280e9bf8600c2d74535dca0ce7887c90f7ecbba8240d5c95a28',
    'be72176c19a9480415d377147654bc1a641005f8479ae210f56f3e1d13b76ff0',
    'c2c3b68b48832afd9a4dbdd474c1b6c81c8baecdb71446f9947dac72dd0fe93d',
    'c3de533e9b7fe63b79f648687a30d2861edd92fe7c3cd1f2c485e0a605367624',
    'cd2eb0837c9b4c962c22d2ff8b5441b7b45805887f051d39bf133b583baf6860',
    'd0a32ecf89f3c0ce7965aa5cc7d9790b34789bd87da255d4cbef49e0bc58c1b5',
    'd2ce238bf4709ddee431fd65689be30c87ae0a0900929f7b3d4f46e67cabca48',
    'd75a838dc758ba17f28bd8dbac605cb70c35465263d5733164521de2f7ef7926',
    'dcb50ee3659fb74208645f29da8bf4c11f799cec04d259eeaace642d960e83db',
    'dd92623b0a4b255f87cc4aaee7990ee182d91db49189df6229ce65b5e9d960da',
    'dfb0ce07edf923f1f40ba56cc9ba9c396b53e3399e3164d60e35050baa2be9c9',
    'e273db21d19ee957f90c3615c7ac673fdcf27755f1a0a3ea14d1324eaa6f1160',
    'e512a05583448f44790783f986b1f36925c8cfc42338ca0e1caa637755bd15ae',
    'e7b98c6aa5b944e0b315d350d423f895ac9e44fb84f1534b18c2572370a67b9e',
    'e99d55248f67be7623332be8dabcd143ce2495eb923860b4ed0d963621ece901',
    'eef3bd091670c3447022d619c06ad15de96da72b5a66f28bb8b75d1b1c12a05f',
    'eff26b18165ece9cd15978f5a124cd19afc08bfc76b4fda4ed11a35a66217051',
    'f50c51ed2315dcf3fa88181cf033f8029cac64f7dea4048327ca032ec102ea74',
    'f6952d6eef555ddd87aca66e56b91530222d6e318414816f3ba7cf5bf694bf0f',
    'f9d0d9b18ae9033a5ea36df19bf279b059e887a9ae785db81117bceaecc95933',
    'fd70ad909b94deb27b460692084d9f2b1dbc9df3c6bcfd3caee571e707031e3f',
  };

  // Leet/symbol swaps applied before matching.
  static const Map<String, String> _substitutions = {
    '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't', '8': 'b',
    '9': 'g', '@': 'a', '\$': 's', '!': 'i', '|': 'i', '(': 'c', '+': 't',
  };

  // Returns an error message, or null if the nickname is ok.
  static String? validate(String raw) {
    final trimmed = raw.trim();

    if (trimmed.isEmpty) {
      return 'Please enter a nickname.';
    }
    if (trimmed.length < minLength) {
      return 'Nickname must be at least $minLength characters.';
    }
    if (trimmed.length > maxLength) {
      return 'Nickname must be $maxLength characters or fewer.';
    }
    if (!RegExp(r'^[A-Za-z0-9 _-]+$').hasMatch(trimmed)) {
      return 'Use only letters, numbers, spaces, - and _.';
    }

    // Strip down to letters, then also check a version with repeated letters
    // collapsed, so padding a word out with extra letters doesn't slip past.
    final letters = _toLetters(trimmed);
    final collapsed = letters.replaceAllMapped(
      RegExp(r'(.)\1+'),
      (m) => m.group(1)!,
    );
    if (_containsBanned(letters) || _containsBanned(collapsed)) {
      return _rejectedMessage;
    }

    return null;
  }

  static String _toLetters(String input) {
    final buffer = StringBuffer();
    for (final ch in input.toLowerCase().split('')) {
      buffer.write(_substitutions[ch] ?? ch);
    }
    return buffer.toString().replaceAll(RegExp(r'[^a-z]'), '');
  }

  // Hashes every substring in the blocklist's length range and looks it up.
  static bool _containsBanned(String normalized) {
    for (var len = _minBannedLength; len <= _maxBannedLength; len++) {
      if (len > normalized.length) break;
      for (var start = 0; start + len <= normalized.length; start++) {
        final chunk = normalized.substring(start, start + len);
        if (_bannedHashes.contains(_hash(chunk))) return true;
      }
    }
    return false;
  }

  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}
