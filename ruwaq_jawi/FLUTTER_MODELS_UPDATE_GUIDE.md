# 🔄 FLUTTER MODELS UPDATE GUIDE

## 🎯 **DATABASE SEKARANG GUNA MODERN COLUMNS SAHAJA!**

Database anda dah dibersihkan dan sekarang guna **modern column names** yang lebih comprehensive dan future-proof. Anda perlu update 3 Flutter model files.

---

## 📱 **UPDATES YANG PERLU DIBUAT:**

### **1. SUBSCRIPTION MODEL** 
**File: `lib/core/models/subscription.dart`**

#### **SEBELUM (Old Flutter columns):**
```dart
factory Subscription.fromJson(Map<String, dynamic> json) {
  return Subscription(
    planType: json['plan_type'] as String,           // ❌ Column tidak wujud
    startDate: DateTime.parse(json['start_date']),   // ❌ Column tidak wujud  
    endDate: DateTime.parse(json['end_date']),       // ❌ Column tidak wujud
    paymentMethod: json['payment_method'] as String?, // ❌ Column tidak wujud
  );
}
```

#### **SEKARANG (Modern columns):**
```dart
factory Subscription.fromJson(Map<String, dynamic> json) {
  return Subscription(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    planType: json['plan_id'] as String,                    // ✅ CHANGE: plan_type → plan_id
    startDate: DateTime.parse(json['started_at'] as String), // ✅ CHANGE: start_date → started_at  
    endDate: DateTime.parse(json['current_period_end'] as String), // ✅ CHANGE: end_date → current_period_end
    status: json['status'] as String,
    paymentMethod: json['provider'] as String?,             // ✅ CHANGE: payment_method → provider
    amount: double.parse(json['amount'].toString()),
    currency: json['currency'] as String,
    autoRenew: json['auto_renew'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );
}
```

#### **UPDATE toJson() juga:**
```dart
Map<String, dynamic> toJson() {
  return {
    'id': id,
    'user_id': userId,
    'plan_id': planType,                    // ✅ CHANGE: plan_type → plan_id
    'started_at': startDate.toIso8601String(), // ✅ CHANGE: start_date → started_at
    'current_period_end': endDate.toIso8601String(), // ✅ CHANGE: end_date → current_period_end
    'status': status,
    'provider': paymentMethod,              // ✅ CHANGE: payment_method → provider
    'amount': amount,
    'currency': currency,
    'auto_renew': autoRenew,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
```

---

### **2. TRANSACTION MODEL**
**File: `lib/core/models/transaction.dart`**

#### **SEBELUM (Old Flutter columns):**
```dart
factory Transaction.fromJson(Map<String, dynamic> json) {
  return Transaction(
    amount: double.parse(json['amount'].toString()),              // ❌ Column tidak wujud
    gatewayTransactionId: json['gateway_transaction_id'],         // ❌ Column tidak wujud
    gatewayReference: json['gateway_reference'],                  // ❌ Column tidak wujud
    processedAt: json['processed_at'] != null ? DateTime.parse(json['processed_at']) : null, // ❌ Column tidak wujud
  );
}
```

#### **SEKARANG (Modern columns):**
```dart
factory Transaction.fromJson(Map<String, dynamic> json) {
  return Transaction(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    subscriptionId: json['subscription_id'] as String?,
    amount: (json['amount_cents'] as int) / 100.0,              // ✅ CHANGE: amount → amount_cents / 100
    currency: json['currency'] as String,
    paymentMethod: json['provider'] as String,                  // ✅ CHANGE: payment_method → provider
    gatewayTransactionId: json['provider_payment_id'] as String?, // ✅ CHANGE: gateway_transaction_id → provider_payment_id
    gatewayReference: json['reference_number'] as String?,        // ✅ CHANGE: gateway_reference → reference_number
    status: json['status'] as String,
    failureReason: json['description'] as String?,               // ✅ NEW: Use description for failure reason
    metadata: json['metadata'] as Map<String, dynamic>?,
    processedAt: json['paid_at'] != null ? DateTime.parse(json['paid_at'] as String) : null, // ✅ CHANGE: processed_at → paid_at
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
```

#### **UPDATE toJson() juga:**
```dart
Map<String, dynamic> toJson() {
  return {
    'id': id,
    'user_id': userId,
    'subscription_id': subscriptionId,
    'amount_cents': (amount * 100).round(),      // ✅ CHANGE: amount → amount_cents * 100
    'currency': currency,
    'provider': paymentMethod,                   // ✅ CHANGE: payment_method → provider
    'provider_payment_id': gatewayTransactionId, // ✅ CHANGE: gateway_transaction_id → provider_payment_id
    'reference_number': gatewayReference,        // ✅ CHANGE: gateway_reference → reference_number
    'status': status,
    'description': failureReason,                // ✅ NEW: Map failure_reason to description
    'metadata': metadata,
    'paid_at': processedAt?.toIso8601String(),   // ✅ CHANGE: processed_at → paid_at
    'created_at': createdAt.toIso8601String(),
  };
}
```

---

### **3. READING_PROGRESS MODEL**
**File: `lib/core/models/reading_progress.dart`**

#### **SEBELUM (Old Flutter columns):**
```dart
factory ReadingProgress.fromJson(Map<String, dynamic> json) {
  return ReadingProgress(
    pdfPage: json['pdf_page'] as int? ?? 1,                        // ❌ Column tidak wujud
    pdfTotalPages: json['pdf_total_pages'] as int?,                // ❌ Column tidak wujud
    completionPercentage: double.parse((json['completion_percentage'] ?? 0.0).toString()), // ❌ Column tidak wujud
  );
}
```

#### **SEKARANG (Modern columns + NEW features):**
```dart
factory ReadingProgress.fromJson(Map<String, dynamic> json) {
  return ReadingProgress(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    kitabId: json['kitab_id'] as String,
    videoProgress: json['video_progress'] as int? ?? 0,
    videoDuration: json['video_duration'] as int? ?? 0,
    pdfPage: json['current_page'] as int? ?? 1,                    // ✅ CHANGE: pdf_page → current_page
    pdfTotalPages: json['total_pages'] as int?,                    // ✅ CHANGE: pdf_total_pages → total_pages
    completionPercentage: double.parse((json['progress_percentage'] ?? 0.0).toString()), // ✅ CHANGE: completion_percentage → progress_percentage
    lastAccessed: DateTime.parse(json['last_accessed'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    
    // ✅ NEW FEATURES AVAILABLE:
    bookmarks: json['bookmarks'] as List<dynamic>? ?? [],          // ✅ NEW: JSON bookmarks
    notes: json['notes'] as Map<String, dynamic>? ?? {},           // ✅ NEW: JSON notes
  );
}
```

#### **UPDATE toJson() juga:**
```dart
Map<String, dynamic> toJson() {
  return {
    'id': id,
    'user_id': userId,
    'kitab_id': kitabId,
    'video_progress': videoProgress,
    'video_duration': videoDuration,
    'current_page': pdfPage,                         // ✅ CHANGE: pdf_page → current_page
    'total_pages': pdfTotalPages,                    // ✅ CHANGE: pdf_total_pages → total_pages
    'progress_percentage': completionPercentage,     // ✅ CHANGE: completion_percentage → progress_percentage
    'last_accessed': lastAccessed.toIso8601String(),
    'bookmarks': bookmarks,                          // ✅ NEW: Save bookmarks as JSON
    'notes': notes,                                  // ✅ NEW: Save notes as JSON
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
```

#### **ADD new properties to ReadingProgress class:**
```dart
class ReadingProgress {
  // ... existing properties ...
  
  // ✅ NEW: Add these properties
  final List<dynamic> bookmarks;     // JSON array for bookmarks
  final Map<String, dynamic> notes;  // JSON object for notes

  ReadingProgress({
    // ... existing parameters ...
    this.bookmarks = const [],       // ✅ NEW: Default empty list
    this.notes = const {},           // ✅ NEW: Default empty map
  });

  // ✅ NEW: Helper methods for bookmarks & notes
  void addBookmark(Map<String, dynamic> bookmark) {
    bookmarks.add(bookmark);
  }
  
  void addNote(String key, dynamic value) {
    notes[key] = value;
  }
}
```

---

## 🆕 **BONUS: NEW FEATURES AVAILABLE**

Dengan modern database structure, anda sekarang ada **NEW FEATURES**:

### **1. Enhanced Subscription Management:**
- ✅ `current_period_start` & `current_period_end` - Track billing periods accurately
- ✅ `provider_customer_id` - Link to payment provider customer
- ✅ `provider_subscription_id` - Link to payment provider subscription
- ✅ `canceled_at` - Track when subscription was cancelled
- ✅ `metadata` - Store additional subscription data

### **2. Advanced Payment Tracking:**
- ✅ `amount_cents` - Precise money handling (no floating point errors)
- ✅ `provider_payment_id` - Direct link to payment provider transaction
- ✅ `payment_intent_id` - Track payment intentions
- ✅ `receipt_url` - Link to payment receipt
- ✅ `raw_payload` - Store complete webhook data for debugging

### **3. Rich Reading Progress:**
- ✅ `bookmarks` - JSON array to store multiple bookmarks per kitab
- ✅ `notes` - JSON object to store user notes and highlights
- ✅ Better progress tracking with separate video and PDF tracking

---

## ✅ **CHECKLIST UNTUK ANDA:**

- [ ] Update `subscription.dart` model dengan modern columns
- [ ] Update `transaction.dart` model dengan modern columns  
- [ ] Update `reading_progress.dart` model dengan modern columns + new features
- [ ] Test app untuk pastikan data load dengan betul
- [ ] Update any API calls yang hardcode column names
- [ ] Consider using new features (bookmarks, notes, enhanced payment tracking)

---

## 🎉 **RESULT:**

Selepas update ini, database anda akan:
- ✅ **100% modern & future-proof**
- ✅ **Single source of truth** (tak ada duplicate columns)
- ✅ **Enhanced features** (bookmarks, notes, better payment tracking)
- ✅ **Better performance** (optimized structure)
- ✅ **Easier to maintain** (consistent naming)
