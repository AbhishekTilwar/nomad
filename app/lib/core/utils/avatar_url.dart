/// Photos served by Google accounts (`lh3.googleusercontent.com/...`) are the
/// Google profile picture, not something the person uploaded to Nomad Mingle.
/// The app never uses them: people see an initials avatar until they add their
/// own photo. Our own uploads live in Firebase Storage, a different host.
bool isGoogleProfilePhoto(String? url) {
  if (url == null || url.isEmpty) return false;
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  return host == 'googleusercontent.com' ||
      host.endsWith('.googleusercontent.com') ||
      host.endsWith('.ggpht.com');
}

/// [url] unless it is a Google profile picture (then null: no photo).
String? ownPhotoUrl(String? url) =>
    (url == null || url.isEmpty || isGoogleProfilePhoto(url)) ? null : url;

/// [urls] without any Google profile pictures.
List<String> ownPhotoUrls(Iterable<String> urls) => [
  for (final u in urls)
    if (!isGoogleProfilePhoto(u)) u,
];
