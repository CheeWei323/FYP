import 'package:flutter/material.dart';

import '../../services/content_manager_service.dart';
import '../content_manager/manage_travel_rules_screen.dart';

class ContentManagerDashboard
    extends StatefulWidget {
  const ContentManagerDashboard({
    super.key,
  });

  @override
  State<ContentManagerDashboard>
  createState() =>
      _ContentManagerDashboardState();
}

class _ContentManagerDashboardState
    extends State<ContentManagerDashboard> {
  final ContentManagerService
  _contentManagerService =
  ContentManagerService();

  static const Color _primaryColor =
  Color(0xFF087F8C);

  static const Color _darkTextColor =
  Color(0xFF102A43);

  static const Color _backgroundColor =
  Color(0xFFF7F9FB);

  static const Color _borderColor =
  Color(0xFFE1E7EC);

  late Future<Map<String, int>>
  _overviewFuture;

  @override
  void initState() {
    super.initState();

    _overviewFuture =
        _contentManagerService
            .getOverview();
  }

  Future<void> _refresh() async {
    final Future<Map<String, int>>
    future =
    _contentManagerService
        .getOverview();

    setState(() {
      _overviewFuture = future;
    });

    await future;
  }

  Future<void>
  _openTravelRegulations()
  async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
        const ManageTravelRulesScreen(),
      ),
    );

    if (!mounted) return;

    await _refresh();
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      _backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading:
        false,
        backgroundColor:
        Colors.white,
        surfaceTintColor:
        Colors.white,
        elevation: 0,
        title: const Text(
          'Content Manager',
          style: TextStyle(
            color:
            _darkTextColor,
            fontWeight:
            FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding:
          const EdgeInsets.fromLTRB(
            18,
            18,
            18,
            36,
          ),
          children: [
            _buildWelcomeCard(),

            const SizedBox(
              height: 26,
            ),

            const Text(
              'System Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.w800,
                color:
                _darkTextColor,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            _buildOverview(),

            const SizedBox(
              height: 28,
            ),

            const Text(
              'Content Management',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.w800,
                color:
                _darkTextColor,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            _buildManagementCard(
              icon:
              Icons.policy_outlined,
              title:
              'Manage Travel Regulations',
              description:
              'Review destination requirements, '
                  'duration rules, travel purposes and '
                  'official authority references.',
              actionText:
              'View Regulations',
              onTap:
              _openTravelRegulations,
            ),

            const SizedBox(
              height: 12,
            ),

            const SizedBox(
              height: 28,
            ),

            const Text(
              'Management Controls',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.w800,
                color:
                _darkTextColor,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            _buildInformationCard(
              icon:
              Icons.verified_outlined,
              title:
              'Regulation Publishing',
              description:
              'New regulations are created as inactive. '
                  'After reviewing the information and official source, '
                  'the rule can be enabled for future traveller checklists.',
            ),

            const SizedBox(
              height: 12,
            ),

            _buildInformationCard(
              icon:
              Icons.link_outlined,
              title:
              'Official Source Management',
              description:
              'Each regulation stores an official authority, '
                  'reference URL and validation date to support '
                  'regulatory traceability.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient:
        const LinearGradient(
          colors: [
            Color(0xFFE7F7F8),
            Color(0xFFF1F8FB),
          ],
          begin:
          Alignment.topLeft,
          end:
          Alignment.bottomRight,
        ),
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color:
          const Color(
            0xFFCBE8EB,
          ),
        ),
      ),
      child: const Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          ContainerIcon(),

          SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  'TravelGuard MY',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight:
                    FontWeight.w800,
                    color:
                    _darkTextColor,
                  ),
                ),

                SizedBox(height: 6),

                Text(
                  'Maintain validated travel preparation '
                      'information and official regulatory references.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color:
                    Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    return FutureBuilder<
        Map<String, int>>(
      future: _overviewFuture,
      builder: (
          context,
          snapshot,
          ) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return Container(
            height: 120,
            decoration:
            BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius
                  .circular(
                18,
              ),
              border: Border.all(
                color:
                _borderColor,
              ),
            ),
            child: const Center(
              child:
              CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding:
            const EdgeInsets.all(
              18,
            ),
            decoration:
            BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius
                  .circular(
                18,
              ),
              border: Border.all(
                color:
                _borderColor,
              ),
            ),
            child: const Text(
              'Unable to load system overview.',
              textAlign:
              TextAlign.center,
            ),
          );
        }

        final Map<String, int>
        overview =
            snapshot.data ?? {};

        final int countries =
            overview[
            'enabledCountries'] ??
                0;

        final int rules =
            overview['rules'] ?? 0;

        final int active =
            overview[
            'activeRules'] ??
                0;

        return Row(
          children: [
            Expanded(
              child:
              _buildOverviewCard(
                icon:
                Icons.public_outlined,
                value:
                '$countries',
                label:
                'Destinations',
              ),
            ),

            const SizedBox(
              width: 10,
            ),

            Expanded(
              child:
              _buildOverviewCard(
                icon:
                Icons.list_alt_outlined,
                value:
                '$rules',
                label:
                'Travel Rules',
              ),
            ),

            const SizedBox(
              width: 10,
            ),

            Expanded(
              child:
              _buildOverviewCard(
                icon: Icons
                    .check_circle_outline_rounded,
                value:
                '$active',
                label:
                'Active Rules',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOverviewCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color: _borderColor,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color:
            _primaryColor,
            size: 23,
          ),

          const SizedBox(
            height: 7,
          ),

          Text(
            value,
            style:
            const TextStyle(
              fontSize: 20,
              fontWeight:
              FontWeight.w800,
              color:
              _darkTextColor,
            ),
          ),

          const SizedBox(
            height: 3,
          ),

          Text(
            label,
            textAlign:
            TextAlign.center,
            style:
            const TextStyle(
              fontSize: 10.5,
              color:
              Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementCard({
    required IconData icon,
    required String title,
    required String description,
    required String actionText,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(18),
        child: Ink(
          padding:
          const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius
                .circular(
              18,
            ),
            border: Border.all(
              color:
              _borderColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration:
                BoxDecoration(
                  color:
                  const Color(
                    0xFFE8F6F7,
                  ),
                  borderRadius:
                  BorderRadius
                      .circular(
                    15,
                  ),
                ),
                child: Icon(
                  icon,
                  color:
                  _primaryColor,
                  size: 25,
                ),
              ),

              const SizedBox(
                width: 15,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      title,
                      style:
                      const TextStyle(
                        fontSize: 16,
                        fontWeight:
                        FontWeight
                            .w700,
                        color:
                        _darkTextColor,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      description,
                      style:
                      const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color:
                        Colors.black54,
                      ),
                    ),

                    const SizedBox(
                      height: 9,
                    ),

                    Text(
                      actionText,
                      style:
                      const TextStyle(
                        fontSize: 13,
                        fontWeight:
                        FontWeight
                            .w700,
                        color:
                        _primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons
                    .chevron_right_rounded,
                color:
                Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInformationCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding:
      const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: _borderColor,
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
            BoxDecoration(
              color:
              const Color(
                0xFFE8F6F7,
              ),
              borderRadius:
              BorderRadius.circular(
                14,
              ),
            ),
            child: Icon(
              icon,
              color:
              _primaryColor,
              size: 24,
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                  const TextStyle(
                    fontSize: 15,
                    fontWeight:
                    FontWeight.w700,
                    color:
                    _darkTextColor,
                  ),
                ),

                const SizedBox(
                  height: 6,
                ),

                Text(
                  description,
                  style:
                  const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color:
                    Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding:
            EdgeInsets.only(
              top: 3,
            ),
            child: Icon(
              Icons
                  .check_circle_outline_rounded,
              color:
              Color(
                0xFF177245,
              ),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class ContainerIcon
    extends StatelessWidget {
  const ContainerIcon({
    super.key,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(
          15,
        ),
      ),
      child: const Icon(
        Icons
            .admin_panel_settings_outlined,
        color:
        Color(
          0xFF087F8C,
        ),
        size: 28,
      ),
    );
  }
}