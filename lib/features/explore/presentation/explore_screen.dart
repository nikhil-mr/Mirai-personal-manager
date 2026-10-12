import 'package:flutter/material.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/feature_card.dart';
import '../../../core/widgets/page_container.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) => PageContainer(
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A little more room for life.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 720 ? 2 : 1;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: columns == 2 ? 1.22 : 1.35,
                children: const [
                  FeatureCard(
                    icon: Icons.map_outlined,
                    title: 'Places & Trips',
                    description: 'Save destinations, organize trips, open places in Maps, and keep trip expenses connected to Money.',
                    route: AppRoutes.places,
                    tint: AppColors.brand,
                  ),
                  FeatureCard(
                    icon: Icons.shopping_basket_outlined,
                    title: 'Grocery Basket',
                    description: 'Keep grocery baskets, track quantities and purchases, and connect spending to Money.',
                    route: AppRoutes.groceries,
                    tint: AppColors.warning,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
