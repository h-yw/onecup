import 'package:flutter/material.dart';
import 'package:onecup/database/database_helper.dart';

class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Future<List<Map<String, dynamic>>>? _recommendationsFuture;

  @override
  void initState() {
    super.initState();
    _recommendationsFuture = _dbHelper.getPurchaseRecommendations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('下一步买什么'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _recommendationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('计算推荐失败: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  '恭喜！根据您现有的库存，我们暂时没有发现能显著增加可调配方数量的单一购买建议。您可能已经拥有一个非常全面的酒柜了！',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ),
            );
          }

          final recommendations = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: recommendations.length,
            itemBuilder: (context, index) {
              final item = recommendations[index];
              final String name = item['name'];
              final int unlocks = item['unlocks'];

              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      '#${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    '购买 $name',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 18),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '即可解锁 $unlocks 款全新鸡尾酒！',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}