abstract final class FinalSaveCredits {
  static const limit = 30;
}

class FinalSaveLimitReached implements Exception {
  const FinalSaveLimitReached();
}
