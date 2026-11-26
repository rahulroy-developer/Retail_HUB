import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/design_tokens.dart';
import '../services/sync_provider.dart';
import '../services/distance_service.dart';
import 'login_screen.dart';

class CustomerScreen extends StatefulWidget {
  final SyncProvider syncProvider;

  const CustomerScreen({super.key, required this.syncProvider});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  String? selectedStoreId;
  Position? _currentPosition;
  bool _locationError = false;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location disabled');

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Permission denied');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permission denied forever');
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() => _currentPosition = position);
    } catch (e) {
      setState(() => _locationError = true);
    }
  }

  List<dynamic> _findAlternativeStores(Product product) {
    if (_currentPosition == null || selectedStoreId == null) return [];
    final currentStore = widget.syncProvider.stores.firstWhere((s) => s.storeId == selectedStoreId);
    final ownerId = currentStore.ownerId;

    final otherStores = widget.syncProvider.stores
        .where((s) => s.ownerId == ownerId && s.storeId != selectedStoreId).toList();
    var availableAlternatives = [];

    for (var store in otherStores) {
      final inv = widget.syncProvider.inventory.firstWhere(
            (i) => i.storeId == store.storeId &&
            (i.productId == product.productId || i.productId == product.sku),
        orElse: () => Inventory(invId: '', storeId: store.storeId, productId: product.productId, quantity: 0),
      );
      if (inv.quantity > 0) {
        final distance = DistanceService.calculateDistance(
            _currentPosition!.latitude, _currentPosition!.longitude,
            double.tryParse(store.latitude) ?? 0.0, double.tryParse(store.longitude) ?? 0.0
        );
        availableAlternatives.add({'store': store, 'distance': distance, 'quantity': inv.quantity});
      }
    }
    availableAlternatives.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    return availableAlternatives;
  }

  Future<void> _openDirections(String latStr, String lngStr) async {
    final lat = double.tryParse(latStr) ?? 0.0;
    final lng = double.tryParse(lngStr) ?? 0.0;
    final Uri googleMapsUrl = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    } else {
      final Uri webUrl = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng");
      await launchUrl(webUrl);
    }
  }

  void _showReservationDialog(Product product, int currentQty, Store store) {
    final hoursController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: DesignTokens.surface,
          title: const Text('Reserve Item', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Product: ${product.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Upfront Deposit: \$5.00', style: TextStyle(color: DesignTokens.accent, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: DesignTokens.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: DesignTokens.error.withOpacity(0.5))
                ),
                child: const Text(
                  'Policy: You must arrive within your selected ETA. If you arrive on time, this deposit adjusts against your final bill. If you miss the window, it is taken as a penalty fee.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: hoursController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Your ETA (in Hours)',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.primary),
              onPressed: () async {
                if(hoursController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an ETA.')));
                  return;
                }

                final effectiveProductId = product.productId.isNotEmpty ? product.productId : product.sku;

                // Deduct Inventory
                final success = await widget.syncProvider.updateInventory(store.storeId, effectiveProductId, currentQty - 1);

                if (success) {
                  // Fire the reservation log to the manager's dashboard
                  await widget.syncProvider.logReservation(store.storeId, effectiveProductId, 1, hoursController.text);
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(success ? 'Payment accepted! You have ${hoursController.text} hour(s) to arrive.' : 'Reservation failed.'),
                    backgroundColor: success ? Colors.green.shade700 : DesignTokens.error,
                  ));
                }
              },
              child: const Text('Pay \$5.00 & Reserve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Retail Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => LoginScreen(syncProvider: widget.syncProvider, role: 'customer')),
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.syncProvider,
        builder: (context, _) {
          if (widget.syncProvider.isLoading && widget.syncProvider.stores.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (widget.syncProvider.stores.isEmpty) {
            return const Center(child: Text("No stores available in the network.", style: TextStyle(color: Colors.grey)));
          }

          selectedStoreId ??= widget.syncProvider.stores.first.storeId;
          final currentStore = widget.syncProvider.stores.firstWhere((s) => s.storeId == selectedStoreId, orElse: () => widget.syncProvider.stores.first);
          final storeProducts = widget.syncProvider.products.where((p) => p.owner == currentStore.ownerId).toList();

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: DesignTokens.surfaceElevated,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.storefront, color: DesignTokens.primary),
                        const SizedBox(width: 12),
                        const Text('Current Location: ', style: TextStyle(color: Colors.grey)),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              dropdownColor: DesignTokens.surface,
                              value: selectedStoreId,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, color: DesignTokens.primary),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              items: widget.syncProvider.stores.map((store) {
                                return DropdownMenuItem(value: store.storeId, child: Text(store.storeName));
                              }).toList(),
                              onChanged: (val) {
                                setState(() => selectedStoreId = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (currentStore.helpline.isNotEmpty && currentStore.helpline != 'N/A')
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.phone, color: DesignTokens.accent, size: 16),
                            const SizedBox(width: 8),
                            Text('Store Helpline: ${currentStore.helpline}', style: const TextStyle(color: DesignTokens.accent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: storeProducts.isEmpty
                    ? const Center(child: Text('No products mapped to this franchise yet.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: storeProducts.length,
                  itemBuilder: (context, index) {
                    return _buildProductCard(storeProducts[index], currentStore);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProductCard(Product product, Store store) {
    final localInventory = widget.syncProvider.inventory.firstWhere(
          (i) => i.storeId == selectedStoreId && (i.productId == product.productId || i.productId == product.sku),
      orElse: () => Inventory(invId: '', storeId: selectedStoreId!, productId: product.productId, quantity: 0),
    );

    final bool isAvailableLocal = localInventory.quantity > 0;
    final alternatives = isAvailableLocal ? [] : _findAlternativeStores(product);

    return Card(
      color: DesignTokens.surface,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: DesignTokens.borderRadiusMedium),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name, style: DesignTokens.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('\$${product.price.toStringAsFixed(2)}', style: const TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.bold)),
            const Divider(color: DesignTokens.surfaceElevated, height: 24),

            if (isAvailableLocal)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text('Available (${localInventory.quantity} units)', style: const TextStyle(color: Colors.green)),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () => _showReservationDialog(product, localInventory.quantity, store),
                    style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.primary, padding: const EdgeInsets.symmetric(horizontal: 16)),
                    child: const Text('Reserve', style: TextStyle(color: Colors.white)),
                  )
                ],
              )
            else ...[
              Row(
                children: const [
                  Icon(Icons.cancel, color: DesignTokens.error, size: 20),
                  SizedBox(width: 8),
                  Text('Out of stock locally', style: TextStyle(color: DesignTokens.error)),
                ],
              ),
              const SizedBox(height: 12),

              if (_currentPosition == null && !_locationError)
                const Text('Acquiring GPS lock to find alternatives...', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
              else if (_locationError)
                const Text('Enable GPS to find nearby stores.', style: TextStyle(color: Colors.orange))
              else if (alternatives.isEmpty)
                  const Text('Sorry, unavailable at all nearby locations.', style: TextStyle(color: Colors.grey))
                else
                  ...alternatives.map((alt) {
                    final Store altStore = alt['store'];
                    final double dist = alt['distance'];
                    final int qty = alt['quantity'];

                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: DesignTokens.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: DesignTokens.primary.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(altStore.storeName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  Text('${dist.toStringAsFixed(1)} km away', style: const TextStyle(color: DesignTokens.accent)),
                                ],
                              ),
                              Text('$qty units', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _showReservationDialog(product, qty, altStore),
                                icon: const Icon(Icons.shopping_cart_checkout, size: 16, color: DesignTokens.accent),
                                label: const Text('RESERVE', style: TextStyle(color: DesignTokens.accent)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _openDirections(altStore.latitude, altStore.longitude),
                                style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.primary, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                icon: const Icon(Icons.directions, size: 16, color: Colors.white),
                                label: const Text('DIRECTIONS', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  }),
            ]
          ],
        ),
      ),
    );
  }
}