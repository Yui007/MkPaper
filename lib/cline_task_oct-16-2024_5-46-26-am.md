**User:**

<task>
'lib/' (see below for folder content) this is my wallpaper app there is an issue with this app please fix it without breaking anything:

when i click on an image and then click set as wallpaper a popup appears with options home screen, lockscreen or both but i can only select Home screen I cannot Select Lock Screen Option Or Both Option
</task>

<folder_content path="lib/">
├── Downloadwallpaper.png
├── main.dart
├── pexels_api.dart
├── unsplash_api.dart
└── zxc.PNG

<file_content path="lib/main.dart">
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myapp/unsplash_api.dart';
import 'package:myapp/pexels_api.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:math';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_wallpaper_manager/flutter_wallpaper_manager.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallpaper App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class ImageDetails {
  final String url;
  final String name;
  final String artistName;
  final String artistAvatarUrl;
  final List<String> categories;
  final String resolution;
  final String copyright;

  ImageDetails({
    required this.url,
    required this.name,
    required this.artistName,
    required this.artistAvatarUrl,
    required this.categories,
    required this.resolution,
    required this.copyright,
  });
}

class _MyHomePageState extends State<MyHomePage> {
  final UnsplashApi _unsplashApi = UnsplashApi();
  List<ImageDetails> _wallpapers = [];
  List<String> _featuredWallpapers = [];
  bool _isLoading = true;
  String _error = '';
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;
  int _featuredWallpaperPage = 1;
  int _wallpaperPage = 1;
  bool _isWallpaperLoading = false;
  String _searchQuery = '';
  String _selectedApi = 'Unsplash';
  int _selectedIndex = 0;

    @override
  void initState() {
    super.initState();
    _fetchWallpapers();
    _scrollController.addListener(_onScroll);
    _pageController.addListener(_onPageScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void onApiChanged(String newApi) {
  setState(() {
    _selectedApi = newApi;
    _wallpapers = [];
    _featuredWallpapers = [];
    _wallpaperPage = 1;
    _featuredWallpaperPage = 1;
  });
  _fetchWallpapers();
}

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _fetchMoreWallpapers();
    }
  }

  void _onPageScroll() {
    if (_pageController.position.pixels ==
        _pageController.position.maxScrollExtent) {
      _fetchMoreFeaturedWallpapers();
    }
  }

   Future<void> _fetchWallpapers({String? query}) async {
  setState(() {
    _isLoading = true;
    _error = '';
    if (query != null) {
      _wallpapers = [];
      _wallpaperPage = 1;
    }
  });

  try {
    // Fetch regular wallpapers
    List<dynamic> apiResponse;
    if (_selectedApi == 'Unsplash') {
      apiResponse = await _unsplashApi.fetchWallpapers(
          page: _wallpaperPage, query: query);
    } else {
      apiResponse = await PexelsApi.getPhotos(query ?? '', _wallpaperPage);
    }

    List<ImageDetails> newWallpapers = _processApiResponse(apiResponse);

    // Fetch featured wallpapers
    List<dynamic> featuredResponse;
    if (_selectedApi == 'Unsplash') {
      featuredResponse = await _unsplashApi.fetchWallpapers(
          query: 'featured landscape', page: _featuredWallpaperPage);
    } else {
      featuredResponse = await PexelsApi.getPhotos('featured landscape', _featuredWallpaperPage);
    }

    List<String> newFeaturedWallpapers = _processApiResponse(featuredResponse)
        .take(5)
        .map((item) => item.url)
        .toList();

    setState(() {
      _wallpapers = newWallpapers;
      _featuredWallpapers = newFeaturedWallpapers;
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
    if (_selectedApi == 'Unsplash') {
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
        categories: item['tags'] ?? [],
        resolution: '${item['width'] ?? 0} x ${item['height'] ?? 0}',
        copyright: 'Pexels License',
      );
    }
  }).where((image) => image.url.isNotEmpty).toList();
}

  Future<void> _fetchMoreFeaturedWallpapers() async {
  try {
    _featuredWallpaperPage++;

    List<dynamic> apiResponse;
    if (_selectedApi == 'Unsplash') {
      apiResponse = await _unsplashApi.fetchWallpapers(
          page: _featuredWallpaperPage, query: _searchQuery);
    } else {
      apiResponse = await PexelsApi.getPhotos(_searchQuery, _featuredWallpaperPage);
    }

    if (apiResponse.isEmpty) {
      throw Exception('No more featured photos returned from $_selectedApi API');
    }

    List<String> newWallpapers = apiResponse.map<String>((item) {
      if (_selectedApi == 'Unsplash') {
        return item['urls']['regular'] as String;
      } else {
        return item['src']['original'] as String;
      }
    }).toList();

    setState(() {
      _featuredWallpapers.addAll(newWallpapers);
    });
  } catch (e) {
    setState(() {
      _error = 'Failed to load more featured wallpapers: $e';
    });
    print('Error fetching more featured wallpapers: $e');
  }
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
    if (_selectedApi == 'Unsplash') {
      apiResponse = await _unsplashApi.fetchWallpapers(
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

    List<ImageDetails> newWallpapers = apiResponse.map((item) {
      if (_selectedApi == 'Unsplash') {
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
          categories: item['tags'] ?? [],
          resolution: '${item['width'] ?? 0} x ${item['height'] ?? 0}',
          copyright: 'Pexels License',
        );
      }
    }).where((image) => image.url.isNotEmpty).toList();

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


  void _onItemTapped(int index) {
  setState(() {
    _selectedIndex = index;
  });

  if (index == 0) {
    // "For You" tab
    _refreshWallpapers();
  } else if (index == 2) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => AccountScreen(
              selectedApi: _selectedApi,
              onApiChanged: onApiChanged,
              onPop: () {
                setState(() {
                  _selectedIndex = 0;
                });
              })),
    );
  }
}

void _refreshWallpapers() {
  setState(() {
    _wallpapers = [];
    _featuredWallpapers = [];
    _wallpaperPage = 1;
    _featuredWallpaperPage = 1;
  });
  _fetchWallpapers();
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

  Future<void> _setWallpaper(String imageUrl, int wallpaperManagerOption) async {
    try {
      // Download the image
      var response = await http.get(Uri.parse(imageUrl));
      var bytes = response.bodyBytes;

      // Get the temporary directory
      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/temp_wallpaper.jpg';

      // Save the image to a temporary file
      File(imagePath).writeAsBytesSync(bytes);

      // Request storage permission if needed
      if (wallpaperManagerOption == WallpaperManager.LOCK_SCREEN ||
          wallpaperManagerOption == 2) {
        var status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Permission to access storage denied');
        }
      }

      // Set the wallpaper
      if (wallpaperManagerOption == WallpaperManager.HOME_SCREEN ||
          wallpaperManagerOption == 2) {
        await WallpaperManager.setWallpaperFromFile(
            imagePath, WallpaperManager.HOME_SCREEN);
      }
      if (wallpaperManagerOption == WallpaperManager.LOCK_SCREEN ||
          wallpaperManagerOption == 2) {
        await WallpaperManager.setWallpaperFromFile(
            imagePath, WallpaperManager.LOCK_SCREEN);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallpaper set successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set wallpaper: $e')),
      );
    }
  }


  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  Widget _buildSearchBar() {
    return AnimatedContainer(
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
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isSearchExpanded = !_isSearchExpanded;
                  if (!_isSearchExpanded) {
                    _searchController.clear();
                  }
                });
              },
              child: Icon(
                _isSearchExpanded ? Icons.close : Icons.search,
                color: Colors.grey[600],
              ),
            ),
          ),
          if (_isSearchExpanded)
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search',
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
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _featuredWallpapers.length,
        (index) => Container(
          width: 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index ? Colors.blue : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedWallpaper() {
    return SizedBox(
      height: 250,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _featuredWallpapers.length,
        onPageChanged: (int page) {
          setState(() {
            _currentPage = page;
          });
        },
        itemBuilder: (BuildContext context, int index) {
          return GestureDetector(
            onTap: () {
              _showImageDetailsModal(
                context,
                ImageDetails(
                  url: _featuredWallpapers[index],
                  name: _getImageName(_featuredWallpapers[index]),
                  artistName: _getArtistName(_featuredWallpapers[index]),
                  artistAvatarUrl: _getArtistAvatarUrl(_featuredWallpapers[index]),
                  categories: _getImageCategories(_featuredWallpapers[index]).split(', '),
                  resolution: _getImageResolution(_featuredWallpapers[index]),
                  copyright: _getImageCopyright(_featuredWallpapers[index]),
                ),
              );
            },
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: _featuredWallpapers[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  alignment: Alignment.center,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Wallpaper of the Week',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildPageIndicator(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWallpaperGrid() {
  return GridView.builder(
    controller: _scrollController,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      childAspectRatio: 0.7,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
    ),
    itemCount: _wallpapers.length + 1,
    itemBuilder: (BuildContext context, int index) {
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
  );
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
                                        int selectedOption = 0; // 0: Home Screen, 1: Lock Screen, 2: Both

                                        return AlertDialog(
                                          title: const Text('Set Wallpaper'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              RadioListTile(
                                                title: const Text('Home Screen'),
                                                value: 0,
                                                groupValue: selectedOption,
                                                onChanged: (int? value) {
                                                  setState(() {
                                                    selectedOption = 0;
                                                  });
                                                },
                                              ),
                                              RadioListTile(
                                                title: const Text('Lock Screen'),
                                                value: 1,
                                                groupValue: selectedOption,
                                                onChanged: (int? value) {
                                                  setState(() {
                                                    selectedOption = 1;
                                                  });
                                                },
                                              ),
                                              RadioListTile(
                                                title: const Text('Both'),
                                                value: 2,
                                                groupValue: selectedOption,
                                                onChanged: (int? value) {
                                                  setState(() {
                                                    selectedOption = 2;
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                if (selectedOption == 0) {
                                                  _setWallpaper(imageDetails.url, WallpaperManager.HOME_SCREEN);
                                                } else if (selectedOption == 1) {
                                                  _setWallpaper(imageDetails.url, WallpaperManager.LOCK_SCREEN);
                                                } else {
                                                  _setWallpaper(imageDetails.url, WallpaperManager.HOME_SCREEN);
                                                  _setWallpaper(imageDetails.url, WallpaperManager.LOCK_SCREEN);
                                                }
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text('Set'),
                                            ),
                                          ],
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
                              CircleAvatar(
                                backgroundImage: imageDetails.artistAvatarUrl.isNotEmpty
                                    ? NetworkImage(imageDetails.artistAvatarUrl)
                                    : const AssetImage('assets/placeholder.png') as ImageProvider, // Placeholder
                              ),
                              const SizedBox(width: 8),
                              Text(
                                imageDetails.artistName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.add_circle_outline),
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

  // Helper methods to get image details from API response
  String _getImageName(String imageUrl) {
    // Implement logic to get image name from API response
    return "Image Name"; // Placeholder
  }

  String _getArtistName(String imageUrl) {
    // Implement logic to get artist name from API response
    return "Artist Name"; // Placeholder
  }

  String _getArtistAvatarUrl(String imageUrl) {
    // Implement logic to get artist avatar URL from API response
    return "https://example.com/avatar.jpg"; // Placeholder
  }

  String _getImageCategories(String imageUrl) {
    // Implement logic to get image categories from API response
    return "Category 1, Category 2"; // Placeholder
  }

  String _getImageResolution(String imageUrl) {
    // Implement logic to get image resolution from API response
    return "1920 x 1080"; // Placeholder
  }

  String _getImageCopyright(String imageUrl) {
    // Implement logic to get image copyright from API response
    return "Copyright 2024"; // Placeholder
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
                    SliverAppBar(
                      expandedHeight: 250.0,
                      floating: false,
                      pinned: true,
                      flexibleSpace: FlexibleSpaceBar(
                        background: _buildFeaturedWallpaper(),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverAppBarDelegate(
                        minHeight: 60.0,
                        maxHeight: 60.0,
                        child: Container(
                          color: Colors.white,
                          child: Center(
                            child: _buildSearchBar(),
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
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'For You',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}

class AccountScreen extends StatefulWidget {
  final String selectedApi;
  final Function(String) onApiChanged;
  final Function() onPop;

  const AccountScreen({
    Key? key,
    required this.selectedApi,
    required this.onApiChanged,
    required this.onPop,
  }) : super(key: key);

  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Select API:'),
            DropdownButton<String>(
              value: widget.selectedApi,
              onChanged: (String? newValue) {
                if (newValue != null && newValue != widget.selectedApi) {
                  widget.onApiChanged(newValue);
                  widget.onPop();
                  Navigator.pop(context);
                }
              },
              items: <String>['Unsplash', 'Pexels']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ],
        ),
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

</file_content>

<file_content path="lib/pexels_api.dart">
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter/foundation.dart' show kIsWeb;


class PexelsApi {
  static const String _apiKey = 's8MiQx1Wre2ObqQTdmtNVdvzOxDlraQrpbhE3lyftrZfjGSDVB4nEyua';
  static const String _baseUrl = 'https://api.pexels.com/v1';

  static Future<List<dynamic>> getPhotos(String query, int page) async {
    if (query.isEmpty) {
      query = 'nature'; // Default query if empty
    }

    final url = Uri.parse('$_baseUrl/search?query=${Uri.encodeComponent(query)}&page=$page&per_page=80');

    print('Fetching photos from Pexels API');
    print('URL: $url');

    try {
      http.Response response;
      if (kIsWeb) {
        // For web platform
        response = await http.get(
          url,
          headers: {'Authorization': _apiKey},
        );
      } else {
        // For mobile platforms
        response = await http.get(
          url,
          headers: {'Authorization': _apiKey},
        );
      }

      print('Response status code: ${response.statusCode}');
      print('Response headers: ${response.headers}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData.containsKey('photos') && jsonData['photos'] != null) {
          return jsonData['photos'];
        } else {
          throw Exception('Photos not found in response or is null');
        }
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception('Failed to load photos. Status code: ${response.statusCode}. Error: ${errorBody['error']}');
      }
    } catch (e) {
      print('Error in getPhotos: $e');
      rethrow;
    }
  }
}

</file_content>

<file_content path="lib/unsplash_api.dart">
import 'dart:convert';
import 'package:http/http.dart' as http;

class UnsplashApi {
  static const String _apiKey = 'bvFLCvPeYf83x6E0Z1fAAq_aNOjAhuqofayR5E3Hvo0';
  static const String _baseUrl = 'https://api.unsplash.com';

  Future<List<dynamic>> fetchWallpapers({int page = 1, String? query}) async {
    final Uri url;
    if (query != null && query.isNotEmpty) {
      url = Uri.parse('$_baseUrl/search/photos?client_id=$_apiKey&page=$page&per_page=30&query=${Uri.encodeComponent(query)}');
    } else {
      url = Uri.parse('$_baseUrl/photos?client_id=$_apiKey&page=$page&per_page=30');
    }
    
    print('Unsplash API Request URL: $url');
    print('Fetching page: $page');

    try {
      final response = await http.get(url);
      
      print('Unsplash API Response Status Code: ${response.statusCode}');
      print('Unsplash API Response Headers: ${response.headers}');

      if (response.statusCode == 200) {
        final dynamic jsonData = jsonDecode(response.body);
        if (jsonData == null) {
          print('Received null response from Unsplash API');
          return [];
        }
        if (query != null && query.isNotEmpty) {
          if (jsonData['results'] == null) {
            print('Received null results from Unsplash API search');
            return [];
          }
          return jsonData['results'] as List<dynamic>;
        } else {
          if (jsonData is! List<dynamic>) {
            print('Unexpected response format from Unsplash API: ${jsonData.runtimeType}');
            return [];
          }
          return jsonData;
        }
      } else {
        print('Failed to load wallpapers. Status code: ${response.statusCode}, Response: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error in fetchWallpapers: $e');
      return [];
    }
  }
}
</file_content>
</folder_content>
<environment_details>
# VSCode Visible Files
android/app/src/main/AndroidManifest.xml

# VSCode Open Tabs
lib/pexels_api.dart
lib/unsplash_api.dart
lib/main.dart
android/app/src/main/AndroidManifest.xml

# Current Working Directory (/home/user/myapp) Files
.gitignore
.metadata
analysis_options.yaml
pubspec.lock
pubspec.yaml
README.md
android/
android/.gitignore
android/build.gradle
android/gradle.properties
android/settings.gradle
android/app/
android/app/build.gradle
android/app/src/
android/app/src/debug/
android/app/src/debug/AndroidManifest.xml
android/app/src/main/
android/app/src/main/AndroidManifest.xml
android/app/src/main/java/
android/app/src/main/java/io/
android/app/src/main/java/io/flutter/
android/app/src/main/java/io/flutter/plugins/
android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java
android/app/src/main/kotlin/
android/app/src/main/kotlin/com/
android/app/src/main/kotlin/com/example/
android/app/src/main/kotlin/com/example/myapp/
android/app/src/main/kotlin/com/example/myapp/MainActivity.kt
android/app/src/main/res/
android/app/src/main/res/drawable/
android/app/src/main/res/drawable/launch_background.xml
android/app/src/main/res/drawable-v21/
android/app/src/main/res/drawable-v21/launch_background.xml
android/app/src/main/res/mipmap-hdpi/
android/app/src/main/res/mipmap-hdpi/ic_launcher.png
android/app/src/main/res/mipmap-mdpi/
android/app/src/main/res/mipmap-mdpi/ic_launcher.png
android/app/src/main/res/mipmap-xhdpi/
android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
android/app/src/main/res/mipmap-xxhdpi/
android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
android/app/src/main/res/mipmap-xxxhdpi/
android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
android/app/src/main/res/values/
android/app/src/main/res/values/styles.xml
android/app/src/main/res/values-night/
android/app/src/main/res/values-night/styles.xml
android/app/src/main/res/xml/
android/app/src/main/res/xml/network_security_config.xml
android/app/src/profile/
android/app/src/profile/AndroidManifest.xml
android/gradle/
android/gradle/wrapper/
android/gradle/wrapper/gradle-wrapper.jar
android/gradle/wrapper/gradle-wrapper.properties
build/
lib/
lib/Downloadwallpaper.png
lib/main.dart
lib/pexels_api.dart
lib/unsplash_api.dart
lib/zxc.PNG
test/
test/widget_test.dart
web/
web/favicon.png
web/index.html
web/manifest.json
web/icons/
web/icons/Icon-192.png
web/icons/Icon-512.png
web/icons/Icon-maskable-192.png
web/icons/Icon-maskable-512.png
</environment_details>

---

**Assistant:**

<thinking>
Based on the description, the issue is that the lock screen and both options in the set wallpaper dialog are not working. The code responsible for setting the wallpaper is in the `_setWallpaper` function in `lib/main.dart`. I need to examine this function to understand why these options are not working.

I can use the `read_file` tool to read the contents of `lib/main.dart` and then analyze the `_setWallpaper` function to identify the issue.
</thinking>
<read_file>
<path>lib/main.dart</path>
</read_file>

---

**User:**

[read_file for 'lib/main.dart'] Result:
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myapp/unsplash_api.dart';
import 'package:myapp/pexels_api.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:math';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_wallpaper_manager/flutter_wallpaper_manager.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallpaper App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class ImageDetails {
  final String url;
  final String name;
  final String artistName;
  final String artistAvatarUrl;
  final List<String> categories;
  final String resolution;
  final String copyright;

  ImageDetails({
    required this.url,
    required this.name,
    required this.artistName,
    required this.artistAvatarUrl,
    required this.categories,
    required this.resolution,
    required this.copyright,
  });
}

class _MyHomePageState extends State<MyHomePage> {
  final UnsplashApi _unsplashApi = UnsplashApi();
  List<ImageDetails> _wallpapers = [];
  List<String> _featuredWallpapers = [];
  bool _isLoading = true;
  String _error = '';
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;
  int _featuredWallpaperPage = 1;
  int _wallpaperPage = 1;
  bool _isWallpaperLoading = false;
  String _searchQuery = '';
  String _selectedApi = 'Unsplash';
  int _selectedIndex = 0;

    @override
  void initState() {
    super.initState();
    _fetchWallpapers();
    _scrollController.addListener(_onScroll);
    _pageController.addListener(_onPageScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void onApiChanged(String newApi) {
  setState(() {
    _selectedApi = newApi;
    _wallpapers = [];
    _featuredWallpapers = [];
    _wallpaperPage = 1;
    _featuredWallpaperPage = 1;
  });
  _fetchWallpapers();
}

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _fetchMoreWallpapers();
    }
  }

  void _onPageScroll() {
    if (_pageController.position.pixels ==
        _pageController.position.maxScrollExtent) {
      _fetchMoreFeaturedWallpapers();
    }
  }

   Future<void> _fetchWallpapers({String? query}) async {
  setState(() {
    _isLoading = true;
    _error = '';
    if (query != null) {
      _wallpapers = [];
      _wallpaperPage = 1;
    }
  });

  try {
    // Fetch regular wallpapers
    List<dynamic> apiResponse;
    if (_selectedApi == 'Unsplash') {
      apiResponse = await _unsplashApi.fetchWallpapers(
          page: _wallpaperPage, query: query);
    } else {
      apiResponse = await PexelsApi.getPhotos(query ?? '', _wallpaperPage);
    }

    List<ImageDetails> newWallpapers = _processApiResponse(apiResponse);

    // Fetch featured wallpapers
    List<dynamic> featuredResponse;
    if (_selectedApi == 'Unsplash') {
      featuredResponse = await _unsplashApi.fetchWallpapers(
          query: 'featured landscape', page: _featuredWallpaperPage);
    } else {
      featuredResponse = await PexelsApi.getPhotos('featured landscape', _featuredWallpaperPage);
    }

    List<String> newFeaturedWallpapers = _processApiResponse(featuredResponse)
        .take(5)
        .map((item) => item.url)
        .toList();

    setState(() {
      _wallpapers = newWallpapers;
      _featuredWallpapers = newFeaturedWallpapers;
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
    if (_selectedApi == 'Unsplash') {
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
        categories: item['tags'] ?? [],
        resolution: '${item['width'] ?? 0} x ${item['height'] ?? 0}',
        copyright: 'Pexels License',
      );
    }
  }).where((image) => image.url.isNotEmpty).toList();
}

  Future<void> _fetchMoreFeaturedWallpapers() async {
  try {
    _featuredWallpaperPage++;

    List<dynamic> apiResponse;
    if (_selectedApi == 'Unsplash') {
      apiResponse = await _unsplashApi.fetchWallpapers(
          page: _featuredWallpaperPage, query: _searchQuery);
    } else {
      apiResponse = await PexelsApi.getPhotos(_searchQuery, _featuredWallpaperPage);
    }

    if (apiResponse.isEmpty) {
      throw Exception('No more featured photos returned from $_selectedApi API');
    }

    List<String> newWallpapers = apiResponse.map<String>((item) {
      if (_selectedApi == 'Unsplash') {
        return item['urls']['regular'] as String;
      } else {
        return item['src']['original'] as String;
      }
    }).toList();

    setState(() {
      _featuredWallpapers.addAll(newWallpapers);
    });
  } catch (e) {
    setState(() {
      _error = 'Failed to load more featured wallpapers: $e';
    });
    print('Error fetching more featured wallpapers: $e');
  }
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
    if (_selectedApi == 'Unsplash') {
      apiResponse = await _unsplashApi.fetchWallpapers(
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

    List<ImageDetails> newWallpapers = apiResponse.map((item) {
      if (_selectedApi == 'Unsplash') {
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
          categories: item['tags'] ?? [],
          resolution: '${item['width'] ?? 0} x ${item['height'] ?? 0}',
          copyright: 'Pexels License',
        );
      }
    }).where((image) => image.url.isNotEmpty).toList();

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


  void _onItemTapped(int index) {
  setState(() {
    _selectedIndex = index;
  });

  if (index == 0) {
    // "For You" tab
    _refreshWallpapers();
  } else if (index == 2) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => AccountScreen(
              selectedApi: _selectedApi,
              onApiChanged: onApiChanged,
              onPop: () {
                setState(() {
                  _selectedIndex = 0;
                });
              })),
    );
  }
}

void _refreshWallpapers() {
  setState(() {
    _wallpapers = [];
    _featuredWallpapers = [];
    _wallpaperPage = 1;
    _featuredWallpaperPage = 1;
  });
  _fetchWallpapers();
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

  Future<void> _setWallpaper(String imageUrl, int wallpaperManagerOption) async {
    try {
      // Download the image
      var response = await http.get(Uri.parse(imageUrl));
      var bytes = response.bodyBytes;

      // Get the temporary directory
      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/temp_wallpaper.jpg';

      // Save the image to a temporary file
      File(imagePath).writeAsBytesSync(bytes);

      // Request storage permission if needed
      if (wallpaperManagerOption == WallpaperManager.LOCK_SCREEN ||
          wallpaperManagerOption == 2) {
        var status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Permission to access storage denied');
        }
      }

      // Set the wallpaper
      if (wallpaperManagerOption == WallpaperManager.HOME_SCREEN ||
          wallpaperManagerOption == 2) {
        await WallpaperManager.setWallpaperFromFile(
            imagePath, WallpaperManager.HOME_SCREEN);
      }
      if (wallpaperManagerOption == WallpaperManager.LOCK_SCREEN ||
          wallpaperManagerOption == 2) {
        await WallpaperManager.setWallpaperFromFile(
            imagePath, WallpaperManager.LOCK_SCREEN);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallpaper set successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set wallpaper: $e')),
      );
    }
  }


  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  Widget _buildSearchBar() {
    return AnimatedContainer(
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
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isSearchExpanded = !_isSearchExpanded;
                  if (!_isSearchExpanded) {
                    _searchController.clear();
                  }
                });
              },
              child: Icon(
                _isSearchExpanded ? Icons.close : Icons.search,
                color: Colors.grey[600],
              ),
            ),
          ),
          if (_isSearchExpanded)
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search',
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
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _featuredWallpapers.length,
        (index) => Container(
          width: 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index ? Colors.blue : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedWallpaper() {
    return SizedBox(
      height: 250,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _featuredWallpapers.length,
        onPageChanged: (int page) {
          setState(() {
            _currentPage = page;
          });
        },
        itemBuilder: (BuildContext context, int index) {
          return GestureDetector(
            onTap: () {
              _showImageDetailsModal(
                context,
                ImageDetails(
                  url: _featuredWallpapers[index],
                  name: _getImageName(_featuredWallpapers[index]),
                  artistName: _getArtistName(_featuredWallpapers[index]),
                  artistAvatarUrl: _getArtistAvatarUrl(_featuredWallpapers[index]),
                  categories: _getImageCategories(_featuredWallpapers[index]).split(', '),
                  resolution: _getImageResolution(_featuredWallpapers[index]),
                  copyright: _getImageCopyright(_featuredWallpapers[index]),
                ),
              );
            },
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: _featuredWallpapers[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  alignment: Alignment.center,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Wallpaper of the Week',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildPageIndicator(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWallpaperGrid() {
  return GridView.builder(
    controller: _scrollController,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      childAspectRatio: 0.7,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
    ),
    itemCount: _wallpapers.length + 1,
    itemBuilder: (BuildContext context, int index) {
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
  );
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
                                        int selectedOption = 0; // 0: Home Screen, 1: Lock Screen, 2: Both

                                        return AlertDialog(
                                          title: const Text('Set Wallpaper'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              RadioListTile(
                                                title: const Text('Home Screen'),
                                                value: 0,
                                                groupValue: selectedOption,
                                                onChanged: (int? value) {
                                                  setState(() {
                                                    selectedOption = 0;
                                                  });
                                                },
                                              ),
                                              RadioListTile(
                                                title: const Text('Lock Screen'),
                                                value: 1,
                                                groupValue: selectedOption,
                                                onChanged: (int? value) {
                                                  setState(() {
                                                    selectedOption = 1;
                                                  });
                                                },
                                              ),
                                              RadioListTile(
                                                title: const Text('Both'),
                                                value: 2,
                                                groupValue: selectedOption,
                                                onChanged: (int? value) {
                                                  setState(() {
                                                    selectedOption = 2;
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                if (selectedOption == 0) {
                                                  _setWallpaper(imageDetails.url, WallpaperManager.HOME_SCREEN);
                                                } else if (selectedOption == 1) {
                                                  _setWallpaper(imageDetails.url, WallpaperManager.LOCK_SCREEN);
                                                } else {
                                                  _setWallpaper(imageDetails.url, WallpaperManager.HOME_SCREEN);
                                                  _setWallpaper(imageDetails.url, WallpaperManager.LOCK_SCREEN);
                                                }
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text('Set'),
                                            ),
                                          ],
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
                              CircleAvatar(
                                backgroundImage: imageDetails.artistAvatarUrl.isNotEmpty
                                    ? NetworkImage(imageDetails.artistAvatarUrl)
                                    : const AssetImage('assets/placeholder.png') as ImageProvider, // Placeholder
                              ),
                              const SizedBox(width: 8),
                              Text(
                                imageDetails.artistName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.add_circle_outline),
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

  // Helper methods to get image details from API response
  String _getImageName(String imageUrl) {
    // Implement logic to get image name from API response
    return "Image Name"; // Placeholder
  }

  String _getArtistName(String imageUrl) {
    // Implement logic to get artist name from API response
    return "Artist Name"; // Placeholder
  }

  String _getArtistAvatarUrl(String imageUrl) {
    // Implement logic to get artist avatar URL from API response
    return "https://example.com/avatar.jpg"; // Placeholder
  }

  String _getImageCategories(String imageUrl) {
    // Implement logic to get image categories from API response
    return "Category 1, Category 2"; // Placeholder
  }

  String _getImageResolution(String imageUrl) {
    // Implement logic to get image resolution from API response
    return "1920 x 1080"; // Placeholder
  }

  String _getImageCopyright(String imageUrl) {
    // Implement logic to get image copyright from API response
    return "Copyright 2024"; // Placeholder
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
                    SliverAppBar(
                      expandedHeight: 250.0,
                      floating: false,
                      pinned: true,
                      flexibleSpace: FlexibleSpaceBar(
                        background: _buildFeaturedWallpaper(),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverAppBarDelegate(
                        minHeight: 60.0,
                        maxHeight: 60.0,
                        child: Container(
                          color: Colors.white,
                          child: Center(
                            child: _buildSearchBar(),
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
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'For You',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}

class AccountScreen extends StatefulWidget {
  final String selectedApi;
  final Function(String) onApiChanged;
  final Function() onPop;

  const AccountScreen({
    Key? key,
    required this.selectedApi,
    required this.onApiChanged,
    required this.onPop,
  }) : super(key: key);

  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Select API:'),
            DropdownButton<String>(
              value: widget.selectedApi,
              onChanged: (String? newValue) {
                if (newValue != null && newValue != widget.selectedApi) {
                  widget.onApiChanged(newValue);
                  widget.onPop();
                  Navigator.pop(context);
                }
              },
              items: <String>['Unsplash', 'Pexels']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ],
        ),
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

<environment_details>
# VSCode Visible Files
android/app/src/main/AndroidManifest.xml

# VSCode Open Tabs
lib/pexels_api.dart
lib/unsplash_api.dart
lib/main.dart
android/app/src/main/AndroidManifest.xml
</environment_details>

---

**Assistant:**

<thinking>
I have the contents of `lib/main.dart`. Now I need to analyze the `_setWallpaper` function to understand why the lock screen and both options are not working.

```dart
  Future<void> _setWallpaper(String imageUrl, int wallpaperManagerOption) async {
    try {
      // Download the image
      var response = await http.get(Uri.parse(imageUrl));
      var bytes = response.bodyBytes;

      // Get the temporary directory
      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/temp_wallpaper.jpg';

      // Save the image to a temporary file
      File(imagePath).writeAsBytesSync(bytes);

      // Request storage permission if needed
      if (wallpaperManagerOption == WallpaperManager.LOCK_SCREEN ||
          wallpaperManagerOption == 2) {
        var status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Permission to access storage denied');
        }
      }

      // Set the wallpaper
      if (wallpaperManagerOption == WallpaperManager.HOME_SCREEN ||
          wallpaperManagerOption == 2) {
        await WallpaperManager.setWallpaperFromFile(
            imagePath, WallpaperManager.HOME_SCREEN);
      }
      if (wallpaperManagerOption == WallpaperManager.LOCK_SCREEN ||
          wallpaperManagerOption == 2) {
        await WallpaperManager.setWallpaperFromFile(
            imagePath, WallpaperManager.LOCK_SCREEN);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallpaper set successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set wallpaper: $e')),
      );
    }
  }
```

The code checks `wallpaperManagerOption` to determine whether to set the wallpaper for the home screen, lock screen, or both. If `wallpaperManagerOption` is `WallpaperManager.LOCK_SCREEN` or `2`, it requests storage permission. However, it only throws an exception if the permission is not granted when `wallpaperManagerOption` is `WallpaperManager.LOCK_SCREEN` or `2`. This means that if the user denies storage permission, the code will still attempt to set the wallpaper for the home screen, which could lead to unexpected behavior.

To fix this, I should request storage permission before attempting to set the wallpaper for either the home screen or lock screen. I can do this by moving the permission request outside the conditional blocks.

I will use the `write_to_file` tool to update `lib/main.dart` with the corrected code.
</thinking>
<write_to_file>
<path>lib/main.dart</path>
<content>
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myapp/unsplash_api.dart';
import 'package:myapp/pexels_api.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:math';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_wallpaper_manager/flutter_wallpaper_manager.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallpaper App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class ImageDetails {
  final String url;
  final String name;
  final String artistName;
  final String artistAvatarUrl;
  final List<String> categories;
  final String resolution;
  final String copyright;

  ImageDetails({
    required this.url,
    required this.name,
    required this.artistName,
    required this.artistAvatarUrl,
    required this.categories,
    required this.resolution,
    required this.copyright,
  });
}

class _MyHomePageState extends State<MyHomePage> {
  final UnsplashApi _unsplashApi = UnsplashApi();
  List<ImageDetails> _wallpapers = [];
  List<String> _featuredWallpapers = [];
  bool _isLoading = true;
  String _error = '';
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;
  int _featuredWallpaperPage = 1;
  int _wallpaperPage = 1;
  bool _isWallpaperLoading = false;
  String _searchQuery = '';
  String _selectedApi = 'Unsplash';
  int _selectedIndex = 0;

    @override
  void initState() {
    super.initState();
    _fetchWallpapers();
    _scrollController.addListener(_onScroll);
    _pageController.addListener(_onPageScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void onApiChanged(String newApi) {
  setState(() {
    _selectedApi = newApi;
    _wallpapers = [];
    _featuredWallpapers = [];
    _wallpaperPage = 1;
    _featuredWallpaperPage = 1;
  });
  _fetchWallpapers();
}

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _fetchMoreWallpapers();
    }
  }

  void _onPageScroll() {
    if (_pageController.position.pixels ==
        _pageController.position.maxScrollExtent) {
      _fetchMoreFeaturedWallpapers();
    }
  }

   Future<void> _fetchWallpapers({String? query}) async {
  setState(() {
    _isLoading = true;
    _error = '';
    if (query != null) {
      _wallpapers = [];
      _wallpaperPage = 1;
    }
  });

  try {
    // Fetch regular wallpapers
    List<dynamic> apiResponse;
    if (_selectedApi == 'Unsplash') {
      apiResponse = await _unsplashApi.fetchWallpapers(
          page: _wallpaperPage, query: query);
    } else {
      apiResponse = await PexelsApi.getPhotos(query ?? '', _wallpaperPage);
    }

    List<ImageDetails> newWallpapers = _processApiResponse(apiResponse);

    // Fetch featured wallpapers
    List<dynamic> featuredResponse;
    if (_selectedApi == 'Unsplash') {
      featuredResponse = await _unsplashApi.fetchWallpapers(
          query: 'featured landscape', page: _featuredWallpaperPage);
    } else {
      featuredResponse = await PexelsApi.getPhotos('featured landscape', _featuredWallpaperPage);
    }

    List<String> newFeaturedWallpapers = _processApiResponse(featuredResponse)
        .take(5)
        .map((item) => item.url)
        .toList();

    setState(() {
      _wallpapers = newWallpapers;
      _featuredWallpapers = newFeaturedWallpapers;
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
    if (_selectedApi == 'Unsplash') {
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
        categories: item['tags'] ?? [],
        resolution: '${item['width'] ?? 0} x ${item['height'] ?? 0}',
        copyright: 'Pexels License',
      );
    }
  }).where((image) => image.url.isNotEmpty).toList();
}

  Future<void> _fetchMoreFeaturedWallpapers() async {
  try {
    _featuredWallpaperPage++;

    List<dynamic> apiResponse;
    if (_selectedApi == 'Unsplash') {
      apiResponse = await _unsplashApi.fetchWallpapers(
          page: _featuredWallpaperPage, query: _searchQuery);
    } else {
      apiResponse = await PexelsApi.getPhotos(_searchQuery, _featuredWallpaperPage);
    }

    if (apiResponse.isEmpty) {
      throw Exception('No more featured photos returned from $_selectedApi API');
    }

    List<String> newWallpapers = apiResponse.map<String>((item) {
      if (_selectedApi == 'Unsplash') {
        return item['urls']['regular'] as String;
      } else {
        return item['src']['original'] as String;
      }
    }).toList();

    setState(() {
      _featuredWallpapers.addAll(newWallpapers);
    });
  } catch (e) {
    setState(() {
      _error = 'Failed to load more featured wallpapers: $e';
    });
    print('Error fetching more featured wallpapers: $e');
  }
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
    if (_selectedApi == 'Unsplash') {
      apiResponse = await _unsplashApi.fetchWallpapers(
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

    List<ImageDetails> newWallpapers = apiResponse.map((item) {
      if (_selectedApi == 'Unsplash') {
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
          categories: item['tags'] ?? [],
          resolution: '${item['width'] ?? 0} x ${item['height'] ?? 0}',
          copyright: 'Pexels License',
        );
      }
    }).where((image) => image.url.isNotEmpty).toList();

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


  void _onItemTapped(int index) {
  setState(() {
    _selectedIndex = index;
  });

  if (index == 0) {
    // "For You" tab
    _refreshWallpapers();
  } else if (index == 2) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => AccountScreen(
              selectedApi: _selectedApi,
              onApiChanged: onApiChanged,
              onPop: () {
                setState(() {
                  _selectedIndex = 0;
                });
              })),
    );
  }
}

void _refreshWallpapers() {
  setState(() {
    _wallpapers = [];
    _featuredWallpapers = [];
    _wallpaperPage = 1;
    _featuredWallpaperPage = 1;
  });
  _fetchWallpapers();
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

  Future<void> _setWallpaper(String imageUrl, int wallpaperManagerOption) async {
    try {
      // Download the image
      var response = await http.get(Uri.parse(imageUrl));
      var bytes = response.bodyBytes;

      // Get the temporary directory
      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/temp_wallpaper.jpg';

      // Save the image to a temporary file
      File(imagePath).writeAsBytesSync(bytes);

      // Request storage permission if needed
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Permission to access storage denied');
      }

      // Set the wallpaper
      if (wallpaperManagerOption == WallpaperManager.HOME_SCREEN ||
          wallpaperManagerOption == 2) {
        await WallpaperManager.setWallpaperFromFile(
            imagePath, WallpaperManager.HOME_SCREEN);
      }
      if (wallpaperManagerOption == WallpaperManager.LOCK_SCREEN ||
          wallpaperManagerOption == 2) {
        await WallpaperManager.setWallpaperFromFile(
            imagePath, WallpaperManager.LOCK_SCREEN);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallpaper set successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set wallpaper: $e')),
      );
    }
  }


  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  Widget _buildSearchBar() {
    return AnimatedContainer(
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
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isSearchExpanded = !_isSearchExpanded;
                  if (!_isSearchExpanded) {
                    _searchController.clear();
                  }
                });
              },
              child: Icon(
                _isSearchExpanded ? Icons.close : Icons.search,
                color: Colors.grey[600],
              ),
            ),
          ),
          if (_isSearchExpanded)
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search',
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
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _featuredWallpapers.length,
        (index) => Container(
          width: 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index ? Colors.blue : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedWallpaper() {
    return SizedBox(
      height: 250,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _featuredWallpapers.length,
        onPageChanged: (int page) {
          setState(() {
            _currentPage = page;
          });
        },
        itemBuilder: (BuildContext context, int index) {
          return GestureDetector(
            onTap: () {
              _showImageDetailsModal(
                context,
                ImageDetails(
                  url: _featuredWallpapers[index],
                  name: _getImageName(_featuredWallpapers[index]),
                  artistName: _getArtistName(_featuredWallpapers[index]),
                  artistAvatarUrl: _getArtistAvatarUrl(_featuredWallpapers[index]),
                  categories: _getImageCategories(_featuredWallpapers[index]).split(', '),
                  resolution: _getImageResolution(_featuredWallpapers[index]),
                  copyright: _getImageCopyright(_featuredWallpapers[index]),
                ),
              );
            },
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: _featuredWallpapers[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  alignment: Alignment.center,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Wallpaper of the Week',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildPageIndicator(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWallpaperGrid() {
  return GridView.builder(
    controller: _scrollController,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      childAspectRatio: 0.7,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
    ),
    itemCount: _wallpapers.length + 1,
    itemBuilder: (BuildContext context, int index) {
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
  );
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
                                        int selectedOption = 0; // 0: Home Screen, 1: Lock Screen, 2: Both

                                        return AlertDialog(
                                          title: const Text('Set Wallpaper'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              RadioListTile(
                                                title: const Text('Home Screen'),
                                                value: 0,
                                                groupValue: selectedOption,
                                                onChanged: (int? value) {
                                                  setState(() {
                                                    selectedOption = 0;
                                                  });
                                                },
                                              ),
                                              RadioListTile(
                                                title: const Text('Lock Screen'),
                                                value: 1,
                                                groupValue: selectedOption,
                                                onChanged: (int? value) {
                                                  setState(() {
                                                    selectedOption = 1;
                                                  });
                                                },
                                              ),
                                              RadioListTile(
                                                title: const Text('Both'),
                                                value: 2,
                                                groupValue: selectedOption,
                                                onChanged: (int? value) {
                                                  setState(() {
                                                    selectedOption = 2;
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                if (selectedOption == 0) {
                                                  _setWallpaper(imageDetails.url, WallpaperManager.HOME_SCREEN);
                                                } else if (selectedOption == 1) {
                                                  _setWallpaper(imageDetails.url, WallpaperManager.LOCK_SCREEN);
                                                } else {
                                                  _setWallpaper(imageDetails.url, WallpaperManager.HOME_SCREEN);
                                                  _setWallpaper(imageDetails.url, WallpaperManager.LOCK_SCREEN);
                                                }
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text('Set'),
                                            ),
                                          ],
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
                              CircleAvatar(
                                backgroundImage: imageDetails.artistAvatarUrl.isNotEmpty
                                    ? NetworkImage(imageDetails.artistAvatarUrl)
                                    : const AssetImage('assets/placeholder.png') as ImageProvider, // Placeholder
                              ),
                              const SizedBox(width: 8),
                              Text(
                                imageDetails.artistName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.add_circle_outline),
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

  // Helper methods to get image details from API response
  String _getImageName(String imageUrl) {
    // Implement logic to get image name from API response
    return "Image Name"; // Placeholder
  }

  String _getArtistName(String imageUrl) {
    // Implement logic to get artist name from API response
    return "Artist Name"; // Placeholder
  }

  String _getArtistAvatarUrl(String imageUrl) {
    // Implement logic to get artist avatar URL from API response
    return "https://example.com/avatar.jpg"; // Placeholder
  }

  String _getImageCategories(String imageUrl) {
    // Implement logic to get image categories from API response
    return "Category 1, Category 2"; // Placeholder
  }

  String _getImageResolution(String imageUrl) {
    // Implement logic to get image resolution from API response
    return "1920 x 1080"; // Placeholder
  }

  String _getImageCopyright(String imageUrl) {
    // Implement logic to get image copyright from API response
    return "Copyright 2024"; // Placeholder
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
                    SliverAppBar(
                      expandedHeight: 250.0,
                      floating: false,
                      pinned: true,
                      flexibleSpace: FlexibleSpaceBar(
                        background: _buildFeaturedWallpaper(),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverAppBarDelegate(
                        minHeight: 60.0,
                        maxHeight: 60.0,
                        child: Container(
                          color: Colors.white,
                          child: Center(
                            child: _buildSearchBar(),
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
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'For You',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}

class AccountScreen extends StatefulWidget {
  final String selectedApi;
  final Function(String) onApiChanged;
  final Function() onPop;

  const AccountScreen({
    Key? key,
    required this.selectedApi,
    required this.onApiChanged,
    required this.onPop,
  }) : super(key: key);

  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Select API:'),
            DropdownButton<String>(
              value: widget.selectedApi,
              onChanged: (String? newValue) {
                if (newValue != null && newValue != widget.selectedApi) {
                  widget.onApiChanged(newValue);
                  widget.onPop();
                  Navigator.pop(context);
                }
              },
              items: <String>['Unsplash', 'Pexels']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ],
        ),
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
</content>
</write_to_file>

---

**User:**

[write_to_file for 'lib/main.dart'] Result:
The content was successfully saved to lib/main.dart.
<environment_details>
# VSCode Visible Files
android/app/src/main/AndroidManifest.xml
lib/main.dart

# VSCode Open Tabs
lib/pexels_api.dart
lib/unsplash_api.dart
android/app/src/main/AndroidManifest.xml
lib/main.dart
</environment_details>

---

**Assistant:**

<thinking>
I've updated `lib/main.dart` to fix the issue with the lock screen and both options in the set wallpaper dialog. Now, I need to confirm that the issue is resolved.

I can ask the user to test the app and verify that the lock screen and both options are working correctly.
</thinking>
<ask_followup_question>
<question>I've updated the code to fix the issue with the lock screen and both options in the set wallpaper dialog. Can you please test the app again and let me know if the issue is resolved?</question>
</ask_followup_question>

---

**User:**

[ask_followup_question for 'I've updated the code to fix the issue with the lock screen and both options in the set wallpaper dialog. Can you please test the app again and let me know if the issue is resolved?'] Result:
<answer>
not working even though i already gave it storage permission before and as i said before the main issue is that i cant select option lock Screen And option Both even though i clicked it 100 times
</answer>
<environment_details>
# VSCode Visible Files
lib/main.dart
extension-output-google.monospace-#1-IDX

# VSCode Open Tabs
lib/pexels_api.dart
lib/unsplash_api.dart
android/app/src/main/AndroidManifest.xml
lib/main.dart
</environment_details>

---

**Assistant:**

<thinking>
The user confirmed that the issue is still not resolved, even after granting storage permission. The user mentioned that they cannot select the "Lock Screen" and "Both" options in the dialog, even after clicking them multiple times.

This suggests that there might be an issue with the UI or the way the options are handled in the dialog. I need to examine the code responsible for creating and handling the dialog to identify the problem.

The dialog is created in the `_showImageDetailsModal` function in `lib/main.dart`. I can use the `read_file` tool to read the contents of `lib/main.dart` again and then analyze the `_showImageDetailsModal` function to find the issue.
</thinking>
<read_file>
<path>lib/main.dart</path>
</read_file>



---

**User:**

[read_file for 'lib/main.dart'] Result:
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myapp/unsplash_api.dart';
import 'package:myapp/pexels_api.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:math';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_wallpaper_manager/flutter_wallpaper_manager.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallpaper App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class ImageDetails {
  final String url;
  final String name;
  final String artistName;
  final String artistAvatarUrl;
  final List<String> categories;
  final String resolution;
  final String copyright;

  ImageDetails({
    required this.url,
    required this.name,
    required this.artistName,
    required this.artistAvatarUrl,
    required this.categories,
    required this.resolution,
    required this.copyright,
  });
}

class _MyHomePageState extends State<MyHomePage> {
  final UnsplashApi _unsplashApi = UnsplashApi();
  List<ImageDetails> _wallpapers = [];
  List<String> _featuredWallpapers = [];
  bool _isLoading = true;
  String _error = '';
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;
  int _featuredWallpaperPage = 1;
  int _wallpaperPage = 1;
  bool _isWallpaperLoading = false;
  String _searchQuery = '';
  String _selectedApi = 'Unsplash';
  int _selectedIndex = 0;

    @override
  void initState() {
    super.initState();
    _fetchWallpapers();
    _scrollController.addListener(_onScroll);
    _pageController.addListener(_onPageScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void onApiChanged(String newApi) {
  setState(() {
    _selectedApi = newApi;
    _wallpapers = [];
    _featuredWallpapers = [];
    _wallpaperPage = 1;
    _featuredWallpaperPage = 1;
  });
  _fetchWallpapers();
}

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _fetchMoreWallpapers();
    }
  }

  void _onPageScroll() {
    if (_pageController.position.pixels ==
        _pageController.position.maxScrollExtent) {
      _fetchMoreFeaturedWallpapers();
    }
  }

   Future<void> _fetchWallpapers({String? query}) async {
  setState(() {
    _isLoading = true;
    _error = '';
    if (query != null) {
      _wallpapers = [];
      _wallpaperPage = 1;
    }
  });

  try {
    // Fetch regular wallpapers
    List<dynamic> apiResponse;
    if (_selectedApi == 'Unsplash') {
      apiResponse = await _unsplashApi.fetchWallpapers(
          page: _wallpaperPage, query: query);
    } else {
      apiResponse = await PexelsApi.getPhotos(query ?? '', _wallpaperPage);
    }

    List<ImageDetails> newWallpapers = _processApiResponse(apiResponse);

    // Fetch featured wallpapers
    List<dynamic> featuredResponse;
    if (_selectedApi == 'Unsplash') {
      featuredResponse = await _unsplashApi.fetchWallpapers(
          query: 'featured landscape', page: _featuredWallpaperPage);
    } else {
      featuredResponse = await PexelsApi.getPhotos('featured landscape', _featuredWallpaperPage);
    }

    List<String> newFeaturedWallpapers = _processApiResponse(featuredResponse)
        .take(5)
        .map((item) => item.url)
        .toList();

    setState(() {
      _wallpapers = newWallpapers;
      _featuredWallpapers = newFeaturedWallpapers;
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
    if (_selectedApi == 'Unsplash') {
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
        categories: item['tags'] ?? [],
        resolution: '${item['width'] ?? 0} x ${item['height'] ?? 0}',
        copyright: 'Pexels License',
      );
    }
  }).where((image) => image.url.isNotEmpty).toList();
}

  Future<void> _fetchMoreFeaturedWallpapers() async {
  try {
    _featuredWallpaperPage++;

    List<dynamic> apiResponse;
    if (_selectedApi == 'Unsplash') {
      apiResponse = await _unsplashApi.fetchWallpapers(
          page: _featuredWallpaperPage, query: _searchQuery);
    } else {
      apiResponse = await PexelsApi.getPhotos(_searchQuery, _featuredWallpaperPage);
    }

    if (apiResponse.isEmpty) {
      throw Exception('No more featured photos returned from $_selectedApi API');
    }

    List<String> newWallpapers = apiResponse.map<String>((item) {
      if (_selectedApi == 'Unsplash') {
        return item['urls']['regular'] as String;
      } else {
        return item['src']['original'] as String;
      }
    }).toList();

    setState(() {
      _featuredWallpapers.addAll(newWallpapers);
    });
  } catch (e) {
    setState(() {
      _error = 'Failed to load more featured wallpapers: $e';
    });
    print('Error fetching more featured wallpapers: $e');
  }
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
    if (_selectedApi == 'Unsplash') {
      apiResponse = await _unsplashApi.fetchWallpapers(
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

    List<ImageDetails> newWallpapers = apiResponse.map((item) {
      if (_selectedApi == 'Unsplash') {
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
          categories: item['tags'] ?? [],
          resolution: '${item['width'] ?? 0} x ${item['height'] ?? 0}',
          copyright: 'Pexels License',
        );
      }
    }).where((image) => image.url.isNotEmpty).toList();

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


  void _onItemTapped(int index) {
  setState(() {
    _selectedIndex = index;
  });

  if (index == 0) {
    // "For You" tab
    _refreshWallpapers();
  } else if (index == 2) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => AccountScreen(
              selectedApi: _selectedApi,
              onApiChanged: onApiChanged,
              onPop: () {
                setState(() {
                  _selectedIndex = 0;
                });
              })),
    );
  }
}

void _refreshWallpapers() {
  setState(() {
    _wallpapers = [];
    _featuredWallpapers = [];
    _wallpaperPage = 1;
    _featuredWallpaperPage = 1;
  });
  _fetchWallpapers();
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

  Future<void> _setWallpaper(String imageUrl, int wallpaperManagerOption) async {
    try {
      // Download the image
      var response = await http.get(Uri.parse(imageUrl));
      var bytes = response.bodyBytes;

      // Get the temporary directory
      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/temp_wallpaper.jpg';

      // Save the image to a temporary file
      File(imagePath).writeAsBytesSync(bytes);

      // Request storage permission if needed
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Permission to access storage denied');
      }

      // Set the wallpaper
      if (wallpaperManagerOption == WallpaperManager.HOME_SCREEN ||
          wallpaperManagerOption == 2) {
        await WallpaperManager.setWallpaperFromFile(
            imagePath, WallpaperManager.HOME_SCREEN);
      }
      if (wallpaperManagerOption == WallpaperManager.LOCK_SCREEN ||
          wallpaperManagerOption == 2) {
        await WallpaperManager.setWallpaperFromFile(
            imagePath, WallpaperManager.LOCK_SCREEN);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallpaper set successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set wallpaper: $e')),
      );
    }
  }


  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  Widget _buildSearchBar() {
    return AnimatedContainer(
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
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isSearchExpanded = !_isSearchExpanded;
                  if (!_isSearchExpanded) {
                    _searchController.clear();
                  }
                });
              },
              child: Icon(
                _isSearchExpanded ? Icons.close : Icons.search,
                color: Colors.grey[600],
              ),
            ),
          ),
          if (_isSearchExpanded)
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search',
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
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _featuredWallpapers.length,
        (index) => Container(
          width: 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index ? Colors.blue : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedWallpaper() {
    return SizedBox(
      height: 250,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _featuredWallpapers.length,
        onPageChanged: (int page) {
          setState(() {
            _currentPage = page;
          });
        },
        itemBuilder: (BuildContext context, int index) {
          return GestureDetector(
            onTap: () {
              _showImageDetailsModal(
                context,
                ImageDetails(
                  url: _featuredWallpapers[index],
                  name: _getImageName(_featuredWallpapers[index]),
                  artistName: _getArtistName(_featuredWallpapers[index]),
                  artistAvatarUrl: _getArtistAvatarUrl(_featuredWallpapers[index]),
                  categories: _getImageCategories(_featuredWallpapers[index]).split(', '),
                  resolution: _getImageResolution(_featuredWallpapers[index]),
                  copyright: _getImageCopyright(_featuredWallpapers[index]),
                ),
              );
            },
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: _featuredWallpapers[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  alignment: Alignment.center,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Wallpaper of the Week',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildPageIndicator(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWallpaperGrid() {
  return GridView.builder(
    controller: _scrollController,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      childAspectRatio: 0.7,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
    ),
    itemCount: _wallpapers.length + 1,
    itemBuilder: (BuildContext context, int index) {
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
  );
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
                                        int selectedOption = 0; // 0: Home Screen, 1: Lock Screen, 2: Both

                                        return AlertDialog(
                                          title: const Text('Set Wallpaper'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              RadioListTile(
                                                title: const Text('Home Screen'),
                                                value: 0,
                                                groupValue: selectedOption,
                                                onChanged: (int? value) {
                                                  setState(() {
                                                    selectedOption = 0;
                                                  });
                                                },
                                              ),
                                              RadioListTile(
                                                title: const Text('Lock Screen'),
                                                value: 1,
                                                groupValue: selectedOption,
                                                onChanged: (int? value) {
                                                  setState(() {
                                                    selectedOption = 1;
                                                  });
                                                },
                                              ),
                                              RadioListTile(
                                                title: const Text('Both'),
                                                value: 2,
                                                groupValue: selectedOption,
                                                onChanged: (int? value) {
                                                  setState(() {
                                                    selectedOption = 2;
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                if (selectedOption == 0) {
                                                  _setWallpaper(imageDetails.url, WallpaperManager.HOME_SCREEN);
                                                } else if (selectedOption == 1) {
                                                  _setWallpaper(imageDetails.url, WallpaperManager.LOCK_SCREEN);
                                                } else {
                                                  _setWallpaper(imageDetails.url, WallpaperManager.HOME_SCREEN);
                                                  _setWallpaper(imageDetails.url, WallpaperManager.LOCK_SCREEN);
                                                }
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text('Set'),
                                            ),
                                          ],
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
                              CircleAvatar(
                                backgroundImage: imageDetails.artistAvatarUrl.isNotEmpty
                                    ? NetworkImage(imageDetails.artistAvatarUrl)
                                    : const AssetImage('assets/placeholder.png') as ImageProvider, // Placeholder
                              ),
                              const SizedBox(width: 8),
                              Text(
                                imageDetails.artistName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.add_circle_outline),
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

  // Helper methods to get image details from API response
  String _getImageName(String imageUrl) {
    // Implement logic to get image name from API response
    return "Image Name"; // Placeholder
  }

  String _getArtistName(String imageUrl) {
    // Implement logic to get artist name from API response
    return "Artist Name"; // Placeholder
  }

  String _getArtistAvatarUrl(String imageUrl) {
    // Implement logic to get artist avatar URL from API response
    return "https://example.com/avatar.jpg"; // Placeholder
  }

  String _getImageCategories(String imageUrl) {
    // Implement logic to get image categories from API response
    return "Category 1, Category 2"; // Placeholder
  }

  String _getImageResolution(String imageUrl) {
    // Implement logic to get image resolution from API response
    return "1920 x 1080"; // Placeholder
  }

  String _getImageCopyright(String imageUrl) {
    // Implement logic to get image copyright from API response
    return "Copyright 2024"; // Placeholder
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
                    SliverAppBar(
                      expandedHeight: 250.0,
                      floating: false,
                      pinned: true,
                      flexibleSpace: FlexibleSpaceBar(
                        background: _buildFeaturedWallpaper(),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverAppBarDelegate(
                        minHeight: 60.0,
                        maxHeight: 60.0,
                        child: Container(
                          color: Colors.white,
                          child: Center(
                            child: _buildSearchBar(),
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
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'For You',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}

class AccountScreen extends StatefulWidget {
  final String selectedApi;
  final Function(String) onApiChanged;
  final Function() onPop;

  const AccountScreen({
    Key? key,
    required this.selectedApi,
    required this.onApiChanged,
    required this.onPop,
  }) : super(key: key);

  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Select API:'),
            DropdownButton<String>(
              value: widget.selectedApi,
              onChanged: (String? newValue) {
                if (newValue != null && newValue != widget.selectedApi) {
                  widget.onApiChanged(newValue);
                  widget.onPop();
                  Navigator.pop(context);
                }
              },
              items: <String>['Unsplash', 'Pexels']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ],
        ),
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

<environment_details>
# VSCode Visible Files
lib/main.dart

# VSCode Open Tabs
lib/pexels_api.dart
lib/unsplash_api.dart
android/app/src/main/AndroidManifest.xml
lib/main.dart
</environment_details>

---

**Assistant:**

<thinking>
I have the contents of `lib/main.dart`. Now I need to analyze the `_showImageDetailsModal` function, specifically the part that creates the dialog, to understand why the "Lock Screen" and "Both" options are not selectable.

```dart
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        int selectedOption = 0; // 0: Home Screen, 1: Lock Screen, 2: Both

                                        return AlertDialog(
                                          title: const Text('Set Wallpaper'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              RadioListTile(
                                                title: const Text('Home Screen'),
                                                value: 0,
                                                groupValue: selectedOption,
                                                onChanged: (int? value) {
                                                  setState(() {
                                                    selectedOption = 0;
                                                  });
                                                },
                                              ),
                                              RadioListTile(
                                                title: const Text('Lock Screen'),
                                                value: 1,
                                                groupValue: selectedOption,
                                                onChanged: (int? value) {
                                                  setState(() {
                                                    selectedOption = 1;
                                                  });
                                                },
                                              ),
                                              RadioListTile(
                                                title: const Text('Both'),
                                                value: 2,
                                                groupValue: selectedOption,
                                                onChanged: (int? value) {
                                                  setState(() {
                                                    selectedOption = 2;
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                if (selectedOption == 0) {
                                                  _setWallpaper(imageDetails.url, WallpaperManager.HOME_SCREEN);
                                                } else if (selectedOption == 1) {
                                                  _setWallpaper(imageDetails.url, WallpaperManager.LOCK_SCREEN);
                                                } else {
                                                  _setWallpaper(imageDetails.url, WallpaperManager.HOME_SCREEN);
                                                  _setWallpaper(imageDetails.url, WallpaperManager.LOCK_SCREEN);
                                                }
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text('Set'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
```

The issue lies in the `setState` calls within the `onChanged` callbacks of the `RadioListTile` widgets. The `setState` calls are updating the state of the widget that created the dialog, but the dialog itself is a separate widget. This means that the changes to `selectedOption` are not being reflected in the dialog's UI.

To fix this, I need to move the `setState` calls to a `StatefulWidget` that manages the state of the dialog itself. I can create a new `StatefulWidget` called `WallpaperDialog` and move the dialog creation logic and state management to this widget.

I will use the `write_to_file` tool to update `lib/main.dart` with the corrected code.
</thinking>
<write_to_file>
<path>lib/main.dart</path>
<content>
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myapp/unsplash_api.dart';
import 'package:myapp/pexels_api.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:math';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_wallpaper_manager/flutter_wallpaper_manager.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallpaper App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class ImageDetails {
  final String url;
  final String name;
  final String artistName;
  final String artistAvatarUrl;
  final List<String> categories;
  final String resolution;
  final String copyright;

  ImageDetails({
    required this.url,
    required this.name,
    required this.artistName,
    required this.artistAvatarUrl,
    required this.categories,
    required this.resolution,
    required this.copyright,
  });
}

class _MyHomePageState extends State<MyHomePage> {
  final UnsplashApi _unsplashApi = UnsplashApi();
  List<ImageDetails> _wallpapers = [];
  List<String> _featuredWallpapers = [];
  bool _isLoading = true;
  String _error = '';
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;
  int _featuredWallpaperPage = 1;
  int _wallpaperPage = 1;
  bool _isWallpaperLoading = false;
  String _searchQuery = '';
  String _selectedApi = 'Unsplash';
  int _selectedIndex = 0;

    @override
  void initState() {
    super.initState();
    _fetchWallpapers();
    _scrollController.addListener(_onScroll);
    _pageController.addListener(_onPageScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void onApiChanged(String newApi) {
  setState(() {
    _selectedApi = newApi;
    _wallpapers = [];
    _featuredWallpapers = [];
    _wallpaperPage = 1;
    _featuredWallpaperPage = 1;
  });
  _fetchWallpapers();
}

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _fetchMoreWallpapers();
    }
  }

  void _onPageScroll() {
    if (_pageController.position.pixels ==
        _pageController.position.maxScrollExtent) {
      _fetchMoreFeaturedWallpapers();
    }
  }

   Future<void> _fetchWallpapers({String? query}) async {
  setState(() {
    _isLoading = true;
    _error = '';
    if (query != null) {
      _wallpapers = [];
      _wallpaperPage = 1;
    }
  });

  try {
    // Fetch regular wallpapers
    List<dynamic> apiResponse;
    if (_selectedApi == 'Unsplash') {
      apiResponse = await _unsplashApi.fetchWallpapers(
          page: _wallpaperPage, query: query);
    } else {
      apiResponse = await PexelsApi.getPhotos(query ?? '', _wallpaperPage);
    }

    List<ImageDetails> newWallpapers = _processApiResponse(apiResponse);

    // Fetch featured wallpapers
    List<dynamic> featuredResponse;
    if (_selectedApi == 'Unsplash') {
      featuredResponse = await _unsplashApi.fetchWallpapers(
          query: 'featured landscape', page: _featuredWallpaperPage);
    } else {
      featuredResponse = await PexelsApi.getPhotos('featured landscape', _featuredWallpaperPage);
    }

    List<String> newFeaturedWallpapers = _processApiResponse(featuredResponse)
        .take(5)
        .map((item) => item.url)
        .toList();

    setState(() {
      _wallpapers = newWallpapers;
      _featuredWallpapers = newFeaturedWallpapers;
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
    if (_selectedApi == 'Unsplash') {
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
        categories: item['tags'] ?? [],
        resolution: '${item['width'] ?? 0} x ${item['height'] ?? 0}',
        copyright: 'Pexels License',
      );
    }
  }).where((image) => image.url.isNotEmpty).toList();
}

  Future<void> _fetchMoreFeaturedWallpapers() async {
  try {
    _featuredWallpaperPage++;

    List<dynamic> apiResponse;
    if (_selectedApi == 'Unsplash') {
      apiResponse = await _unsplashApi.fetchWallpapers(
          page: _featuredWallpaperPage, query: _searchQuery);
    } else {
      apiResponse = await PexelsApi.getPhotos(_searchQuery, _featuredWallpaperPage);
    }

    if (apiResponse.isEmpty) {
      throw Exception('No more featured photos returned from $_selectedApi API');
    }

    List<String> newWallpapers = apiResponse.map<String>((item) {
      if (_selectedApi == 'Unsplash') {
        return item['urls']['regular'] as String;
      } else {
        return item['src']['original'] as String;
      }
    }).toList();

    setState(() {
      _featuredWallpapers.addAll(newWallpapers);
    });
  } catch (e) {
    setState(() {
      _error = 'Failed to load more featured wallpapers: $e';
    });
    print('Error fetching more featured wallpapers: $e');
  }
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
    if (_selectedApi == 'Unsplash') {
      apiResponse = await _unsplashApi.fetchWallpapers(
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

    List<ImageDetails> newWallpapers = apiResponse.map((item) {
      if (_selectedApi == 'Unsplash') {
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
          categories: item['tags'] ?? [],
          resolution: '${item['width'] ?? 0} x ${item['height'] ?? 0}',
          copyright: 'Pexels License',
        );
      }
    }).where((image) => image.url.isNotEmpty).toList();

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


  void _onItemTapped(int index) {
  setState(() {
    _selectedIndex = index;
  });

  if (index == 0) {
    // "For You" tab
    _refreshWallpapers();
  } else if (index == 2) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => AccountScreen(
              selectedApi: _selectedApi,
              onApiChanged: onApiChanged,
              onPop: () {
                setState(() {
                  _selectedIndex = 0;
                });
              })),
    );
  }
}

void _refreshWallpapers() {
  setState(() {
    _wallpapers = [];
    _featuredWallpapers = [];
    _wallpaperPage = 1;
    _featuredWallpaperPage = 1;
  });
  _fetchWallpapers();
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

  Future<void> _setWallpaper(String imageUrl, int wallpaperManagerOption) async {
    try {
      // Download the image
      var response = await http.get(Uri.parse(imageUrl));
      var bytes = response.bodyBytes;

      // Get the temporary directory
      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/temp_wallpaper.jpg';

      // Save the image to a temporary file
      File(imagePath).writeAsBytesSync(bytes);

      // Request storage permission if needed
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Permission to access storage denied');
      }

      // Set the wallpaper
      if (wallpaperManagerOption == WallpaperManager.HOME_SCREEN ||
          wallpaperManagerOption == 2) {
        await WallpaperManager.setWallpaperFromFile(
            imagePath, WallpaperManager.HOME_SCREEN);
      }
      if (wallpaperManagerOption == WallpaperManager.LOCK_SCREEN ||
          wallpaperManagerOption == 2) {
        await WallpaperManager.setWallpaperFromFile(
            imagePath, WallpaperManager.LOCK_SCREEN);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallpaper set successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set wallpaper: $e')),
      );
    }
  }


  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  Widget _buildSearchBar() {
    return AnimatedContainer(
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
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isSearchExpanded = !_isSearchExpanded;
                  if (!_isSearchExpanded) {
                    _searchController.clear();
                  }
                });
              },
              child: Icon(
                _isSearchExpanded ? Icons.close : Icons.search,
                color: Colors.grey[600],
              ),
            ),
          ),
          if (_isSearchExpanded)
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search',
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
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _featuredWallpapers.length,
        (index) => Container(
          width: 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index ? Colors.blue : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedWallpaper() {
    return SizedBox(
      height: 250,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _featuredWallpapers.length,
        onPageChanged: (int page) {
          setState(() {
            _currentPage = page;
          });
        },
        itemBuilder: (BuildContext context, int index) {
          return GestureDetector(
            onTap: () {
              _showImageDetailsModal(
                context,
                ImageDetails(
                  url: _featuredWallpapers[index],
                  name: _getImageName(_featuredWallpapers[index]),
                  artistName: _getArtistName(_featuredWallpapers[index]),
                  artistAvatarUrl: _getArtistAvatarUrl(_featuredWallpapers[index]),
                  categories: _getImageCategories(_featuredWallpapers[index]).split(', '),
                  resolution: _getImageResolution(_featuredWallpapers[index]),
                  copyright: _getImageCopyright(_featuredWallpapers[index]),
                ),
              );
            },
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: _featuredWallpapers[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  alignment: Alignment.center,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Wallpaper of the Week',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildPageIndicator(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWallpaperGrid() {
  return GridView.builder(
    controller: _scrollController,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      childAspectRatio: 0.7,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
    ),
    itemCount: _wallpapers.length + 1,
    itemBuilder: (BuildContext context, int index) {
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
  );
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
                                          setWallpaper: _setWallpaper,
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
                              CircleAvatar(
                                backgroundImage: imageDetails.artistAvatarUrl.isNotEmpty
                                    ? NetworkImage(imageDetails.artistAvatarUrl)
                                    : const AssetImage('assets/placeholder.png') as ImageProvider, // Placeholder
                              ),
                              const SizedBox(width: 8),
                              Text(
                                imageDetails.artistName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.add_circle_outline),
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

  // Helper methods to get image details from API response
  String _getImageName(String imageUrl) {
    // Implement logic to get image name from API response
    return "Image Name"; // Placeholder
  }

  String _getArtistName(String imageUrl) {
    // Implement logic to get artist name from API response
    return "Artist Name"; // Placeholder
  }

  String _getArtistAvatarUrl(String imageUrl) {
    // Implement logic to get artist avatar URL from API response
    return "https://example.com/avatar.jpg"; // Placeholder
  }

  String _getImageCategories(String imageUrl) {
    // Implement logic to get image categories from API response
    return "Category 1, Category 2"; // Placeholder
  }

  String _getImageResolution(String imageUrl) {
    // Implement logic to get image resolution from API response
    return "1920 x 1080"; // Placeholder
  }

  String _getImageCopyright(String imageUrl) {
    // Implement logic to get image copyright from API response
    return "Copyright 2024"; // Placeholder
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
                    SliverAppBar(
                      expandedHeight: 250.0,
                      floating: false,
                      pinned: true,
                      flexibleSpace: FlexibleSpaceBar(
                        background: _buildFeaturedWallpaper(),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverAppBarDelegate(
                        minHeight: 60.0,
                        maxHeight: 60.0,
                        child: Container(
                          color: Colors.white,
                          child: Center(
                            child: _buildSearchBar(),
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
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'For You',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}

class AccountScreen extends StatefulWidget {
  final String selectedApi;
  final Function(String) onApiChanged;
  final Function() onPop;

  const AccountScreen({
    Key? key,
    required this.selectedApi,
    required this.onApiChanged,
    required this.onPop,
  }) : super(key: key);

  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Select API:'),
            DropdownButton<String>(
              value: widget.selectedApi,
              onChanged: (String? newValue) {
                if (newValue != null && newValue != widget.selectedApi) {
                  widget.onApiChanged(newValue);
                  widget.onPop();
                  Navigator.pop(context);
                }
              },
              items: <String>['Unsplash', 'Pexels']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class WallpaperDialog extends StatefulWidget {
  final String imageUrl;
  final Function(String, int) setWallpaper;

  const WallpaperDialog({
    Key? key,
    required this.imageUrl,
    required this.setWallpaper,
  }) : super(key: key);

  @override
  _WallpaperDialogState createState() => _WallpaperDialogState();
}

class _WallpaperDialogState extends State<WallpaperDialog> {
  int selectedOption = 0; // 0: Home Screen, 1: Lock Screen, 2: Both

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Wallpaper'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile(
            title: const Text('Home Screen'),
            value: 0,
            groupValue: selectedOption,
            onChanged: (int? value) {
              setState(() {
                selectedOption = value!;
              });
            },
          ),
          RadioListTile(
            title: const Text('Lock Screen'),
            value: 1,
            groupValue: selectedOption,
            onChanged: (int? value) {
              setState(() {
                selectedOption = value!;
              });
            },
          ),
          RadioListTile(
            title: const Text('Both'),
            value: 2,
            groupValue: selectedOption,
            onChanged: (int? value) {
              setState(() {
                selectedOption = value!;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (selectedOption == 0) {
              widget.setWallpaper(widget.imageUrl, WallpaperManager.HOME_SCREEN);
            } else if (selectedOption == 1) {
              widget.setWallpaper(widget.imageUrl, WallpaperManager.LOCK_SCREEN);
            } else {
              widget.setWallpaper(widget.imageUrl, WallpaperManager.HOME_SCREEN);
              widget.setWallpaper(widget.imageUrl, WallpaperManager.LOCK_SCREEN);
            }
            Navigator.of(context).pop();
          },
          child: const Text('Set'),
        ),
      ],
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
</content>
</write_to_file>



---

**User:**

[write_to_file for 'lib/main.dart'] Result:
The content was successfully saved to lib/main.dart.
<environment_details>
# VSCode Visible Files
android/app/src/main/AndroidManifest.xml
lib/main.dart

# VSCode Open Tabs
lib/pexels_api.dart
lib/unsplash_api.dart
android/app/src/main/AndroidManifest.xml
lib/main.dart
</environment_details>

---

**Assistant:**

<thinking>
I've updated `lib/main.dart` to fix the issue with the radio buttons in the set wallpaper dialog. Now, I need to confirm that the issue is resolved.

I can ask the user to test the app and verify that all options in the set wallpaper dialog are working correctly.
</thinking>
<ask_followup_question>
<question>I've updated the code to fix the issue with the radio buttons in the set wallpaper dialog. Can you please test the app again and let me know if all options are working correctly now?</question>
</ask_followup_question>


---

**User:**

[ask_followup_question for 'I've updated the code to fix the issue with the radio buttons in the set wallpaper dialog. Can you please test the app again and let me know if all options are working correctly now?'] Result:
<answer>
when i select lock screen option and press ok it applies the wallpaper to home screen why is that
</answer>
<environment_details>
# VSCode Visible Files
lib/main.dart

# VSCode Open Tabs
lib/pexels_api.dart
lib/unsplash_api.dart
android/app/src/main/AndroidManifest.xml
lib/main.dart
</environment_details>
[TASK RESUMPTION] This task was interrupted 20 minutes ago. It may or may not be complete, so please reassess the task context. Be aware that the project state may have changed since then. The current working directory is now '/home/user/myapp'. If the task has not been completed, retry the last step before interruption and proceed with completing the task.

Note: If you previously attempted a tool use that the user did not provide a result for, you should assume the tool use was not successful and assess whether you should retry.
<environment_details>
# VSCode Visible Files
lib/main.dart

# VSCode Open Tabs
lib/pexels_api.dart
lib/unsplash_api.dart
android/app/src/main/AndroidManifest.xml
lib/main.dart

# Current Working Directory (/home/user/myapp) Files
.gitignore
.metadata
analysis_options.yaml
pubspec.lock
pubspec.yaml
README.md
android/
android/.gitignore
android/build.gradle
android/gradle.properties
android/settings.gradle
android/app/
android/app/build.gradle
android/app/src/
android/app/src/debug/
android/app/src/debug/AndroidManifest.xml
android/app/src/main/
android/app/src/main/AndroidManifest.xml
android/app/src/main/java/
android/app/src/main/java/io/
android/app/src/main/java/io/flutter/
android/app/src/main/java/io/flutter/plugins/
android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java
android/app/src/main/kotlin/
android/app/src/main/kotlin/com/
android/app/src/main/kotlin/com/example/
android/app/src/main/kotlin/com/example/myapp/
android/app/src/main/kotlin/com/example/myapp/MainActivity.kt
android/app/src/main/res/
android/app/src/main/res/drawable/
android/app/src/main/res/drawable/launch_background.xml
android/app/src/main/res/drawable-v21/
android/app/src/main/res/drawable-v21/launch_background.xml
android/app/src/main/res/mipmap-hdpi/
android/app/src/main/res/mipmap-hdpi/ic_launcher.png
android/app/src/main/res/mipmap-mdpi/
android/app/src/main/res/mipmap-mdpi/ic_launcher.png
android/app/src/main/res/mipmap-xhdpi/
android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
android/app/src/main/res/mipmap-xxhdpi/
android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
android/app/src/main/res/mipmap-xxxhdpi/
android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
android/app/src/main/res/values/
android/app/src/main/res/values/styles.xml
android/app/src/main/res/values-night/
android/app/src/main/res/values-night/styles.xml
android/app/src/main/res/xml/
android/app/src/main/res/xml/network_security_config.xml
android/app/src/profile/
android/app/src/profile/AndroidManifest.xml
android/gradle/
android/gradle/wrapper/
android/gradle/wrapper/gradle-wrapper.jar
android/gradle/wrapper/gradle-wrapper.properties
build/
lib/
lib/Downloadwallpaper.png
lib/main.dart
lib/pexels_api.dart
lib/unsplash_api.dart
lib/zxc.PNG
test/
test/widget_test.dart
web/
web/favicon.png
web/index.html
web/manifest.json
web/icons/
web/icons/Icon-192.png
web/icons/Icon-512.png
web/icons/Icon-maskable-192.png
web/icons/Icon-maskable-512.png
</environment_details>

---

**Assistant:**

<thinking>
The user reported that selecting the "Lock Screen" option in the dialog still sets the wallpaper to the home screen. This indicates an error in the `_setWallpaper` function, specifically in the logic for setting the lock screen wallpaper.

I need to examine the `_setWallpaper` function in `lib/main.dart` to identify the issue. I can use the `read_file` tool to read the contents of `lib/main.dart` again and then analyze the `_setWallpaper` function.
</thinking>
<read_file>
<path>lib/main.dart</path>
</read_file>


---

**User:**

[read_file for 'lib/main.dart'] Result:
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myapp/unsplash_api.dart';
import 'package:myapp/pexels_api.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:math';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_wallpaper_manager/flutter_wallpaper_manager.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallpaper App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class ImageDetails {
  final String url;
  final String name;
  final String artistName;
  final String artistAvatarUrl;
  final List<String> categories;
  final String resolution;
  final String copyright;

  ImageDetails({
    required this.url,
    required this.name,
    required this.artistName,
    required this.artistAvatarUrl,
    required this.categories,
    required this.resolution,
    required this.copyright,
  });
}

class _MyHomePageState extends State<MyHomePage> {
  final UnsplashApi _unsplashApi = UnsplashApi();
  List<ImageDetails> _wallpapers = [];
  List<String> _featuredWallpapers = [];
  bool _isLoading = true;
  String _error = '';
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;
  int _featuredWallpaperPage = 1;
  int _wallpaperPage = 1;
  bool _isWallpaperLoading = false;
  String _searchQuery = '';
  String _selectedApi = 'Unsplash';
  int _selectedIndex = 0;

    @override
  void initState() {
    super.initState();
    _fetchWallpapers();
    _scrollController.addListener(_onScroll);
    _pageController.addListener(_onPageScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void onApiChanged(String newApi) {
  setState(() {
    _selectedApi = newApi;
    _wallpapers = [];
    _featuredWallpapers = [];
    _wallpaperPage = 1;
    _featuredWallpaperPage = 1;
  });
  _fetchWallpapers();
}

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _fetchMoreWallpapers();
    }
  }

  void _onPageScroll() {
    if (_pageController.position.pixels ==
        _pageController.position.maxScrollExtent) {
      _fetchMoreFeaturedWallpapers();
    }
  }

   Future<void> _fetchWallpapers({String? query}) async {
  setState(() {
    _isLoading = true;
    _error = '';
    if (query != null) {
      _wallpapers = [];
      _wallpaperPage = 1;
    }
  });

  try {
    // Fetch regular wallpapers
    List<dynamic> apiResponse;
    if (_selectedApi == 'Unsplash') {
      apiResponse = await _unsplashApi.fetchWallpapers(
          page: _wallpaperPage, query: query);
    } else {
      apiResponse = await PexelsApi.getPhotos(query ?? '', _wallpaperPage);
    }

    List<ImageDetails> newWallpapers = _processApiResponse(apiResponse);

    // Fetch featured wallpapers
    List<dynamic> featuredResponse;
    if (_selectedApi == 'Unsplash') {
      featuredResponse = await _unsplashApi.fetchWallpapers(
          query: 'featured landscape', page: _featuredWallpaperPage);
    } else {
      featuredResponse = await PexelsApi.getPhotos('featured landscape', _featuredWallpaperPage);
    }

    List<String> newFeaturedWallpapers = _processApiResponse(featuredResponse)
        .take(5)
        .map((item) => item.url)
        .toList();

    setState(() {
      _wallpapers = newWallpapers;
      _featuredWallpapers = newFeaturedWallpapers;
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
    if (_selectedApi == 'Unsplash') {
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
        categories: item['tags'] ?? [],
        resolution: '${item['width'] ?? 0} x ${item['height'] ?? 0}',
        copyright: 'Pexels License',
      );
    }
  }).where((image) => image.url.isNotEmpty).toList();
}

  Future<void> _fetchMoreFeaturedWallpapers() async {
  try {
    _featuredWallpaperPage++;

    List<dynamic> apiResponse;
    if (_selectedApi == 'Unsplash') {
      apiResponse = await _unsplashApi.fetchWallpapers(
          page: _featuredWallpaperPage, query: _searchQuery);
    } else {
      apiResponse = await PexelsApi.getPhotos(_searchQuery, _featuredWallpaperPage);
    }

    if (apiResponse.isEmpty) {
      throw Exception('No more featured photos returned from $_selectedApi API');
    }

    List<String> newWallpapers = apiResponse.map<String>((item) {
      if (_selectedApi == 'Unsplash') {
        return item['urls']['regular'] as String;
      } else {
        return item['src']['original'] as String;
      }
    }).toList();

    setState(() {
      _featuredWallpapers.addAll(newWallpapers);
    });
  } catch (e) {
    setState(() {
      _error = 'Failed to load more featured wallpapers: $e';
    });
    print('Error fetching more featured wallpapers: $e');
  }
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
    if (_selectedApi == 'Unsplash') {
      apiResponse = await _unsplashApi.fetchWallpapers(
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

    List<ImageDetails> newWallpapers = apiResponse.map((item) {
      if (_selectedApi == 'Unsplash') {
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
          categories: item['tags'] ?? [],
          resolution: '${item['width'] ?? 0} x ${item['height'] ?? 0}',
          copyright: 'Pexels License',
        );
      }
    }).where((image) => image.url.isNotEmpty).toList();

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


  void _onItemTapped(int index) {
  setState(() {
    _selectedIndex = index;
  });

  if (index == 0) {
    // "For You" tab
    _refreshWallpapers();
  } else if (index == 2) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => AccountScreen(
              selectedApi: _selectedApi,
              onApiChanged: onApiChanged,
              onPop: () {
                setState(() {
                  _selectedIndex = 0;
                });
              })),
    );
  }
}

void _refreshWallpapers() {
  setState(() {
    _wallpapers = [];
    _featuredWallpapers = [];
    _wallpaperPage = 1;
    _featuredWallpaperPage = 1;
  });
  _fetchWallpapers();
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

  Future<void> _setWallpaper(String imageUrl, int wallpaperManagerOption) async {
    try {
      // Download the image
      var response = await http.get(Uri.parse(imageUrl));
      var bytes = response.bodyBytes;

      // Get the temporary directory
      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/temp_wallpaper.jpg';

      // Save the image to a temporary file
      File(imagePath).writeAsBytesSync(bytes);

      // Request storage permission if needed
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Permission to access storage denied');
      }

      // Set the wallpaper
      if (wallpaperManagerOption == WallpaperManager.HOME_SCREEN ||
          wallpaperManagerOption == 2) {
        await WallpaperManager.setWallpaperFromFile(
            imagePath, WallpaperManager.HOME_SCREEN);
      }
      if (wallpaperManagerOption == WallpaperManager.LOCK_SCREEN ||
          wallpaperManagerOption == 2) {
        await WallpaperManager.setWallpaperFromFile(
            imagePath, WallpaperManager.LOCK_SCREEN);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallpaper set successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set wallpaper: $e')),
      );
    }
  }


  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  Widget _buildSearchBar() {
    return AnimatedContainer(
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
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isSearchExpanded = !_isSearchExpanded;
                  if (!_isSearchExpanded) {
                    _searchController.clear();
                  }
                });
              },
              child: Icon(
                _isSearchExpanded ? Icons.close : Icons.search,
                color: Colors.grey[600],
              ),
            ),
          ),
          if (_isSearchExpanded)
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search',
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
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _featuredWallpapers.length,
        (index) => Container(
          width: 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index ? Colors.blue : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedWallpaper() {
    return SizedBox(
      height: 250,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _featuredWallpapers.length,
        onPageChanged: (int page) {
          setState(() {
            _currentPage = page;
          });
        },
        itemBuilder: (BuildContext context, int index) {
          return GestureDetector(
            onTap: () {
              _showImageDetailsModal(
                context,
                ImageDetails(
                  url: _featuredWallpapers[index],
                  name: _getImageName(_featuredWallpapers[index]),
                  artistName: _getArtistName(_featuredWallpapers[index]),
                  artistAvatarUrl: _getArtistAvatarUrl(_featuredWallpapers[index]),
                  categories: _getImageCategories(_featuredWallpapers[index]).split(', '),
                  resolution: _getImageResolution(_featuredWallpapers[index]),
                  copyright: _getImageCopyright(_featuredWallpapers[index]),
                ),
              );
            },
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: _featuredWallpapers[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  alignment: Alignment.center,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Wallpaper of the Week',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildPageIndicator(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWallpaperGrid() {
  return GridView.builder(
    controller: _scrollController,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      childAspectRatio: 0.7,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
    ),
    itemCount: _wallpapers.length + 1,
    itemBuilder: (BuildContext context, int index) {
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
  );
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
                                          setWallpaper: _setWallpaper,
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
                              CircleAvatar(
                                backgroundImage: imageDetails.artistAvatarUrl.isNotEmpty
                                    ? NetworkImage(imageDetails.artistAvatarUrl)
                                    : const AssetImage('assets/placeholder.png') as ImageProvider, // Placeholder
                              ),
                              const SizedBox(width: 8),
                              Text(
                                imageDetails.artistName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.add_circle_outline),
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

  // Helper methods to get image details from API response
  String _getImageName(String imageUrl) {
    // Implement logic to get image name from API response
    return "Image Name"; // Placeholder
  }

  String _getArtistName(String imageUrl) {
    // Implement logic to get artist name from API response
    return "Artist Name"; // Placeholder
  }

  String _getArtistAvatarUrl(String imageUrl) {
    // Implement logic to get artist avatar URL from API response
    return "https://example.com/avatar.jpg"; // Placeholder
  }

  String _getImageCategories(String imageUrl) {
    // Implement logic to get image categories from API response
    return "Category 1, Category 2"; // Placeholder
  }

  String _getImageResolution(String imageUrl) {
    // Implement logic to get image resolution from API response
    return "1920 x 1080"; // Placeholder
  }

  String _getImageCopyright(String imageUrl) {
    // Implement logic to get image copyright from API response
    return "Copyright 2024"; // Placeholder
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
                    SliverAppBar(
                      expandedHeight: 250.0,
                      floating: false,
                      pinned: true,
                      flexibleSpace: FlexibleSpaceBar(
                        background: _buildFeaturedWallpaper(),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverAppBarDelegate(
                        minHeight: 60.0,
                        maxHeight: 60.0,
                        child: Container(
                          color: Colors.white,
                          child: Center(
                            child: _buildSearchBar(),
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
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'For You',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}

class AccountScreen extends StatefulWidget {
  final String selectedApi;
  final Function(String) onApiChanged;
  final Function() onPop;

  const AccountScreen({
    Key? key,
    required this.selectedApi,
    required this.onApiChanged,
    required this.onPop,
  }) : super(key: key);

  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Select API:'),
            DropdownButton<String>(
              value: widget.selectedApi,
              onChanged: (String? newValue) {
                if (newValue != null && newValue != widget.selectedApi) {
                  widget.onApiChanged(newValue);
                  widget.onPop();
                  Navigator.pop(context);
                }
              },
              items: <String>['Unsplash', 'Pexels']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class WallpaperDialog extends StatefulWidget {
  final String imageUrl;
  final Function(String, int) setWallpaper;

  const WallpaperDialog({
    Key? key,
    required this.imageUrl,
    required this.setWallpaper,
  }) : super(key: key);

  @override
  _WallpaperDialogState createState() => _WallpaperDialogState();
}

class _WallpaperDialogState extends State<WallpaperDialog> {
  int selectedOption = 0; // 0: Home Screen, 1: Lock Screen, 2: Both

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Wallpaper'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile(
            title: const Text('Home Screen'),
            value: 0,
            groupValue: selectedOption,
            onChanged: (int? value) {
              setState(() {
                selectedOption = value!;
              });
            },
          ),
          RadioListTile(
            title: const Text('Lock Screen'),
            value: 1,
            groupValue: selectedOption,
            onChanged: (int? value) {
              setState(() {
                selectedOption = value!;
              });
            },
          ),
          RadioListTile(
            title: const Text('Both'),
            value: 2,
            groupValue: selectedOption,
            onChanged: (int? value) {
              setState(() {
                selectedOption = value!;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (selectedOption == 0) {
              widget.setWallpaper(widget.imageUrl, WallpaperManager.HOME_SCREEN);
            } else if (selectedOption == 1) {
              widget.setWallpaper(widget.imageUrl, WallpaperManager.LOCK_SCREEN);
            } else {
              widget.setWallpaper(widget.imageUrl, WallpaperManager.HOME_SCREEN);
              widget.setWallpaper(widget.imageUrl, WallpaperManager.LOCK_SCREEN);
            }
            Navigator.of(context).pop();
          },
          child: const Text('Set'),
        ),
      ],
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

<environment_details>
# VSCode Visible Files
lib/unsplash_api.dart

# VSCode Open Tabs
lib/pexels_api.dart
lib/unsplash_api.dart
android/app/src/main/AndroidManifest.xml
lib/main.dart
</environment_details>

---

**Assistant:**

<thinking>
I have the contents of `lib/main.dart`. Now I need to analyze the `_setWallpaper` function to understand why selecting the "Lock Screen" option sets the wallpaper to the home screen.

```dart
  Future<void> _setWallpaper(String imageUrl, int wallpaperManagerOption) async {
    try {
      // Download the image
      var response = await http.get(Uri.parse(imageUrl));
      var bytes = response.bodyBytes;

      // Get the temporary directory
      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/temp_wallpaper.jpg';

      // Save the image to a temporary file
      File(imagePath).writeAsBytesSync(bytes);

      // Request storage permission if needed
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Permission to access storage denied');
      }

      // Set the wallpaper
      if (wallpaperManagerOption == WallpaperManager.HOME_SCREEN ||
          wallpaperManagerOption == 2) {
        await WallpaperManager.setWallpaperFromFile(
            imagePath, WallpaperManager.HOME_SCREEN);
      }
      if (wallpaperManagerOption == WallpaperManager.LOCK_SCREEN ||
          wallpaperManagerOption == 2) {
        await WallpaperManager.setWallpaperFromFile(
            imagePath, WallpaperManager.LOCK_SCREEN);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallpaper set successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set wallpaper: $e')),
      );
    }
  }
```

The issue is that the code is calling `WallpaperManager.setWallpaperFromFile` twice, once for the home screen and once for the lock screen, regardless of the selected option. This means that if the user selects "Lock Screen", the wallpaper will be set to both the home screen and the lock screen.

To fix this, I need to modify the code to only call `WallpaperManager.setWallpaperFromFile` once, based on the selected option. I can do this by removing the second `if` block and using an `else if` block instead.

I will use the `write_to_file` tool to update `lib/main.dart` with the corrected code.
</thinking>
<write_to_file>
<path>lib/main.dart</path>
<content>
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myapp/unsplash_api.dart';
import 'package:myapp/pexels_api.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:math';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_wallpaper_manager/flutter_wallpaper_manager.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallpaper App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class ImageDetails {
  final String url;
  final String name;
  final String artistName;
  final String artistAvatarUrl;
  final List<String> categories;
  final String resolution;
  final String copyright;

  ImageDetails({
    required this.url,
    required this.name,
    required this.artistName,
    required this.artistAvatarUrl,
    required this.categories,
    required this.resolution,
    required this.copyright,
  });
}

class _MyHomePageState extends State<MyHomePage> {
  final UnsplashApi _unsplashApi = UnsplashApi();
  List<ImageDetails> _wallpapers = [];
  List<String> _featuredWallpapers = [];
  bool _isLoading = true;
  String _error = '';
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;
  int _featuredWallpaperPage = 1;
  int _wallpaperPage = 1;
  bool _isWallpaperLoading = false;
  String _searchQuery = '';
  String _selectedApi = 'Unsplash';
  int _selectedIndex = 0;

    @override
  void initState() {
    super.initState();
    _fetchWallpapers();
    _scrollController.addListener(_onScroll);
    _pageController.addListener(_onPageScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void onApiChanged(String newApi) {
  setState(() {
    _selectedApi = newApi;
    _wallpapers = [];
    _featuredWallpapers = [];
    _wallpaperPage = 1;
    _featuredWallpaperPage = 1;
  });
  _fetchWallpapers();
}

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _fetchMoreWallpapers();
    }
  }

  void _onPageScroll() {
    if (_pageController.position.pixels ==
        _pageController.position.maxScrollExtent) {
      _fetchMoreFeaturedWallpapers();
    }
  }

   Future<void> _fetchWallpapers({String? query}) async {
  setState(() {
    _isLoading = true;
    _error = '';
    if (query != null) {
      _wallpapers = [];
      _wallpaperPage = 1;
    }
  });

  try {
    // Fetch regular wallpapers
    List<dynamic> apiResponse;
    if (_selectedApi == 'Unsplash') {
      apiResponse = await _unsplashApi.fetchWallpapers(
          page: _wallpaperPage, query: query);
    } else {
      apiResponse = await PexelsApi.getPhotos(query ?? '', _wallpaperPage);
    }

    List<ImageDetails> newWallpapers = _processApiResponse(apiResponse);

    // Fetch featured wallpapers
    List<dynamic> featuredResponse;
    if (_selectedApi == 'Unsplash') {
      featuredResponse = await _unsplashApi.fetchWallpapers(
          query: 'featured landscape', page: _featuredWallpaperPage);
    } else {
      featuredResponse = await PexelsApi.getPhotos('featured landscape', _featuredWallpaperPage);
    }

    List<String> newFeaturedWallpapers = _processApiResponse(featuredResponse)
        .take(5)
        .map((item) => item.url)
        .toList();

    setState(() {
      _wallpapers = newWallpapers;
      _featuredWallpapers = newFeaturedWallpapers;
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
    if (_selectedApi == 'Unsplash') {
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
        categories: item['tags'] ?? [],
        resolution: '${item['width'] ?? 0} x ${item['height'] ?? 0}',
        copyright: 'Pexels License',
      );
    }
  }).where((image) => image.url.isNotEmpty).toList();
}

  Future<void> _fetchMoreFeaturedWallpapers() async {
  try {
    _featuredWallpaperPage++;

    List<dynamic> apiResponse;
    if (_selectedApi == 'Unsplash') {
      apiResponse = await _unsplashApi.fetchWallpapers(
          page: _featuredWallpaperPage, query: _searchQuery);
    } else {
      apiResponse = await PexelsApi.getPhotos(_searchQuery, _featuredWallpaperPage);
    }

    if (apiResponse.isEmpty) {
      throw Exception('No more featured photos returned from $_selectedApi API');
    }

    List<String> newWallpapers = apiResponse.map<String>((item) {
      if (_selectedApi == 'Unsplash') {
        return item['urls']['regular'] as String;
      } else {
        return item['src']['original'] as String;
      }
    }).toList();

    setState(() {
      _featuredWallpapers.addAll(newWallpapers);
    });
  } catch (e) {
    setState(() {
      _error = 'Failed to load more featured wallpapers: $e';
    });
    print('Error fetching more featured wallpapers: $e');
  }
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
    if (_selectedApi == 'Unsplash') {
      apiResponse = await _unsplashApi.fetchWallpapers(
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

    List<ImageDetails> newWallpapers = apiResponse.map((item) {
      if (_selectedApi == 'Unsplash') {
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
          categories: item['tags'] ?? [],
          resolution: '${item['width'] ?? 0} x ${item['height'] ?? 0}',
          copyright: 'Pexels License',
        );
      }
    }).where((image) => image.url.isNotEmpty).toList();

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


  void _onItemTapped(int index) {
  setState(() {
    _selectedIndex = index;
  });

  if (index == 0) {
    // "For You" tab
    _refreshWallpapers();
  } else if (index == 2) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => AccountScreen(
              selectedApi: _selectedApi,
              onApiChanged: onApiChanged,
              onPop: () {
                setState(() {
                  _selectedIndex = 0;
                });
              })),
    );
  }
}

void _refreshWallpapers() {
  setState(() {
    _wallpapers = [];
    _featuredWallpapers = [];
    _wallpaperPage = 1;
    _featuredWallpaperPage = 1;
  });
  _fetchWallpapers();
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

  Future<void> _setWallpaper(String imageUrl, int wallpaperManagerOption) async {
    try {
      // Download the image
      var response = await http.get(Uri.parse(imageUrl));
      var bytes = response.bodyBytes;

      // Get the temporary directory
      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/temp_wallpaper.jpg';

      // Save the image to a temporary file
      File(imagePath).writeAsBytesSync(bytes);

      // Request storage permission if needed
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Permission to access storage denied');
      }

      // Set the wallpaper
      if (wallpaperManagerOption == WallpaperManager.HOME_SCREEN) {
        await WallpaperManager.setWallpaperFromFile(
            imagePath, WallpaperManager.HOME_SCREEN);
      } else if (wallpaperManagerOption == WallpaperManager.LOCK_SCREEN) {
        await WallpaperManager.setWallpaperFromFile(
            imagePath, WallpaperManager.LOCK_SCREEN);
      } else if (wallpaperManagerOption == 2) {
        await WallpaperManager.setWallpaperFromFile(
            imagePath, WallpaperManager.HOME_SCREEN);
        await WallpaperManager.setWallpaperFromFile(
            imagePath, WallpaperManager.LOCK_SCREEN);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallpaper set successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set wallpaper: $e')),
      );
    }
  }


  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  Widget _buildSearchBar() {
    return AnimatedContainer(
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
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isSearchExpanded = !_isSearchExpanded;
                  if (!_isSearchExpanded) {
                    _searchController.clear();
                  }
                });
              },
              child: Icon(
                _isSearchExpanded ? Icons.close : Icons.search,
                color: Colors.grey[600],
              ),
            ),
          ),
          if (_isSearchExpanded)
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search',
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
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _featuredWallpapers.length,
        (index) => Container(
          width: 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index ? Colors.blue : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedWallpaper() {
    return SizedBox(
      height: 250,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _featuredWallpapers.length,
        onPageChanged: (int page) {
          setState(() {
            _currentPage = page;
          });
        },
        itemBuilder: (BuildContext context, int index) {
          return GestureDetector(
            onTap: () {
              _showImageDetailsModal(
                context,
                ImageDetails(
                  url: _featuredWallpapers[index],
                  name: _getImageName(_featuredWallpapers[index]),
                  artistName: _getArtistName(_featuredWallpapers[index]),
                  artistAvatarUrl: _getArtistAvatarUrl(_featuredWallpapers[index]),
                  categories: _getImageCategories(_featuredWallpapers[index]).split(', '),
                  resolution: _getImageResolution(_featuredWallpapers[index]),
                  copyright: _getImageCopyright(_featuredWallpapers[index]),
                ),
              );
            },
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: _featuredWallpapers[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  alignment: Alignment.center,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Wallpaper of the Week',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildPageIndicator(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWallpaperGrid() {
  return GridView.builder(
    controller: _scrollController,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      childAspectRatio: 0.7,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
    ),
    itemCount: _wallpapers.length + 1,
    itemBuilder: (BuildContext context, int index) {
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
  );
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
                                          setWallpaper: _setWallpaper,
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
                              CircleAvatar(
                                backgroundImage: imageDetails.artistAvatarUrl.isNotEmpty
                                    ? NetworkImage(imageDetails.artistAvatarUrl)
                                    : const AssetImage('assets/placeholder.png') as ImageProvider, // Placeholder
                              ),
                              const SizedBox(width: 8),
                              Text(
                                imageDetails.artistName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.add_circle_outline),
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

  // Helper methods to get image details from API response
  String _getImageName(String imageUrl) {
    // Implement logic to get image name from API response
    return "Image Name"; // Placeholder
  }

  String _getArtistName(String imageUrl) {
    // Implement logic to get artist name from API response
    return "Artist Name"; // Placeholder
  }

  String _getArtistAvatarUrl(String imageUrl) {
    // Implement logic to get artist avatar URL from API response
    return "https://example.com/avatar.jpg"; // Placeholder
  }

  String _getImageCategories(String imageUrl) {
    // Implement logic to get image categories from API response
    return "Category 1, Category 2"; // Placeholder
  }

  String _getImageResolution(String imageUrl) {
    // Implement logic to get image resolution from API response
    return "1920 x 1080"; // Placeholder
  }

  String _getImageCopyright(String imageUrl) {
    // Implement logic to get image copyright from API response
    return "Copyright 2024"; // Placeholder
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
                    SliverAppBar(
                      expandedHeight: 250.0,
                      floating: false,
                      pinned: true,
                      flexibleSpace: FlexibleSpaceBar(
                        background: _buildFeaturedWallpaper(),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverAppBarDelegate(
                        minHeight: 60.0,
                        maxHeight: 60.0,
                        child: Container(
                          color: Colors.white,
                          child: Center(
                            child: _buildSearchBar(),
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
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'For You',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}

class AccountScreen extends StatefulWidget {
  final String selectedApi;
  final Function(String) onApiChanged;
  final Function() onPop;

  const AccountScreen({
    Key? key,
    required this.selectedApi,
    required this.onApiChanged,
    required this.onPop,
  }) : super(key: key);

  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Select API:'),
            DropdownButton<String>(
              value: widget.selectedApi,
              onChanged: (String? newValue) {
                if (newValue != null && newValue != widget.selectedApi) {
                  widget.onApiChanged(newValue);
                  widget.onPop();
                  Navigator.pop(context);
                }
              },
              items: <String>['Unsplash', 'Pexels']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class WallpaperDialog extends StatefulWidget {
  final String imageUrl;
  final Function(String, int) setWallpaper;

  const WallpaperDialog({
    Key? key,
    required this.imageUrl,
    required this.setWallpaper,
  }) : super(key: key);

  @override
  _WallpaperDialogState createState() => _WallpaperDialogState();
}

class _WallpaperDialogState extends State<WallpaperDialog> {
  int selectedOption = 0; // 0: Home Screen, 1: Lock Screen, 2: Both

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Wallpaper'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile(
            title: const Text('Home Screen'),
            value: 0,
            groupValue: selectedOption,
            onChanged: (int? value) {
              setState(() {
                selectedOption = value!;
              });
            },
          ),
          RadioListTile(
            title: const Text('Lock Screen'),
            value: 1,
            groupValue: selectedOption,
            onChanged: (int? value) {
              setState(() {
                selectedOption = value!;
              });
            },
          ),
          RadioListTile(
            title: const Text('Both'),
            value: 2,
            groupValue: selectedOption,
            onChanged: (int? value) {
              setState(() {
                selectedOption = value!;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (selectedOption == 0) {
              widget.setWallpaper(widget.imageUrl, WallpaperManager.HOME_SCREEN);
            } else if (selectedOption == 1) {
              widget.setWallpaper(widget.imageUrl, WallpaperManager.LOCK_SCREEN);
            } else if (selectedOption == 2) {
              widget.setWallpaper(widget.imageUrl, WallpaperManager.HOME_SCREEN);
              widget.setWallpaper(widget.imageUrl, WallpaperManager.LOCK_SCREEN);
            }
            Navigator.of(context).pop();
          },
          child: const Text('Set'),
        ),
      ],
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
</content>
</write_to_file>



---

**User:**

[write_to_file for 'lib/main.dart'] Result:
The content was successfully saved to lib/main.dart.
<environment_details>
# VSCode Visible Files
lib/unsplash_api.dart
lib/main.dart

# VSCode Open Tabs
lib/pexels_api.dart
lib/unsplash_api.dart
android/app/src/main/AndroidManifest.xml
lib/main.dart
</environment_details>

---

**Assistant:**

<thinking>
I've updated `lib/main.dart` to fix the issue with the set wallpaper logic. Now, I need to confirm that the issue is resolved.

I can ask the user to test the app and verify that all options in the set wallpaper dialog are working correctly.
</thinking>
<ask_followup_question>
<question>I've updated the code to fix the issue with the set wallpaper logic. Can you please test the app again and let me know if all options in the set wallpaper dialog are working correctly now?</question>
</ask_followup_question>



