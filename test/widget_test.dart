import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_keep/config/app_theme.dart';
import 'package:go_keep/models/checklist_item.dart';
import 'package:go_keep/models/label.dart';
import 'package:go_keep/models/note.dart';
import 'package:go_keep/models/user.dart';
import 'package:go_keep/providers/auth_provider.dart';
import 'package:go_keep/screens/login_screen.dart';
import 'package:go_keep/services/api_service.dart';

void main() {
  testWidgets('LoginScreen smoke test', (WidgetTester tester) async {
    final apiService = ApiService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: apiService),
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(apiService),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const LoginScreen(),
        ),
      ),
    );

    // Verifikasi elemen halaman login berhasil dirender
    expect(find.text('Go-Keep'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Daftar'), findsOneWidget);
  });

  group('Model serialization tests', () {
    test('User fromJson & toJson', () {
      final json = {
        'id': 1,
        'name': 'Budi Santoso',
        'email': 'budi@example.com',
        'created_at': '2026-10-15T10:00:00.000Z',
      };
      final user = User.fromJson(json);
      expect(user.id, 1);
      expect(user.name, 'Budi Santoso');
      expect(user.email, 'budi@example.com');
      expect(user.createdAt, isNotNull);
      expect(user.toJson()['email'], 'budi@example.com');
    });

    test('Label fromJson & toJson', () {
      final json = {
        'id': 10,
        'name': 'Pekerjaan',
        'notes_count': 5,
      };
      final label = Label.fromJson(json);
      expect(label.id, 10);
      expect(label.name, 'Pekerjaan');
      expect(label.notesCount, 5);
      expect(label.toJson()['notes_count'], 5);
    });

    test('ChecklistItem fromJson & toJson', () {
      final json = {
        'id': 101,
        'note_id': 20,
        'text': 'Beli susu',
        'is_checked': true,
        'position': 1,
      };
      final item = ChecklistItem.fromJson(json);
      expect(item.id, 101);
      expect(item.noteId, 20);
      expect(item.text, 'Beli susu');
      expect(item.isChecked, true);
      expect(item.position, 1);
      expect(item.toJson()['is_checked'], true);
    });

    test('Note fromJson & toJson with relations', () {
      final json = {
        'id': 1,
        'user_id': 2,
        'title': 'Catatan Rapat',
        'content': 'Agenda sprint 4',
        'type': 'text',
        'color': 'yellow',
        'is_pinned': true,
        'is_archived': false,
        'deleted_at': null,
        'created_at': '2026-10-15T10:00:00.000Z',
        'updated_at': '2026-10-15T11:00:00.000Z',
        'checklist_items': [
          {
            'id': 1,
            'note_id': 1,
            'text': 'Review PR',
            'is_checked': false,
            'position': 0,
          }
        ],
        'labels': [
          {
            'id': 1,
            'name': 'Pekerjaan',
          }
        ],
      };

      final note = Note.fromJson(json);
      expect(note.id, 1);
      expect(note.userId, 2);
      expect(note.title, 'Catatan Rapat');
      expect(note.color, 'yellow');
      expect(note.isPinned, true);
      expect(note.isArchived, false);
      expect(note.deletedAt, isNull);
      expect(note.isActive, true);
      expect(note.isTrash, false);
      expect(note.checklistItems.length, 1);
      expect(note.checklistItems.first.text, 'Review PR');
      expect(note.labels.length, 1);
      expect(note.labels.first.name, 'Pekerjaan');

      final outputJson = note.toJson();
      expect(outputJson['is_pinned'], true);
      expect(outputJson['checklist_items'], isNotEmpty);
    });

    test('Theme note colors mapping contains all backend colors', () {
      final expectedColors = [
        'default',
        'red',
        'orange',
        'yellow',
        'green',
        'teal',
        'blue',
        'purple',
        'pink',
        'brown',
        'gray',
      ];
      for (final color in expectedColors) {
        expect(AppTheme.noteColors.containsKey(color), true);
        expect(AppTheme.getNoteColor(color), isNotNull);
      }
      expect(AppTheme.getNoteColor('unknown'), AppTheme.noteColors['default']);
    });
  });
}
