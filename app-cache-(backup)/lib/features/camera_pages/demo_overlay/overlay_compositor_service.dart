/// DEPRECATED — No longer used.
///
/// The screenshot-based export using [RenderRepaintBoundary.toImage] has been
/// replaced by [OverlayExportService], which performs true native-resolution
/// pixel compositing via [ui.PictureRecorder].
///
/// This file is retained temporarily to avoid breaking any indirect references,
/// but it will be removed in a future cleanup. Do not use this service.
///
/// Use [OverlayExportService.exportComposite] instead.
@Deprecated('Use OverlayExportService instead.')
library;
