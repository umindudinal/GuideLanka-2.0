import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/theme_constants.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  List<dynamic> _reviews = [];
  bool _isLoading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
    NotificationService.profileRefreshTick.addListener(_onRefreshTick);
  }

  @override
  void dispose() {
    NotificationService.profileRefreshTick.removeListener(_onRefreshTick);
    super.dispose();
  }

  void _onRefreshTick() {
    if (mounted) {
      _fetchReviews();
    }
  }

  Future<void> _fetchReviews() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final result = await ApiService.getMyReviews();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _reviews = List<dynamic>.from(result['reviews'] ?? []);
      } else {
        _errorMsg = result['error']?.toString() ?? 'Could not load reviews.';
      }
    });
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
    final dt = DateTime.tryParse(isoDate)?.toLocal();
    if (dt == null) return '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  double get _averageRating {
    if (_reviews.isEmpty) return 0.0;
    double sum = 0;
    for (final r in _reviews) {
      sum += (double.tryParse(r['rating']?.toString() ?? '0') ?? 0.0);
    }
    return sum / _reviews.length;
  }

  Future<void> _openReplySheet(Map<String, dynamic> review) async {
    final existingReply = review['driver_reply']?.toString() ?? '';
    final updatedReview = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReplyBottomSheet(
        reviewId: review['id'].toString(),
        touristName: review['tourist_name']?.toString() ?? 'Safari Guest',
        rating: int.tryParse(review['rating']?.toString() ?? '5') ?? 5,
        comment: review['comment']?.toString() ?? '',
        initialReply: existingReply,
      ),
    );

    if (updatedReview != null && mounted) {
      setState(() {
        final idx = _reviews.indexWhere((r) => r['id']?.toString() == updatedReview['id']?.toString());
        if (idx != -1) {
          _reviews[idx] = updatedReview;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Reply published to your profile!'),
          backgroundColor: AppColors.online,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSand,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Tourist Reviews', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _fetchReviews,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _errorMsg != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 60),
                      const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.offline),
                      const SizedBox(height: 12),
                      Text(
                        _errorMsg!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(
                          onPressed: _fetchReviews,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: AppGradients.primaryGradient,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: AppShadows.intenseShadow,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.star_rounded, color: AppColors.accent, size: 32),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _reviews.isEmpty
                                        ? 'No Ratings Yet'
                                        : '${_averageRating.toStringAsFixed(1)} / 5.0 Average',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_reviews.length} ${_reviews.length == 1 ? 'tourist review' : 'tourist reviews'} received',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_reviews.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                          decoration: AppDecorations.premiumCard,
                          child: const Column(
                            children: [
                              Icon(Icons.rate_review_outlined, size: 46, color: AppColors.textLight),
                              SizedBox(height: 12),
                              Text(
                                'No Tourist Reviews Yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'When tourists rate your safaris, their reviews will appear here and you can reply directly.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._reviews.map((item) {
                          final review = Map<String, dynamic>.from(item as Map);
                          final touristName = review['tourist_name']?.toString() ?? 'Safari Guest';
                          final rating = int.tryParse(review['rating']?.toString() ?? '5') ?? 5;
                          final comment = review['comment']?.toString() ?? '';
                          final reply = review['driver_reply']?.toString() ?? '';
                          final dateStr = _formatDate(review['created_at']?.toString());

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: AppDecorations.premiumCard,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppColors.primaryExtraLight,
                                      child: Text(
                                        touristName.isNotEmpty ? touristName[0].toUpperCase() : 'T',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            touristName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              color: AppColors.textDark,
                                            ),
                                          ),
                                          if (dateStr.isNotEmpty)
                                            Text(
                                              dateStr,
                                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: List.generate(
                                        5,
                                        (idx) => Icon(
                                          idx < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                          size: 16,
                                          color: Colors.amber.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Text(
                                    '"$comment"',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textDark,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                if (reply.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryExtraLight,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.reply_rounded, size: 14, color: AppColors.primary),
                                            SizedBox(width: 4),
                                            Text(
                                              'Your Reply',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          reply,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textDark,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => _openReplySheet(review),
                                    icon: Icon(
                                      reply.isEmpty ? Icons.reply_rounded : Icons.edit_outlined,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                    label: Text(
                                      reply.isEmpty ? 'Reply to Review' : 'Edit Reply',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
      ),
    );
  }
}

class _ReplyBottomSheet extends StatefulWidget {
  final String reviewId;
  final String touristName;
  final int rating;
  final String comment;
  final String initialReply;

  const _ReplyBottomSheet({
    required this.reviewId,
    required this.touristName,
    required this.rating,
    required this.comment,
    required this.initialReply,
  });

  @override
  State<_ReplyBottomSheet> createState() => _ReplyBottomSheetState();
}

class _ReplyBottomSheetState extends State<_ReplyBottomSheet> {
  late final TextEditingController _replyCtrl;
  bool _isSending = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _replyCtrl = TextEditingController(text: widget.initialReply);
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _errorMsg = 'Please write a reply message.');
      return;
    }

    setState(() {
      _isSending = true;
      _errorMsg = null;
    });

    final res = await ApiService.replyToReview(widget.reviewId, text);
    if (!mounted) return;

    if (res['success'] == true && res['review'] is Map) {
      Navigator.of(context).pop(Map<String, dynamic>.from(res['review'] as Map));
    } else {
      setState(() {
        _isSending = false;
        _errorMsg = res['error']?.toString() ?? 'Failed to post reply.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Reply to ${widget.touristName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isSending ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(
                        5,
                        (idx) => Icon(
                          idx < widget.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 14,
                          color: Colors.amber.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '"${widget.comment}"',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_errorMsg != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMsg!,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              TextField(
                controller: _replyCtrl,
                enabled: !_isSending,
                maxLines: 4,
                maxLength: 400,
                decoration: InputDecoration(
                  labelText: 'Your Reply',
                  hintText: 'Thank the guest or share a quick note...',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSending ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _isSending ? 'Sending...' : 'Post Reply',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
