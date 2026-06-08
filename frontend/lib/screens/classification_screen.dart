import 'package:flutter/material.dart';
import 'package:frontend/providers/category_provider.dart';
import 'package:frontend/providers/tag_assignment_provider.dart';
import 'package:frontend/providers/tag_provider.dart';
import 'package:frontend/screens/assigned_connections_screen.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../models/tag.dart';

class ClassificationScreen extends StatefulWidget {
  const ClassificationScreen({super.key});

  @override
  State<ClassificationScreen> createState() => _ClassificationScreenState();
}

class _ClassificationScreenState extends State<ClassificationScreen> {
  @override
  void initState() {
    super.initState();
Future.microtask(() {
      Provider.of<CategoryProvider>(context, listen: false).fetchCategories();
      Provider.of<TagProvider>(context, listen: false).fetchTags();
    });
}

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
}

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sınıflandırma'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.category), text: 'Kategoriler'),
               Tab(icon: Icon(Icons.label), text: 'Etiketler'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            CategoryView(onError: _showErrorSnackBar),
            TagView(onError: _showErrorSnackBar),
          ],
        
),
      ),
    );
}
}

// MARK: - Category View
class CategoryView extends StatelessWidget {
  final Function(String) onError;
  const CategoryView({super.key, required this.onError});
void _showAddCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Kategori Ekle'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Kategori Adı'),
          autofocus: true,
        ),
        actions: [
          
TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              try {
                await Provider.of<CategoryProvider>(context, listen: false)
                   .addCategory(nameController.text);
                if (!context.mounted) return;
                Navigator.of(ctx).pop();
              } catch (e) {
                onError('Kategori eklenemedi: ${e.toString()}');
                Navigator.of(ctx).pop();
              
}
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<CategoryProvider>(
        builder: (ctx, categoryProvider, child) =>
            categoryProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: 
() => categoryProvider.fetchCategories(),
                    child: ListView.builder(
                      itemCount: categoryProvider.categories.length,
                      itemBuilder: (ctx, i) {
                        final Category category = categoryProvider.categories[i];
 
                        return ListTile(
                          title: Text(category.name),
                          trailing: IconButton(
                      
icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              try {
                            
await categoryProvider.deleteCategory(category.categoryId);
                              } catch (e) {
                                onError('Kategori silinemedi: ${e.toString()}');
}
                            },
                          ),
                        );
},
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(context),
        child: const Icon(Icons.add),
      ),
    );
}
}

// MARK: - Tag View
class TagView extends StatelessWidget {
  final Function(String) onError;
  const TagView({super.key, required this.onError});
void _showTagDialog(BuildContext context, {Tag? tag}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: tag?.name);
final noteController = TextEditingController(text: tag?.note);
    final percentageController = TextEditingController(text: tag?.pricingPercentage?.toString());
    final deltaController = TextEditingController(text: tag?.pricingDelta?.toString());
showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tag == null ? 'Yeni Etiket Ekle' : 'Etiketi Düzenle'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
       
children: [
                TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Etiket Adı'),
                    validator: (val) => val!.isEmpty ? 'Gerekli' : null),
    
            TextFormField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Not')),
                TextFormField(
                    controller: percentageController,
       
             decoration: const InputDecoration(labelText: 'Fiyat Yüzdesi (%)', hintText: 'Örn: -10.5 veya 5'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true)),
                TextFormField(
                    controller: deltaController,
               
     decoration: const InputDecoration(labelText: 'Fiyat Farkı (₺)', hintText: 'Örn: -8 veya 15.5'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true)),
              ],
            ),
          ),
        ),
        actions: [
       
   TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
final double? percentage = double.tryParse(percentageController.text);
              final double? delta = double.tryParse(deltaController.text);
              final tagProvider = Provider.of<TagProvider>(context, listen: false);
try {
                if (tag == null) {
                  await tagProvider.addTag(nameController.text, noteController.text, percentage, delta);
} else {
                  await tagProvider.updateTag(tag.tagId, nameController.text, noteController.text, percentage, delta);
}
                if (!context.mounted) return;
                Navigator.of(ctx).pop();
} catch (e) {
                 onError('Etiket kaydedilemedi: ${e.toString()}');
Navigator.of(ctx).pop();
              }
            },
            child: Text(tag == null ? 'Ekle' : 'Güncelle'),
          ),
        ],
      ),
    );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<TagProvider>(
        builder: (ctx, tagProvider, child) =>
            tagProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: 
() => tagProvider.fetchTags(),
                    child: ListView.builder(
                      itemCount: tagProvider.tags.length,
                      itemBuilder: (ctx, i) {
                        final Tag tag = tagProvider.tags[i];
 
                        return ListTile(
                          title: Text(tag.name),
                          subtitle: Text(tag.note ?? ''),
                          onTap: () {
                             Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ChangeNotifierProvider.value(
                                    value: Provider.of<TagAssignmentProvider>(context, listen: false),
                                    child: AssignedConnectionsScreen(tag: tag),
                                ),
                            ));
                          },
                    
trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                                if (value == 'edit') {
                                    _showTagDialog(context, tag: tag);
                                } else if (value == 'delete') {
                                    showDialog(
                                        context: context,
                                        builder: (dialogCtx) => AlertDialog(
                                            title: const Text('Emin misiniz?'),
                                            content: Text('\'${tag.name}\' etiketini silmek üzeresiniz. Bu etiket tüm bağlantılardan kaldırılacaktır.'),
                                            actions: [
                                                TextButton(
                                                    onPressed: () => Navigator.of(dialogCtx).pop(),
                                                    child: const Text('İptal'),
                                                ),
                                                TextButton(
                                                    onPressed: () async {
                                                        try {
                                                            await tagProvider.deleteTag(tag.tagId);
                                                        } catch (e) {
                                                            onError('Etiket silinemedi: ${e.toString()}');
                                                        }
                                                        if (context.mounted) Navigator.of(dialogCtx).pop();
                                                    },
                                                    child: const Text('Sil', style: TextStyle(color: Colors.red)),
                                                ),
                                            ],
                                        ),
                                    );
                                }
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                const PopupMenuItem<String>(
                                    value: 'edit',
                                    child: ListTile(leading: Icon(Icons.edit), title: Text('Düzenle')),
                                ),
                                const PopupMenuItem<String>(
                                    value: 'delete',
                                    child: ListTile(leading: Icon(Icons.delete), title: Text('Sil')),
                                ),
                            ],
                          ),
                        );
},
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTagDialog(context),
        child: const Icon(Icons.add),
      ),
    );
}
}