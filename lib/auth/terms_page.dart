import 'package:flutter/material.dart';

class TermsPage extends StatefulWidget {
  final VoidCallback onAccept;

  const TermsPage({super.key, required this.onAccept});

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  final ScrollController _scrollController = ScrollController();

  bool accepted = false;
  bool hasScrolledToBottom = false;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 20) {
        if (!hasScrolledToBottom) {
          setState(() => hasScrolledToBottom = true);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get canProceed => accepted && hasScrolledToBottom;

  void _handleAccept() {
    if (!canProceed) return;
    widget.onAccept();
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Terms & Conditions")),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Food Oasis Terms & Conditions",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Last Updated: April 14, 2026",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "By creating an account and using Food Oasis, you agree to these Terms. If you do not agree, please do not use the Service.",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  _section(
                    "1. Eligibility",
                    "You must be at least 18 years old.",
                  ),

                  _section(
                    "2. Location Services",
                    "Food Oasis may request access to your device location to show nearby sellers and listings. Location is used only for platform functionality. You may disable location, but some features may be limited as a result. You acknowledge responsibility for enabling or disabling permissions.",
                  ),

                  _section(
                    "3. Marketplace Role",
                    "Food Oasis is a neutral marketplace connecting users. We do not prepare, inspect, store, or deliver food. We are not a party to transactions between users. We do not guarantee listings, users, or outcomes. All transactions occur directly between users at their own risk. By accepting, you acknowledge that Food Oasis is not liable for any issues arising from transactions, including but not limited to food safety, legality, or disputes.",
                  ),

                  _section(
                    "4. Buyer Risk",
                    "As a buyer, you agree that:\n"
                    "• You are responsible for reviewing listings before purchase or reservation.\n"
                    "• You assume all risks related to food consumption, including allergies, illness, or injury.\n"
                    "• Food Oasis is not responsible for disputes, refunds, or product quality.\n"
                    "• You are responsible for communication and coordination with sellers.",
                  ),

                  _section(
                    "5. Seller Responsibility",
                    "As a seller, you agree that:\n"
                    "• You are fully responsible for all items you list or sell.\n"
                    "• You will not sell expired, unsafe, contaminated, or misleading items.\n"
                    "• You must comply with all applicable food safety laws and regulations.\n"
                    "• You are responsible for proper handling, storage, and preparation of food.\n"
                    "• You are responsible for fulfilling accepted orders or reservations.\n"
                    "• You may be liable for any harm caused by your products or actions.",
                  ),

                  _section(
                    "6. Health & Safety",
                    "Users acknowledge that food transactions carry inherent risks, including but not limited to:\n"
                    "• Foodborne illness or contamination\n"
                    "• Allergic reactions\n"
                    "• Injury or accidents during pickup or interaction\n"
                    "• Criminal or harmful behavior by other users\n\n"
                    "Food Oasis is not responsible for any such incidents.",
                  ),

                  _section(
                    "7. User Conduct",
                    "You agree not to:\n"
                    "• Post false, misleading, or fraudulent listings or reviews\n"
                    "• Sell illegal or prohibited items\n"
                    "• Harass, threaten, or abuse other users\n"
                    "• Engage in discrimination of any kind, including but not limited to race, ethnicity, national origin, gender, gender identity, sexual orientation, religion, disability, age, or socioeconomic status\n"
                    "• Use hate speech, slurs, or content intended to intimidate, degrade, or dehumanize individuals or groups\n"
                    "• Circumvent platform systems or policies\n"
                    "• Use the Service for unlawful purposes\n\n"
                    "Violation may result in account suspension or termination.",
                  ),

                  _section(
                    "8. Account Security",
                    "You are responsible for maintaining the confidentiality of your account and password. You agree to notify Food Oasis immediately of any unauthorized use of your account. Food Oasis is not liable for any loss or damage arising from your failure to comply with this security obligation.",
                  ),

                  _section(
                    "9. Payment & Transactions",
                    "Food Oasis may enable transactions between users. Food Oasis can not guarantee payment or fulfillment. Disputes must be resolved between users unless otherwise stated in policy. Food Oasis may not mediate or reverse transactions.",
                  ),

                  _section(
                    "10. Limitation of Liability",
                    "To the fullest extent permitted by law, Food Oasis and its affiliates shall not be liable for any indirect, incidental, special, consequential, or punitive damages, or any loss of profits or revenues, whether incurred directly or indirectly, or any loss of data, use, goodwill, or other intangible losses, resulting from (i) your access to or use of or inability to access or use the Service; (ii) any conduct or content of any third party on the Service; (iii) any content obtained from the Service; and (iv) unauthorized access, use, or alteration of your transmissions or content. In no event shall Food Oasis's total liability to you for all damages, losses, and causes of action exceed the amount paid by you, if any, for accessing the Service. The limitations of this section shall apply even if Food Oasis has been advised of the possibility of such damages. Food Oasis is not liable for injury, illness, or harm resulting from use of the platform, including but not limited to foodborne illness, allergic reactions, or accidents during pickup. By accepting these terms, you acknowledge and assume all risks associated with using Food Oasis."
                  ),

                  _section(
                    "11. Termination",
                    "Food Oasis may suspend or terminate accounts that violate these Terms or harm the platform or other users."
                  ),

                  _section(
                    "12. Updates to Terms",
                    "Food Oasis may update these Terms at any time. Continued use of the Service constitutes acceptance of changes."
                  ),

                  _section(
                    "13. Agreement",
                    "By accepting, you acknowledge that you have read, understood, and agree to be bound by these Terms & Conditions. If you do not agree, please do not use Food Oasis."
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: accepted,
                      onChanged: (value) {
                        setState(() => accepted = value ?? false);
                      },
                    ),
                    const Expanded(
                      child: Text(
                        "I agree to the Terms & Conditions",
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: canProceed ? _handleAccept : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                    child: const Text("Continue"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}