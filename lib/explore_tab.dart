import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myapp/unsplash_api.dart';
import 'package:myapp/pexels_api.dart';
import 'package:myapp/main.dart'; // Import ImageDetails
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:math';

class ExploreTab extends StatefulWidget {
  final String selectedApi;
  final Function(String, int) setWallpaper;

  const ExploreTab({Key? key, required this.selectedApi, required this.setWallpaper}) : super(key: key);

  @override
  _ExploreTabState createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  List<ImageDetails> _wallpapers = [];
  bool _isLoading = true;
  String _error = '';
  final ScrollController _scrollController = ScrollController();
  int _wallpaperPage = 1;
  bool _isWallpaperLoading = false;
  String _searchQuery = '';
  final List<String> _selectedTags = []; // Store selected tags

  @override
  void initState() {
    super.initState();
    _fetchWallpapers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _fetchMoreWallpapers();
    }
  }

  Future<void> _fetchWallpapers({String? query, String? tag}) async {
    setState(() {
      _isLoading = true;
      _error = '';
      if (query != null || tag != null) {
        _wallpapers = [];
        _wallpaperPage = 1;
      }
    });

    try {
      List<dynamic> apiResponse;
      if (widget.selectedApi == 'Unsplash') {
        apiResponse = await UnsplashApi().fetchWallpapers(
            page: _wallpaperPage, query: query ?? tag); // Use query or tag
      } else {
        apiResponse = await PexelsApi.getPhotos(query ?? tag ?? '', _wallpaperPage); // Use query or tag
      }

      List<ImageDetails> newWallpapers = _processApiResponse(apiResponse);

      setState(() {
        _wallpapers = newWallpapers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load wallpapers: $e';
      });
      print('Error fetching wallpapers: $e');
    }
  }

  List<ImageDetails> _processApiResponse(List<dynamic> apiResponse) {
    return apiResponse.map((item) {
      if (widget.selectedApi == 'Unsplash') {
        return ImageDetails(
          url: item['urls']?['regular'] ?? '',
          name: item['description'] ?? item['alt_description'] ?? 'Untitled',
          artistName: item['user']?['name'] ?? 'Unknown',
          artistAvatarUrl: item['user']?['profile_image']?['medium'] ?? '',
          categories: (item['tags'] as List<dynamic>?)?.map((tag) => tag['title'] as String).toList() ?? [],
          resolution: '${item['width'] ?? 0} x ${item['height'] ?? 0}',
          copyright: 'Unsplash License',
        );
      } else {
        return ImageDetails(
          url: item['src']?['large2x'] ?? '',
          name: item['alt'] ?? 'Untitled',
          artistName: item['photographer'] ?? 'Unknown',
          artistAvatarUrl: item['photographer_url'] ?? '',
          categories: (item['tags'] as List<dynamic>?)?.map((tag) => tag['title'] as String).toList() ?? [],
          resolution: '${item['width'] ?? 0} x ${item['height'] ?? 0}',
          copyright: 'Pexels License',
        );
      }
    }).where((image) => image.url.isNotEmpty).toList();
  }

  Future<void> _fetchMoreWallpapers() async {
    if (_isWallpaperLoading) return;

    setState(() {
      _isWallpaperLoading = true;
    });

    try {
      _wallpaperPage++;
      print('Fetching more wallpapers. Page: $_wallpaperPage');

      List<dynamic> apiResponse;
      if (widget.selectedApi == 'Unsplash') {
        apiResponse = await UnsplashApi().fetchWallpapers(
            page: _wallpaperPage, query: _searchQuery);
      } else {
        apiResponse = await PexelsApi.getPhotos(_searchQuery, _wallpaperPage);
      }

      if (apiResponse.isEmpty) {
        print('No more wallpapers to fetch');
        setState(() {
          _isWallpaperLoading = false;
        });
        return;
      }

      List<ImageDetails> newWallpapers = _processApiResponse(apiResponse);

      setState(() {
        _wallpapers.addAll(newWallpapers);
        _isWallpaperLoading = false;
      });

      print('Successfully added ${newWallpapers.length} new wallpapers');
    } catch (e) {
      setState(() {
        _isWallpaperLoading = false;
        _error = 'Failed to load more wallpapers: $e';
      });
      print('Error fetching more wallpapers: $e');
    }
  }

  void _showImageDetailsModal(BuildContext context, ImageDetails imageDetails) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height,
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CachedNetworkImage(
                      imageUrl: imageDetails.url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * 0.6,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            imageDetails.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _downloadImage(imageDetails.url),
                                  child: const Text('Download Image'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return WallpaperDialog(
                                          imageUrl: imageDetails.url,
                                          setWallpaper: widget.setWallpaper,
                                        );
                                      },
                                    );
                                  },
                                  child: const Text('Set as Wallpaper'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              widget.selectedApi == 'Unsplash'
                                ? CircleAvatar(
                                    backgroundImage: imageDetails.artistAvatarUrl.isNotEmpty
                                        ? NetworkImage(imageDetails.artistAvatarUrl)
                                        : const AssetImage('assets/placeholder.png') as ImageProvider,
                                  )
                                : CircleAvatar(
                                    backgroundColor: Colors.blue,
                                    child: Text(imageDetails.artistName[0].toUpperCase()),
                                  ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  imageDetails.artistName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.link),
                                onPressed: () {
                                  // TODO: Implement opening the photographer's profile URL
                                  // You can use the url_launcher package to open the URL
                                  // For Pexels, use imageDetails.artistAvatarUrl (which contains the profile URL)
                                  // For Unsplash, you may need to store the profile URL separately
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(imageDetails.categories.join(", ")),
                          const SizedBox(height: 8),
                          Text(imageDetails.resolution),
                          const SizedBox(height: 8),
                          Text(imageDetails.copyright),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadImage(String imageUrl) async {
    // Request storage permission
    var status = await Permission.storage.request();
    if (status.isGranted) {
      try {
        // Download the image
        var response = await http.get(Uri.parse(imageUrl));
        var bytes = response.bodyBytes;

        // Save the image to the gallery
        final result = await ImageGallerySaver.saveImage(bytes);

        if (result['isSuccess']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image saved to gallery')),
          );
        } else {
          throw Exception('Failed to save image to gallery');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download image: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission denied')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != ''
              ? Center(child: Text(_error))
              : CustomScrollView(
                  controller: _scrollController,
                  slivers: <Widget>[
                    const SliverAppBar(
                      title: Text('Explore'),
                      pinned: true,
                      floating: true,
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverAppBarDelegate(
                        minHeight: 120.0, // Increased height for search bar and chips
                        maxHeight: 120.0,
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              _buildSearchBar(),
                              const SizedBox(height: 8.0),
                              _buildTagChips(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                          if (index == _wallpapers.length) {
                            return _isWallpaperLoading
                                ? const Center(child: CircularProgressIndicator())
                                : const SizedBox.shrink();
                          } else {
                            return GestureDetector(
                              onTap: () {
                                _showImageDetailsModal(context, _wallpapers[index]);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 5,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: CachedNetworkImage(
                                    imageUrl: _wallpapers[index].url,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        const Center(child: CircularProgressIndicator()),
                                    errorWidget: (context, url, error) => const Icon(Icons.error),
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                        childCount: _wallpapers.length + 1,
                      ),
                    ),
                  ],
                ),
    );
  }

  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isSearchExpanded = !_isSearchExpanded;
          if (!_isSearchExpanded) {
            _searchController.clear();
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: _isSearchExpanded
            ? MediaQuery.of(context).size.width - 32
            : 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                _isSearchExpanded ? Icons.close : Icons.search,
                color: Colors.grey[600],
              ),
            ),
            if (_isSearchExpanded)
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search tags or artists',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                  onSubmitted: (String query) {
                    _searchQuery = query;
                    _fetchWallpapers(query: query);
                    setState(() {
                      _isSearchExpanded = false;
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Build horizontal scrollable chips for popular tags
  Widget _buildTagChips() {
    List<String> popularTags = ['Nature', 'Abstract', 'Technology', 'Space', 'Animals', 'City']; // Replace with actual popular tags
    return SizedBox(
      height: 40.0,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: popularTags.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(popularTags[index]),
              selected: _selectedTags.contains(popularTags[index]),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedTags.add(popularTags[index]);
                  } else {
                    _selectedTags.remove(popularTags[index]);
                  }
                  _fetchWallpapers(tag: _selectedTags.isNotEmpty ? _selectedTags.join(',') : null); // Fetch wallpapers based on selected tags
                });
              },
            ),
          );
        },
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => max(maxHeight, minHeight);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
