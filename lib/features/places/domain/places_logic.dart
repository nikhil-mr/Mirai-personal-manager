Uri mapsSearchUri({
  required String name,
  String address = '',
  double? latitude,
  double? longitude,
}) {
  final query = latitude != null && longitude != null
      ? '$latitude,$longitude'
      : address.trim().isNotEmpty
      ? address.trim()
      : name.trim();
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': query,
  });
}

Uri placeVisitUri({
  required String name,
  String address = '',
  String mapUrl = '',
  double? latitude,
  double? longitude,
}) {
  final savedLink = Uri.tryParse(mapUrl.trim());
  if (savedLink != null &&
      {'http', 'https'}.contains(savedLink.scheme) &&
      savedLink.host.isNotEmpty) {
    return savedLink;
  }
  return mapsSearchUri(
    name: name,
    address: address,
    latitude: latitude,
    longitude: longitude,
  );
}
