Map<String, String> requestHeaders({String? session}) {
  return {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (session != null) 'Authorization': 'Bearer $session',
  };
}
