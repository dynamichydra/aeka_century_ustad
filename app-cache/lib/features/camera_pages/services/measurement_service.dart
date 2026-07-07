class MeasurementService {
  const MeasurementService();

  static double calculateAreaInSqFt(double widthInches, double heightInches) {
    final double calculatedArea = (widthInches * heightInches) / 144.0;
    return double.parse(calculatedArea.toStringAsFixed(1));
  }

  static double calculateWidthInchesFromPixelWidth(double pixelWidth) {
    return pixelWidth.roundToDouble();
  }

  static double calculateHeightInchesFromPixelHeight(double pixelHeight) {
    return pixelHeight.roundToDouble();
  }
}
