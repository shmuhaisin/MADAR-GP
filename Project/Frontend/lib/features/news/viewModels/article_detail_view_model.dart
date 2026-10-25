import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';

import '../models/article_model.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/news_api.dart';
import '../../../core/storage/token_storage.dart';

sealed class ArticleDetailEvent {
  const ArticleDetailEvent();
}

class ShowAddToSheetEvent extends ArticleDetailEvent {
  const ShowAddToSheetEvent();
}

class ShowAddConfirmEvent extends ArticleDetailEvent {
  final String groupName;
  const ShowAddConfirmEvent(this.groupName);
}

class RedirectToNewsWithSuccessEvent extends ArticleDetailEvent {
  final String message;
  const RedirectToNewsWithSuccessEvent(this.message);
}

class ShowReportConfirmEvent extends ArticleDetailEvent {
  const ShowReportConfirmEvent();
}

class ShowErrorEvent extends ArticleDetailEvent {
  final String message;
  const ShowErrorEvent(this.message);
}

enum AudioUiState {
  idle,
  loading,
  playing,
  paused,
}

class ArticleDetailViewModel extends ChangeNotifier {
  final ApiClient _client;
  late final NewsApi _api;
  final TokenStorage _tokenStorage = TokenStorage();

  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  ArticleModel? article;
  final String articleId;

  bool loading = false;
  bool summaryLoading = false;
  bool audioLoading = false;
  String? error;

  bool ttsEnabled = false;
  bool summaryEnabled = false;
  bool isPlayingAudio = false;

  Duration audioPosition = Duration.zero;
  Duration audioDuration = Duration.zero;

  String currentAudioMode = 'full';
  AudioUiState audioUiState = AudioUiState.idle;

  final ValueNotifier<ArticleDetailEvent?> event = ValueNotifier(null);

  String? selectedCollectionId;
  String? selectedCollectionName;

  ArticleDetailViewModel({
    required this.articleId,
    ArticleModel? initialArticle,
    ApiClient? api,
  })  : _client = api ?? ApiClient(),
        article = initialArticle {
    _api = NewsApi(_client);
    _bindAudioPlayer();
  }

  void _bindAudioPlayer() {
    _playerStateSub = _audioPlayer.playerStateStream.listen((state) {
      isPlayingAudio = state.playing;

      if (state.processingState == ProcessingState.completed) {
        ttsEnabled = false;
        isPlayingAudio = false;
        audioPosition = Duration.zero;
        audioUiState = AudioUiState.idle;
        notifyListeners();
        return;
      }

      if (state.playing) {
        audioUiState = AudioUiState.playing;
      } else if (audioPosition > Duration.zero) {
        audioUiState = AudioUiState.paused;
      } else if (!audioLoading) {
        audioUiState = AudioUiState.idle;
      }

      notifyListeners();
    });

    _positionSub = _audioPlayer.positionStream.listen((position) {
      audioPosition = position;
      notifyListeners();
    });

    _durationSub = _audioPlayer.durationStream.listen((duration) {
      audioDuration = duration ?? Duration.zero;
      notifyListeners();
    });
  }

  void _emit(ArticleDetailEvent e) {
    event.value = e;
    event.value = null;
  }

  void clearError() {
    if (error == null) return;
    error = null;
    notifyListeners();
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 3),
      );

      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> toggleTts(bool v) async {
    if (audioUiState == AudioUiState.loading) return;

    if (audioUiState == AudioUiState.playing) {
      ttsEnabled = false;
      await stopAudio();
      notifyListeners();
      return;
    }

    if (audioUiState == AudioUiState.paused) {
      ttsEnabled = true;
      await resumeAudio();
      notifyListeners();
      return;
    }

    ttsEnabled = v;
    notifyListeners();

    if (!v) {
      await stopAudio();
      return;
    }

    await playCurrentAudio();
  }

  Future<void> toggleSummary(bool v) async {
    summaryEnabled = v;
    notifyListeners();

    if (v && article != null && article!.summaryText.trim().isEmpty) {
      await loadSummary();
    }

    if (ttsEnabled) {
      await playCurrentAudio();
    }
  }

  void onAddToPressed() => _emit(const ShowAddToSheetEvent());

  void onGroupChosen({
    required String collectionId,
    required String collectionName,
  }) {
    selectedCollectionId = collectionId;
    selectedCollectionName = collectionName;
    _emit(ShowAddConfirmEvent(collectionName));
  }

  void onReportPressed() => _emit(const ShowReportConfirmEvent());

  Future<void> loadDetails() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final res = await _api.getById(articleId);

      final Map<String, dynamic> json =
          (res['news'] ?? res['data'] ?? res) as Map<String, dynamic>;

      article = ArticleModel.fromJson(json);
    } catch (e) {
      final msg = ApiClient.formatDioError(e);

      if (msg.contains('HTTP 401')) {
        await _tokenStorage.clearToken();
        error = 'غير مصرح. سجّل دخولك من جديد.';
      } else {
        error = msg;
      }

      _emit(ShowErrorEvent(error ?? 'حدث خطأ غير متوقع'));
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadSummary() async {
    if (article == null) return;
    if (article!.summaryText.trim().isNotEmpty) return;

    summaryLoading = true;
    notifyListeners();

    try {
      final online = await _hasInternetConnection();

      if (!online) {
        summaryEnabled = false;
        summaryLoading = false;
        notifyListeners();
        _emit(const ShowErrorEvent('الملخص غير متاح بدون إنترنت'));
        return;
      }

      final res = await _api.getSummary(articleId);
      final summaryText = (res['summaryText'] ?? '').toString();

      article = article!.copyWith(summaryText: summaryText);
    } catch (e) {
      final msg = ApiClient.formatDioError(e);
      _emit(ShowErrorEvent(msg));
    } finally {
      summaryLoading = false;
      notifyListeners();
    }
  }

  Future<void> playCurrentAudio() async {
    if (article == null) return;

    final mode = summaryEnabled ? 'summary' : 'full';

    try {
      audioLoading = true;
      audioUiState = AudioUiState.loading;
      error = null;
      notifyListeners();

      final online = await _hasInternetConnection();

      if (!online) {
        audioLoading = false;
        ttsEnabled = false;
        audioUiState = AudioUiState.idle;
        notifyListeners();
        _emit(const ShowErrorEvent('الاستماع غير متاح بدون إنترنت'));
        return;
      }

      final data = await _api.getAudioRequestData(
        id: articleId,
        mode: mode,
      );

      final url = (data['url'] ?? '').toString().trim();

      if (url.isEmpty) {
        throw Exception('Audio URL is empty');
      }

      final rawNews = data['news'];

      if (rawNews is Map) {
        article = ArticleModel.fromJson(Map<String, dynamic>.from(rawNews));
      } else {
        article = mode == 'summary'
            ? article!.copyWith(ttsAudioURLforSummary: url)
            : article!.copyWith(ttsAudioURLforContent: url);
      }

      currentAudioMode = mode;

      await _audioPlayer.stop();
      await _audioPlayer.setUrl(url);

      audioLoading = false;
      isPlayingAudio = true;
      audioUiState = AudioUiState.playing;
      notifyListeners();

      unawaited(_audioPlayer.play());
    } catch (e, s) {
      debugPrint('PLAY AUDIO ERROR => $e');
      debugPrint('PLAY AUDIO STACK => $s');

      audioLoading = false;
      ttsEnabled = false;
      isPlayingAudio = false;
      audioUiState = AudioUiState.idle;
      error = 'تعذر تشغيل الصوت';
      _emit(ShowErrorEvent(error!));
      notifyListeners();
    }
  }

  Future<void> pauseAudio() async {
    await _audioPlayer.pause();
    isPlayingAudio = false;
    audioUiState = AudioUiState.paused;
    notifyListeners();
  }

  Future<void> resumeAudio() async {
    await _audioPlayer.play();
    isPlayingAudio = true;
    audioUiState = AudioUiState.playing;
    notifyListeners();
  }

  Future<void> stopAudio() async {
    await _audioPlayer.stop();
    isPlayingAudio = false;
    audioPosition = Duration.zero;
    audioDuration = Duration.zero;
    audioUiState = AudioUiState.idle;
    notifyListeners();
  }

  Future<void> replayAudio() async {
    await _audioPlayer.seek(Duration.zero);
    await _audioPlayer.play();
    isPlayingAudio = true;
    audioUiState = AudioUiState.playing;
    notifyListeners();
  }

  Future<void> reportConfirmed() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final res = await _api.report(articleId);
      final status = (res['status'] ?? '').toString();

      if (status == 'already_reported') {
        _emit(
          const RedirectToNewsWithSuccessEvent(
            'لقد قمت بالإبلاغ عن هذا الخبر مسبقًا',
          ),
        );
      } else if (status == 'deleted') {
        _emit(
          const RedirectToNewsWithSuccessEvent(
            'تم حذف الخبر بسبب كثرة البلاغات',
          ),
        );
      } else {
        _emit(const RedirectToNewsWithSuccessEvent('تم إرسال البلاغ بنجاح'));
      }
    } catch (e) {
      final msg = ApiClient.formatDioError(e);

      if (msg.contains('HTTP 401')) {
        await _tokenStorage.clearToken();
        error = 'غير مصرح. سجّل دخولك من جديد.';
      } else {
        error = msg;
      }

      _emit(ShowErrorEvent(error ?? 'حدث خطأ غير متوقع'));
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> shareArticle(ArticleModel a) async {
    final categoryAr = _categoryToArabic(a.category);
    final dateStr = _formatPublishDate(a.publishDate);

    final body = (summaryEnabled && a.summaryText.trim().isNotEmpty)
        ? a.summaryText
        : a.newsContent;

    final text = '''
${a.newsTitle}

الاهتمام: $categoryAr
المصدر: ${a.newsSource}
تاريخ النشر: $dateStr

$body

الرابط:
${a.sourceLink}
''';

    await Share.share(text);
  }

  String _categoryToArabic(String v) {
    switch (v.trim()) {
      case 'Health':
        return 'الصحة';
      case 'Politics':
        return 'السياسة';
      case 'Entertainment':
        return 'الترفيه';
      case 'Technology':
        return 'التقنية';
      case 'Sports':
        return 'الرياضة';
      case 'Economy':
        return 'الاقتصاد';
      default:
        return v.trim().isEmpty ? 'الكل' : v.trim();
    }
  }

  String _formatPublishDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy - $hh:$min';
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _audioPlayer.dispose();
    event.dispose();
    super.dispose();
  }
}