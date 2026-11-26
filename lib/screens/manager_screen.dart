import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../services/sync_provider.dart';
import 'login_screen.dart';

class ManagerScreen extends StatelessWidget {
  final SyncProvider syncProvider;

  const ManagerScreen({super.key, required this.syncProvider});

  @override
  Widget build(BuildContext context) {
    final myStores = syncProvider.stores.where((s) => s.ownerId == syncProvider.currentOwnerId).toList();
    final myStoreIds = myStores.map((s) => s.storeId).toSet();
    final myOrders = syncProvider.orders.where((o) => myStoreIds.contains(o.storeId)).toList().reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Retail Hub Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              syncProvider.currentUser = null;
              syncProvider.currentUserId = null;
              syncProvider.currentOwnerId = null;
              syncProvider.currentUserRole = null;
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen(syncProvider: syncProvider, role: 'provider')));
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: syncProvider,
        builder: (context, _) {
          if (syncProvider.isLoading && myStores.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (myStores.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('No stores assigned to your account. Tap + to add one.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverToBoxAdapter(child: Text('My Stores & Inventory', style: DesignTokens.textTheme.titleLarge)),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildStoreCard(context, myStores[index]),
                  childCount: myStores.length,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverToBoxAdapter(child: Text('Recent Reservations', style: DesignTokens.textTheme.titleLarge)),
              ),
              myOrders.isEmpty
                  ? const SliverToBoxAdapter(
                  child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('No reservations yet.', style: TextStyle(color: Colors.grey))
                  )
              )
                  : SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildOrderLogCard(myOrders[index]),
                  childCount: myOrders.length,
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: DesignTokens.primary,
        onPressed: () => _showAddOptions(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildOrderLogCard(OrderLog order) {
    final product = syncProvider.products.firstWhere(
            (p) => p.productId == order.productId || p.sku == order.productId,
        orElse: () => Product(productId: order.productId, sku: '', name: 'Unknown Item', price: 0, stockCount: 0)
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: DesignTokens.accent, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Customer: ${order.customerName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(order.timestamp.split('T').first, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Reserved: ${product.name} (Qty: ${order.quantity})', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.timer, color: DesignTokens.accent, size: 14),
              const SizedBox(width: 4),
              Text('ETA Penalty Window: ${order.eta} Hour(s)', style: const TextStyle(color: DesignTokens.accent, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoreCard(BuildContext context, Store store) {
    List<Widget> storeChildren = syncProvider.products
        .where((p) => p.owner.trim() == syncProvider.currentOwnerId?.trim())
        .map((product) {

      final effectiveId = product.productId.isNotEmpty ? product.productId : product.sku;
      final inv = syncProvider.inventory.firstWhere(
            (i) {
          bool storeMatch = i.storeId.trim() == store.storeId.trim();
          bool exactMatch = effectiveId.isNotEmpty && i.productId.trim() == effectiveId.trim();
          bool skuMatch = product.sku.isNotEmpty && i.productId.trim() == product.sku.trim();
          return storeMatch && (exactMatch || skuMatch);
        },
        orElse: () => Inventory(invId: '', storeId: store.storeId, productId: effectiveId, quantity: 0),
      );

      final exactId = inv.productId.isNotEmpty ? inv.productId : effectiveId;
      return _buildInventoryRow(context, store.storeId, product, inv.quantity, exactId);
    }).toList();

    // NEW: "Add Local Product" and "Delete Store" buttons side by side
    storeChildren.add(
      Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0, top: 8.0),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showAddProductDialog(context, store: store),
                icon: const Icon(Icons.add, color: DesignTokens.primary),
                label: const Text('Add Local Product', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: DesignTokens.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: DesignTokens.borderRadiusSmall),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () => _confirmDeleteStore(context, store),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: DesignTokens.borderRadiusSmall),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );

    return Card(
      color: DesignTokens.surface,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: DesignTokens.borderRadiusMedium,
        side: const BorderSide(color: DesignTokens.surfaceElevated, width: 1),
      ),
      child: ExpansionTile(
        key: PageStorageKey(store.storeId),
        title: Text(store.storeName, style: DesignTokens.textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(store.address, style: DesignTokens.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
            if (store.helpline.isNotEmpty && store.helpline != 'N/A')
              Text('☎ ${store.helpline}', style: const TextStyle(color: DesignTokens.accent, fontSize: 12)),
          ],
        ),
        leading: const Icon(Icons.store, color: DesignTokens.primary),
        children: storeChildren,
      ),
    );
  }

  Widget _buildInventoryRow(BuildContext context, String storeId, Product product, int currentStock, String exactId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(product.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    // NEW: Product Delete Trash Icon
                    InkWell(
                      onTap: () => _confirmDeleteProduct(context, product, exactId),
                      child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                    )
                  ],
                ),
                const SizedBox(height: 2),
                Text('SKU: ${product.sku} | \$${product.price}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: DesignTokens.error),
                onPressed: currentStock > 0
                    ? () => syncProvider.updateInventory(storeId, exactId, currentStock - 1)
                    : null,
              ),
              Text(
                currentStock.toString(),
                style: TextStyle(color: currentStock > 0 ? DesignTokens.accent : DesignTokens.error, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                onPressed: () => syncProvider.updateInventory(storeId, exactId, currentStock + 1),
              ),
            ],
          )
        ],
      ),
    );
  }

  // --- NEW: Confirmation Dialogs for Safety ---

  void _confirmDeleteStore(BuildContext context, Store store) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DesignTokens.surface,
        title: const Text('Delete Store?', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete ${store.storeName}? This cannot be undone.', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await syncProvider.deleteStore(store.storeId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _confirmDeleteProduct(BuildContext context, Product product, String exactId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DesignTokens.surface,
        title: const Text('Delete Product?', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to permanently delete ${product.name}? It will be removed from all stores.', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await syncProvider.deleteProduct(exactId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // --- Existing Dialogs Below ---

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DesignTokens.surface,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.store, color: DesignTokens.primary),
                title: const Text('Add New Store', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showAddStoreDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.inventory, color: DesignTokens.accent),
                title: const Text('Add New Product', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showAddProductDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddStoreDialog(BuildContext context) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    final helplineController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: DesignTokens.surface,
          title: const Text('Add Store Location', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Store Name', labelStyle: TextStyle(color: Colors.grey))),
                TextField(controller: addressController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Address', labelStyle: TextStyle(color: Colors.grey))),
                TextField(controller: helplineController, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Helpline Number', labelStyle: TextStyle(color: Colors.grey))),
                TextField(controller: latController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Latitude (e.g. 22.76)', labelStyle: TextStyle(color: Colors.grey))),
                TextField(controller: lngController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Longitude (e.g. 88.37)', labelStyle: TextStyle(color: Colors.grey))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                final success = await syncProvider.addStore(
                  nameController.text,
                  addressController.text,
                  double.tryParse(latController.text) ?? 0.0,
                  double.tryParse(lngController.text) ?? 0.0,
                  helplineController.text,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(success ? 'Store added successfully!' : 'Failed to add store.'),
                    backgroundColor: success ? Colors.green.shade700 : DesignTokens.error,
                  ));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.primary),
              child: const Text('Save Store', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showAddProductDialog(BuildContext context, {Store? store}) {
    final nameController = TextEditingController();
    final skuController = TextEditingController();
    final descController = TextEditingController();
    final categoryController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: DesignTokens.surface,
          title: Text(store != null ? 'Add Local Product' : 'Add Global Product', style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Product Name', labelStyle: TextStyle(color: Colors.grey))),
                TextField(controller: skuController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'SKU (e.g. D003)', labelStyle: TextStyle(color: Colors.grey))),
                TextField(controller: descController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Description', labelStyle: TextStyle(color: Colors.grey))),
                TextField(controller: categoryController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Category', labelStyle: TextStyle(color: Colors.grey))),
                TextField(controller: priceController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Price', labelStyle: TextStyle(color: Colors.grey))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                final success = await syncProvider.addProduct(
                  skuController.text,
                  nameController.text,
                  descController.text,
                  categoryController.text,
                  double.tryParse(priceController.text) ?? 0.0,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(success ? 'Product added successfully!' : 'Failed to add product.'),
                    backgroundColor: success ? Colors.green.shade700 : DesignTokens.error,
                  ));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.primary),
              child: const Text('Save Product', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}