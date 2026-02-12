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
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        ],
      ),
      body: ListView.separated(
        itemCount: users.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final user = users[index];
          final isBanned = user['status'] == 'BANNED';
          
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isBanned ? Colors.red[100] : Colors.blue[100],
              child: Text((user['name'] as String)[0]),
            ),
            title: Text(user['name'] as String),
            subtitle: Text(user['email'] as String),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (user['role'] == 'ADMIN')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('ADMIN', style: TextStyle(fontSize: 10, color: Colors.purple)),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    isBanned ? Icons.lock_open : Icons.block,
                    color: isBanned ? Colors.green : Colors.red,
                  ),
                  tooltip: isBanned ? 'Unban User' : 'Ban User',
                  onPressed: () {
                    // TODO: Implement ban/unban
                  },
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'view', child: Text('View Profile')),
                    const PopupMenuItem(value: 'role', child: Text('Change Role')),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
