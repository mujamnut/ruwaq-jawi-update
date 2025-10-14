import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
      value: 0.0,
    );
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
      value: 0.0,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _fadeAnimationController.forward();
            _slideAnimationController.forward();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Help & Support',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: AppTheme.textPrimaryColor,
            size: 24,
          ),
          onPressed: () => context.pop(),
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value.clamp(0.0, 1.0),
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    _buildSearchBar(),

                    const SizedBox(height: 24),

                    // Quick Help Section
                    _buildSection(
                      title: 'Quick Help',
                      icon: PhosphorIcons.question(PhosphorIconsStyle.fill),
                      iconColor: const Color(0xFF4CAF50),
                      children: [
                        _buildHelpTile(
                          title: 'Getting Started',
                          subtitle: 'Learn the basics of using the app',
                          icon: PhosphorIcons.play(PhosphorIconsStyle.fill),
                          onTap: _handleGettingStarted,
                        ),
                        _buildHelpTile(
                          title: 'How to Subscribe',
                          subtitle: 'Step-by-step guide to premium plans',
                          icon: PhosphorIcons.crown(PhosphorIconsStyle.fill),
                          onTap: _handleHowToSubscribe,
                        ),
                        _buildHelpTile(
                          title: 'Payment Issues',
                          subtitle: 'Troubleshoot payment problems',
                          icon: PhosphorIcons.creditCard(PhosphorIconsStyle.fill),
                          onTap: _handlePaymentIssues,
                        ),
                        _buildHelpTile(
                          title: 'Account Settings',
                          subtitle: 'Manage your profile and preferences',
                          icon: PhosphorIcons.gear(PhosphorIconsStyle.fill),
                          onTap: _handleAccountSettings,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Contact Support Section
                    _buildSection(
                      title: 'Contact Support',
                      icon: PhosphorIcons.headset(PhosphorIconsStyle.fill),
                      iconColor: AppTheme.primaryColor,
                      children: [
                        _buildContactTile(
                          title: 'Live Chat',
                          subtitle: 'Chat with our support team',
                          icon: PhosphorIcons.chatCircle(PhosphorIconsStyle.fill),
                          badge: 'Online',
                          onTap: _handleLiveChat,
                        ),
                        _buildContactTile(
                          title: 'Email Support',
                          subtitle: 'Send us an email',
                          icon: PhosphorIcons.envelope(PhosphorIconsStyle.fill),
                          subtitle2: 'support@ruwaqjawi.com',
                          onTap: _handleEmailSupport,
                        ),
                        _buildContactTile(
                          title: 'Phone Support',
                          subtitle: 'Call us for immediate assistance',
                          icon: PhosphorIcons.phone(PhosphorIconsStyle.fill),
                          subtitle2: '+60 123-456-789',
                          onTap: _handlePhoneSupport,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Resources Section
                    _buildSection(
                      title: 'Resources',
                      icon: PhosphorIcons.bookOpen(PhosphorIconsStyle.fill),
                      iconColor: const Color(0xFF2196F3),
                      children: [
                        _buildHelpTile(
                          title: 'FAQ',
                          subtitle: 'Frequently asked questions',
                          icon: PhosphorIcons.question(PhosphorIconsStyle.fill),
                          onTap: _handleFAQ,
                        ),
                        _buildHelpTile(
                          title: 'Video Tutorials',
                          subtitle: 'Watch helpful video guides',
                          icon: PhosphorIcons.playCircle(PhosphorIconsStyle.fill),
                          onTap: _handleVideoTutorials,
                        ),
                        _buildHelpTile(
                          title: 'User Guide',
                          subtitle: 'Comprehensive user documentation',
                          icon: PhosphorIcons.fileText(PhosphorIconsStyle.fill),
                          onTap: _handleUserGuide,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Feedback Section
                    _buildSection(
                      title: 'Feedback',
                      icon: PhosphorIcons.chatText(PhosphorIconsStyle.fill),
                      iconColor: const Color(0xFFFF9800),
                      children: [
                        _buildHelpTile(
                          title: 'Report a Bug',
                          subtitle: 'Help us improve by reporting issues',
                          icon: PhosphorIcons.bug(PhosphorIconsStyle.fill),
                          onTap: _handleReportBug,
                        ),
                        _buildHelpTile(
                          title: 'Feature Request',
                          subtitle: 'Suggest new features or improvements',
                          icon: PhosphorIcons.lightbulb(PhosphorIconsStyle.fill),
                          onTap: _handleFeatureRequest,
                        ),
                        _buildHelpTile(
                          title: 'Rate Our App',
                          subtitle: 'Share your experience with others',
                          icon: PhosphorIcons.star(PhosphorIconsStyle.fill),
                          onTap: _handleRateApp,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search for help topics...',
          hintStyle: TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 15,
          ),
          prefixIcon: HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            color: AppTheme.textSecondaryColor,
            size: 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedSearchRemove,
                    color: AppTheme.textSecondaryColor,
                    size: 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        onChanged: (value) {
          setState(() {});
          if (value.isNotEmpty) {
            _performSearch(value);
          }
        },
        onSubmitted: (value) {
          if (value.isNotEmpty) {
            _performSearch(value);
          }
        },
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: PhosphorIcon(
                      icon,
                      color: iconColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
          // Section Content
          ...children,
        ],
      ),
    );
  }

  Widget _buildHelpTile({
    required String title,
    required String subtitle,
    required IconData icon,
    Color iconColor = AppTheme.primaryColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: PhosphorIcon(
                      icon,
                      color: iconColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                PhosphorIcon(
                  PhosphorIcons.caretRight(),
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactTile({
    required String title,
    required String subtitle,
    required IconData icon,
    String? subtitle2,
    String? badge,
    Color iconColor = AppTheme.primaryColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: PhosphorIcon(
                      icon,
                      color: iconColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  color: Color(0xFF4CAF50),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      if (subtitle2 != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle2,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PhosphorIcon(
                  PhosphorIcons.caretRight(),
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Quick Help Handlers
  void _handleGettingStarted() {
    _showHelpDialog(
      'Getting Started',
      [
        _buildHelpItem('1. Sign Up', 'Create your account with email and password'),
        _buildHelpItem('2. Browse Kitab', 'Explore our collection of Islamic books'),
        _buildHelpItem('3. Watch Videos', 'Access video explanations and lessons'),
        _buildHelpItem('4. Save Progress', 'Track your reading and learning progress'),
        _buildHelpItem('5. Get Premium', 'Unlock all features with subscription'),
      ],
      'Welcome to Maktabah Ruwaq Jawi! Your gateway to Islamic knowledge.',
    );
  }

  void _handleHowToSubscribe() {
    _showHelpDialog(
      'How to Subscribe',
      [
        _buildHelpItem('1. Go to Profile', 'Tap on your profile icon'),
        _buildHelpItem('2. Select Subscription', 'Choose your preferred plan'),
        _buildHelpItem('3. Payment Method', 'Select ToyyibPay or manual payment'),
        _buildHelpItem('4. Complete Payment', 'Follow the payment instructions'),
        _buildHelpItem('5. Enjoy Premium', 'Access all premium features immediately'),
      ],
      'Choose from Monthly (RM9.90) or Yearly (RM99.00) plans.',
    );
  }

  void _handlePaymentIssues() {
    _showHelpDialog(
      'Payment Issues',
      [
        _buildHelpItem('Payment Failed', 'Check your internet connection and try again'),
        _buildHelpItem('Card Declined', 'Contact your bank or use a different card'),
        _buildHelpItem('ToyyibPay Issues', 'Wait 5-10 minutes for payment confirmation'),
        _buildHelpItem('Manual Payment', 'Upload payment receipt and wait for verification'),
        _buildHelpItem('Still Problems?', 'Contact our support team for assistance'),
      ],
      'Most payment issues are resolved within 30 minutes.',
    );
  }

  void _handleAccountSettings() {
    _showHelpDialog(
      'Account Settings',
      [
        _buildHelpItem('Profile Info', 'Update your name, email, and profile picture'),
        _buildHelpItem('Password', 'Change your password for security'),
        _buildHelpItem('Notifications', 'Manage app notifications preferences'),
        _buildHelpItem('Privacy', 'Control your data and privacy settings'),
        _buildHelpItem('Delete Account', 'Permanently delete your account and data'),
      ],
      'Access these settings from your profile page.',
    );
  }

  // Contact Support Handlers
  void _handleLiveChat() {
    _showWhatsAppChat();
  }

  void _handleEmailSupport() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@ruwaqjawi.com',
      query: 'subject=Support Request - Maktabah Ruwaq Jawi&body=Hi Ruwaq Jawi Team,\n\nI need help with:\n\n[Please describe your issue here]\n\nThank you,\n[Your Name]',
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      _showErrorDialog('Email App', 'Could not open email app. Please email support@ruwaqjawi.com directly.');
    }
  }

  void _handlePhoneSupport() async {
    _showContactDialog();
  }

  // Resources Handlers
  void _handleFAQ() {
    _showFAQDialog();
  }

  void _handleVideoTutorials() async {
    final Uri youtubeUrl = Uri.parse('https://www.youtube.com/playlist?list=PLrAXtmRdnEQy9Q8w2a8rKt8i8uJc8i2Ld');

    if (await canLaunchUrl(youtubeUrl)) {
      await launchUrl(youtubeUrl, mode: LaunchMode.externalApplication);
    } else {
      _showErrorDialog('Cannot Open', 'Could not open YouTube. Please visit our channel manually.');
    }
  }

  void _handleUserGuide() {
    _showHelpDialog(
      'User Guide',
      [
        _buildHelpItem('Navigation', 'Use bottom navigation to access main sections'),
        _buildHelpItem('Search', 'Find books and videos using the search bar'),
        _buildHelpItem('Categories', 'Browse content by categories'),
        _buildHelpItem('Reading Mode', 'Adjust font size and background color'),
        _buildHelpItem('Video Player', 'Control playback speed and quality'),
        _buildHelpItem('Bookmarks', 'Save your favorite pages and sections'),
      ],
      'For detailed guides, visit our YouTube channel.',
    );
  }

  // Feedback Handlers
  void _handleReportBug() {
    _showFeedbackDialog('Bug Report');
  }

  void _handleFeatureRequest() {
    _showFeedbackDialog('Feature Request');
  }

  void _handleRateApp() async {
    _showRatingDialog();
  }

  // Helper Methods
  Widget _buildHelpItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6, right: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(String title, List<Widget> helpItems, String description) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedInformationCircle,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (description.isNotEmpty) ...[
                Text(
                  description,
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ...helpItems,
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Got it!'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWhatsAppChat() async {
    final Uri whatsappUrl = Uri.parse('https://wa.me/60123456789?text=Hi! I need help with Maktabah Ruwaq Jawi app.');

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      _showErrorDialog('WhatsApp', 'Could not open WhatsApp. Please install the app or contact us via email.');
    }
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Contact Us',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 20),
              _buildContactOption(
                'WhatsApp',
                'Fast response time',
                PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill),
                Colors.green,
                () async {
                  Navigator.of(context).pop();
                  final Uri whatsappUrl = Uri.parse('https://wa.me/60123456789?text=Hi! I need help with Maktabah Ruwaq Jawi app.');
                  if (await canLaunchUrl(whatsappUrl)) {
                    await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              _buildContactOption(
                'Phone',
                '+60 123-456-789',
                PhosphorIcons.phone(PhosphorIconsStyle.fill),
                AppTheme.primaryColor,
                () async {
                  Navigator.of(context).pop();
                  final Uri phoneLaunchUri = Uri(scheme: 'tel', path: '+60123456789');
                  if (await canLaunchUrl(phoneLaunchUri)) {
                    await launchUrl(phoneLaunchUri);
                  }
                },
              ),
              _buildContactOption(
                'Email',
                'support@ruwaqjawi.com',
                PhosphorIcons.envelope(PhosphorIconsStyle.fill),
                Colors.orange,
                () async {
                  Navigator.of(context).pop();
                  final Uri emailLaunchUri = Uri(
                    scheme: 'mailto',
                    path: 'support@ruwaqjawi.com',
                    query: 'subject=Support Request - Maktabah Ruwaq Jawi',
                  );
                  if (await canLaunchUrl(emailLaunchUri)) {
                    await launchUrl(emailLaunchUri);
                  }
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactOption(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderColor),
              borderRadius: BorderRadius.circular(12),
              color: Colors.transparent,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: PhosphorIcon(
                      icon,
                      color: color,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                PhosphorIcon(
                  PhosphorIcons.caretRight(),
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFAQDialog() {
    final faqs = [
      {
        'question': 'How do I subscribe to premium?',
        'answer': 'Go to Profile → Subscription → Choose Plan → Complete Payment.'
      },
      {
        'question': 'Can I use the app for free?',
        'answer': 'Yes! Basic features are free. Premium unlocks all content and features.'
      },
      {
        'question': 'How do I reset my password?',
        'answer': 'On the login screen, tap "Forgot Password" and follow the instructions.'
      },
      {
        'question': 'Is my payment information secure?',
        'answer': 'Yes, we use ToyyibPay, a secure payment gateway compliant with Malaysian regulations.'
      },
      {
        'question': 'Can I use the app offline?',
        'answer': 'Some features work offline, but internet is required for syncing and new content.'
      },
    ];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Frequently Asked Questions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: faqs.length,
                  itemBuilder: (context, index) {
                    final faq = faqs[index];
                    return ExpansionTile(
                      title: Text(
                        faq['question']!,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                          fontSize: 14,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            faq['answer']!,
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFeedbackDialog(String type) {
    final TextEditingController feedbackController = TextEditingController();
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: type == 'Bug Report'
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: PhosphorIcon(
                        type == 'Bug Report'
                          ? PhosphorIcons.bug(PhosphorIconsStyle.fill)
                          : PhosphorIcons.lightbulb(PhosphorIconsStyle.fill),
                        color: type == 'Bug Report' ? Colors.red : Colors.blue,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      type,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Your Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: feedbackController,
                decoration: InputDecoration(
                  labelText: type == 'Bug Report' ? 'Describe the bug' : 'Describe your feature request',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  hintText: type == 'Bug Report'
                    ? 'What happened? What did you expect to happen?'
                    : 'What feature would you like to see?',
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (feedbackController.text.trim().isNotEmpty &&
                            emailController.text.trim().isNotEmpty) {
                          Navigator.of(context).pop();

                          // Send feedback via email
                          final subject = Uri.encodeComponent('$type - Maktabah Ruwaq Jawi');
                          final body = Uri.encodeComponent(
                            'From: ${emailController.text}\n\n${type == 'Bug Report' ? 'Bug Report:' : 'Feature Request:'}\n\n${feedbackController.text}',
                          );

                          final Uri emailLaunchUri = Uri.parse(
                            'mailto:support@ruwaqjawi.com?subject=$subject&body=$body',
                          );

                          if (await canLaunchUrl(emailLaunchUri)) {
                            await launchUrl(emailLaunchUri);
                          }

                          _showSuccessDialog(type, 'Thank you! Your feedback has been sent to our team.');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRatingDialog() {
    int rating = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rate Our App',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'How would you rate your experience?',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      onPressed: () {
                        setState(() {
                          rating = index + 1;
                        });
                      },
                      icon: PhosphorIcon(
                        rating > index
                          ? PhosphorIcons.star(PhosphorIconsStyle.fill)
                          : PhosphorIcons.star(),
                        color: rating > index ? Colors.amber : Colors.grey,
                        size: 32,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Maybe Later'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: rating > 0 ? () {
                          Navigator.of(context).pop();
                          if (rating >= 4) {
                            _showSuccessDialog('Thank You!', 'We\'re glad you enjoy our app!');
                          } else {
                            _showContactDialog();
                          }
                        } : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Submit'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
          color: Colors.green,
          size: 48,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
          color: Colors.red,
          size: 48,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _performSearch(String query) {
    final allTopics = [
      {'title': 'Getting Started', 'handler': _handleGettingStarted},
      {'title': 'How to Subscribe', 'handler': _handleHowToSubscribe},
      {'title': 'Payment Issues', 'handler': _handlePaymentIssues},
      {'title': 'Account Settings', 'handler': _handleAccountSettings},
      {'title': 'FAQ', 'handler': _handleFAQ},
      {'title': 'Video Tutorials', 'handler': _handleVideoTutorials},
      {'title': 'User Guide', 'handler': _handleUserGuide},
      {'title': 'Report a Bug', 'handler': _handleReportBug},
      {'title': 'Feature Request', 'handler': _handleFeatureRequest},
      {'title': 'Rate App', 'handler': _handleRateApp},
    ];

    final matches = allTopics.where((topic) {
      return topic['title']!.toString().toLowerCase().contains(query.toLowerCase());
    }).toList();

    if (matches.isNotEmpty) {
      _showSearchResults(query, matches);
    } else {
      _showSearchResults(query, []);
    }
  }

  void _showSearchResults(String query, List<Map<String, dynamic>> results) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedSearch01,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Search Results',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedSearchRemove,
                      color: AppTheme.textSecondaryColor,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Showing results for: "$query"',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedSearch01,
                              color: AppTheme.textSecondaryColor,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No results found',
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try searching with different keywords',
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final result = results[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedInformationCircle,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                              ),
                            ),
                            title: Text(
                              result['title']!,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimaryColor,
                                fontSize: 15,
                              ),
                            ),
                            trailing: HugeIcon(
                              icon: HugeIcons.strokeRoundedArrowRight01,
                              color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
                              size: 16,
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              result['handler']();
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}