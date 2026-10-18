# Sos extension

Not implemented in the base.

- Collections: `patients/{pid}/alerts (type sos, audience all)`.
- Functions: onAlertCreated.
- Add providers under data/ and widgets under presentation/ when implementing.
- Gate the UI with `FeatureFlags.sos` in `lib/core/feature_flags.dart` (false by default). A disabled feature renders nothing (`SizedBox.shrink()`); do not add a placeholder or navigation item.
