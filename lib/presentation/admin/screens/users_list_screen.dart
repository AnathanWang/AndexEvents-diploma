import 'package:flutter/material.dart';

class UsersListScreen extends StatelessWidget {
  const UsersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data
    final users = List.generate(10, (index) => {
      'id': 'user_$index',
      'email': 'user$index@example.com',
      'name': 'User $index',
      'role': index == 0 ? 'ADMIN' : 'USER',
      'status': index == 2 ? 'BANNED' : 'ACTIVE',
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // App Bar with gradient
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xFF4ECDC4),
                      Color(0xFF44A08D),
                    ],
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Пользователи',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF4ECDC4)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),

          // Users list
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final user = users[index];
                  final isBanned = user['status'] == 'BANNED';
                  final isAdmin = user['role'] == 'ADMIN';
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isBanned
                                  ? [
                                      const Color(0xFFFF6B6B).withOpacity(0.2),
                                      const Color(0xFFFF8E53).withOpacity(0.2),
                                    ]
                                  : isAdmin
                                      ? [
                                          const Color(0xFF5E60CE).withOpacity(0.2),
                                          const Color(0xFF9370DB).withOpacity(0.2),
                                        ]
                                      : [
                                          const Color(0xFF4ECDC4).withOpacity(0.2),
                                          const Color(0xFF44A08D).withOpacity(0.2),
                                        ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              (user['name'] as String)[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isBanned
                                    ? const Color(0xFFFF6B6B)
                                    : isAdmin
                                        ? const Color(0xFF5E60CE)
                                        : const Color(0xFF4ECDC4),
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          user['name'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A4D6A),
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              user['email'] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF9E9E9E),
                              ),
                            ),
                            if (isBanned || isAdmin) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isBanned
                                        ? [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)]
                                        : [const Color(0xFF5E60CE), const Color(0xFF9370DB)],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isBanned ? 'ЗАБЛОКИРОВАН' : 'АДМИН',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: isBanned
                                    ? const Color(0xFF4ECDC4).withOpacity(0.1)
                                    : const Color(0xFFFF6B6B).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  isBanned ? Icons.lock_open_rounded : Icons.block_rounded,
                                  color: isBanned
                                      ? const Color(0xFF4ECDC4)
                                      : const Color(0xFFFF6B6B),
                                ),
                                tooltip: isBanned ? 'Разблокировать' : 'Заблокировать',
                                onPressed: () {},
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F2FB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Color(0xFF5E60CE),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'view',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person, color: Color(0xFF5E60CE)),
                                        SizedBox(width: 12),
                                        Text('Посмотреть профиль'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'role',
                                    child: Row(
                                      children: [
                                        Icon(Icons.admin_panel_settings, color: Color(0xFF5E60CE)),
                                        SizedBox(width: 12),
                                        Text('Изменить роль'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: users.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
