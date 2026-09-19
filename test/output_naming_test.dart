import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shrink/io/output_naming.dart';
import 'package:shrink/model/output_format.dart';
import 'package:shrink/model/output_options.dart';

void main() {
  String absolute(String path) => p.normalize(p.absolute(path));

  group('destinationFor', () {
    test('writes beside the source with the suffix appended', () {
      final path = OutputNaming.destinationFor(
        sourcePath: p.join('photos', 'holiday.jpg'),
        format: OutputFormat.jpeg,
        options: const OutputOptions(suffix: '-small'),
      );
      expect(p.basename(path), 'holiday-small.jpg');
      expect(p.dirname(path), 'photos');
    });

    test('takes the extension from the target format, not the source', () {
      final path = OutputNaming.destinationFor(
        sourcePath: p.join('photos', 'logo.png'),
        format: OutputFormat.jpeg,
        options: const OutputOptions(suffix: ''),
      );
      expect(p.basename(path), 'logo.jpg');
    });

    test('writes into the chosen folder, keeping the name', () {
      final path = OutputNaming.destinationFor(
        sourcePath: p.join('photos', 'holiday.jpg'),
        format: OutputFormat.jpeg,
        options: OutputOptions(
          destination: OutputDestination.chosenFolder,
          folder: p.join('out'),
          suffix: '',
        ),
      );
      expect(p.dirname(path), 'out');
      expect(p.basename(path), 'holiday.jpg');
    });

    test('falls back to the source folder when no folder has been chosen', () {
      // Better than writing to the working directory, which for a launched
      // desktop application is somewhere nobody would think to look.
      final path = OutputNaming.destinationFor(
        sourcePath: p.join('photos', 'holiday.jpg'),
        format: OutputFormat.jpeg,
        options: const OutputOptions(
          destination: OutputDestination.chosenFolder,
          suffix: '-small',
        ),
      );
      expect(p.dirname(path), 'photos');
    });
  });

  group('sanitiseSuffix', () {
    test('strips what a filesystem will not accept', () {
      expect(OutputNaming.sanitiseSuffix('a/b\\c:d*e?'), 'abcde');
      expect(OutputNaming.sanitiseSuffix('  -small  '), '-small');
    });

    test('leaves an ordinary suffix alone', () {
      expect(OutputNaming.sanitiseSuffix('_1600px'), '_1600px');
    });
  });

  group('resolve', () {
    const options = OutputOptions();

    test('uses the name when it is free', () {
      final plan = OutputNaming.resolve(
        candidate: absolute('out/a.jpg'),
        options: options,
        protected: <String>{},
        exists: (_) => false,
      );
      expect(plan.skipped, isFalse);
      expect(plan.path, absolute('out/a.jpg'));
    });

    test('adds a number when renaming', () {
      final taken = <String>{absolute('out/a.jpg')};
      final plan = OutputNaming.resolve(
        candidate: absolute('out/a.jpg'),
        options: options,
        protected: <String>{},
        exists: (path) => taken.contains(absolute(path)),
      );
      expect(p.basename(plan.path!), 'a (2).jpg');
    });

    test('keeps counting past a name that is also taken', () {
      final taken = <String>{absolute('out/a.jpg'), absolute('out/a (2).jpg')};
      final plan = OutputNaming.resolve(
        candidate: absolute('out/a.jpg'),
        options: options,
        protected: <String>{},
        exists: (path) => taken.contains(absolute(path)),
      );
      expect(p.basename(plan.path!), 'a (3).jpg');
    });

    test('overwrites when told to', () {
      final plan = OutputNaming.resolve(
        candidate: absolute('out/a.jpg'),
        options: const OutputOptions(collision: CollisionPolicy.overwrite),
        protected: <String>{},
        exists: (_) => true,
      );
      expect(plan.path, absolute('out/a.jpg'));
    });

    test('skips when told to', () {
      final plan = OutputNaming.resolve(
        candidate: absolute('out/a.jpg'),
        options: const OutputOptions(collision: CollisionPolicy.skip),
        protected: <String>{},
        exists: (_) => true,
      );
      expect(plan.skipped, isTrue);
      expect(plan.path, isNull);
    });

    test('never overwrites a source, whatever the policy says', () {
      // The rule that outranks every setting: somebody resizing a folder of
      // photographs in place, with the originals as the only copy, must not be
      // able to destroy them by leaving the suffix field empty.
      for (final policy in CollisionPolicy.values) {
        final plan = OutputNaming.resolve(
          candidate: absolute('photos/a.jpg'),
          options: OutputOptions(collision: policy),
          protected: <String>{absolute('photos/a.jpg')},
          exists: (_) => false,
        );
        expect(plan.skipped, isFalse, reason: 'policy $policy');
        expect(
          plan.path,
          isNot(absolute('photos/a.jpg')),
          reason: 'policy $policy overwrote a source file',
        );
      }
    });

    test('will not rename onto another source either', () {
      final plan = OutputNaming.resolve(
        candidate: absolute('photos/a.jpg'),
        options: const OutputOptions(),
        protected: <String>{
          absolute('photos/a.jpg'),
          absolute('photos/a (2).jpg'),
        },
        exists: (_) => false,
      );
      expect(p.basename(plan.path!), 'a (3).jpg');
    });
  });
}
