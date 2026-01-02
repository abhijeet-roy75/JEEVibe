# Mobile App Updates Required

**Status:** ⚠️ **REQUIRED BEFORE DEPLOYMENT**

The backend API has been updated with security improvements. The mobile app needs updates to work with the new API.

---

## 🔴 Critical Updates Required

### 1. **Solve Endpoint Now Requires Authentication**

**File:** `mobile/lib/services/api_service.dart`

**Before:**
```dart
static Future<Solution> solveQuestion(File imageFile) async {
  var request = http.MultipartRequest(
    'POST',
    Uri.parse('$baseUrl/api/solve'),
  );
  // No auth header
}
```

**After:**
```dart
static Future<Solution> solveQuestion({
  required File imageFile,
  required String authToken, // ADD THIS
}) async {
  var request = http.MultipartRequest(
    'POST',
    Uri.parse('$baseUrl/api/solve'),
  );
  
  // ADD THIS
  request.headers['Authorization'] = 'Bearer $authToken';
  
  // ... rest of code
}
```

**Update all call sites:**
```dart
// Get token from AuthService
final authService = Provider.of<AuthService>(context, listen: false);
final token = await authService.getIdToken();

if (token == null) {
  throw Exception('Authentication required');
}

final solution = await ApiService.solveQuestion(
  imageFile: imageFile,
  authToken: token, // ADD THIS
);
```

---

### 2. **Error Response Format Changed**

**File:** `mobile/lib/services/api_service.dart` and all API call sites

**Before:**
```dart
if (response.statusCode == 200) {
  final jsonData = json.decode(response.body);
  // Handle response
} else {
  final errorData = json.decode(response.body);
  throw Exception(errorData['error'] ?? 'Error');
}
```

**After:**
```dart
if (response.statusCode == 200) {
  final jsonData = json.decode(response.body);
  
  // New format: { success: true, data: {...}, requestId: "..." }
  if (jsonData['success'] == true) {
    return parseData(jsonData['data']);
  } else {
    throw Exception(jsonData['error'] ?? 'Error');
  }
} else {
  final errorData = json.decode(response.body);
  
  // New format: { success: false, error: "...", requestId: "..." }
  throw Exception(errorData['error'] ?? 'Error');
}
```

---

### 3. **CORS Configuration**

**Action Required:** Add your mobile app's backend URL to `ALLOWED_ORIGINS`

**In Render.com:**
1. Go to Environment variables
2. Add: `ALLOWED_ORIGINS=https://jeevibe.onrender.com`
3. If you have a custom domain, add that too

**Note:** For mobile apps, CORS may not apply, but it's good to set it anyway.

---

## 🟡 Optional Updates (Recommended)

### 4. **Use Request ID for Better Debugging**

**New Response Format:**
```json
{
  "success": true,
  "data": {...},
  "requestId": "uuid-here"
}
```

**You can log requestId for debugging:**
```dart
final response = await apiCall();
final requestId = response['requestId'];
print('Request ID: $requestId'); // Use this when reporting bugs
```

---

### 5. **Handle Rate Limit Responses**

**New Rate Limit Response:**
```json
{
  "success": false,
  "error": "Too many requests from this IP, please try again later."
}
```

**Update error handling:**
```dart
catch (e) {
  if (e.toString().contains('Too many requests')) {
    // Show user-friendly message
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rate Limit Exceeded'),
        content: Text('Please wait a moment before trying again.'),
      ),
    );
  }
  // ... other error handling
}
```

---

## 📝 Files to Update

1. ✅ `mobile/lib/services/api_service.dart`
   - Update `solveQuestion()` to require authToken
   - Update error handling for new response format
   - Update all API methods to handle new response format

2. ✅ All screens that call `ApiService.solveQuestion()`
   - Pass authToken parameter
   - Handle new error format

3. ✅ Error handling throughout app
   - Update to handle `{ success: false, error: "..." }` format

---

## 🧪 Testing Checklist

After updating:

- [ ] Solve endpoint works with authentication
- [ ] Error messages display correctly
- [ ] Rate limit errors handled gracefully
- [ ] All API calls work with new response format
- [ ] Request IDs logged for debugging

---

## 🚀 Deployment Order

1. **Deploy Backend First**
   - Push backend changes to Render.com
   - Verify health endpoint works
   - Test API endpoints

2. **Update Mobile App**
   - Make required changes
   - Test locally
   - Deploy to TestFlight/Play Store

3. **Monitor**
   - Check logs for errors
   - Monitor rate limiting
   - Check error rates

---

## ⚠️ Breaking Changes Summary

| Change | Impact | Action Required |
|--------|--------|-----------------|
| Solve endpoint requires auth | 🔴 High | Add auth token to solve calls |
| Error response format | 🟡 Medium | Update error handling |
| Rate limiting | 🟢 Low | Handle rate limit errors gracefully |

---

**Priority:** Update solve endpoint authentication first - this is a breaking change!

