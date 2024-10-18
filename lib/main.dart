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
import 'package:myapp/explore_tab.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) {
    return context.findAncestorStateOfType<_MyAppState>()!;
  }
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system; // Default to system theme

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallpaper App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
        brightness: Brightness.light, // Light theme
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark, // Dark theme
      ),
      themeMode: _themeMode, // Use system theme
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
  List<ImageDetails> _featuredWallpapers = [];
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
  Widget _currentTab =
      Container(); // Placeholder for the currently displayed tab
  late ValueNotifier<Future<List<ImageDetails>>> _wallpapersFuture;

  @override
  void initState() {
    super.initState();
    _requestStoragePermission(); // Request storage permission on app start
    _wallpapersFuture = ValueNotifier(_fetchWallpapers());
    _scrollController.addListener(_onScroll);
    _pageController.addListener(_onPageScroll);
    _currentTab = _buildWallpaperGrid();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    _wallpapersFuture.dispose();
    super.dispose();
  }

  // Function to request storage permission
  Future<void> _requestStoragePermission() async {
    var status = await Permission.storage.request();
    if (status.isGranted) {
      print('Storage permission granted');
    } else if (status.isDenied) {
      print('Storage permission denied');
      // You can show a dialog to the user explaining why you need the permission
    } else if (status.isPermanentlyDenied) {
      print('Storage permission permanently denied');
      // You can show a dialog to the user explaining how to enable the permission from app settings
    }
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

  Future<List<ImageDetails>> _fetchWallpapers({String? query}) async {
    setState(() {
      _isLoading = true;
      _error = '';
      if (query != null) {
        _wallpapers = [];
        _wallpaperPage = 1;
      }
    });

    try {
      List<dynamic> apiResponse;
      if (_selectedApi == 'Unsplash') {
        apiResponse = await _unsplashApi.fetchWallpapers(
            page: _wallpaperPage, query: query);
      } else {
        apiResponse = await PexelsApi.getPhotos(query ?? '', _wallpaperPage);
      }

      List<ImageDetails> newWallpapers = _processApiResponse(apiResponse);

      setState(() {
        if (_wallpaperPage == 1) {
          _wallpapers = newWallpapers;
        } else {
          _wallpapers.addAll(newWallpapers);
        }
        _isLoading = false;
      });

      return _wallpapers;
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load wallpapers: $e';
      });
      print('Error fetching wallpapers: $e');

      return [];
    }
  }

  List<ImageDetails> _processApiResponse(List<dynamic> apiResponse) {
    return apiResponse
        .map((item) {
          if (_selectedApi == 'Unsplash') {
            return ImageDetails(
              url: item['urls']?['regular'] ?? '',
              name:
                  item['description'] ?? item['alt_description'] ?? 'Untitled',
              artistName: item['user']?['name'] ?? 'Unknown',
              artistAvatarUrl: item['user']?['profile_image']?['medium'] ?? '',
              categories: (item['tags'] as List<dynamic>?)
                      ?.map((tag) => tag['title'] as String)
                      .toList() ??
                  [],
              resolution: '${item['width'] ?? 0} x ${item['height'] ?? 0}',
              copyright: 'Unsplash License',
            );
          } else {
            return ImageDetails(
              url: item['src']?['large2x'] ?? '',
              name: item['alt'] ?? 'Untitled',
              artistName: item['photographer'] ?? 'Unknown',
              artistAvatarUrl: item['photographer_url'] ?? '',
              categories: (item['tags'] as List<dynamic>?)
                      ?.map((tag) => tag['title'] as String)
                      .toList() ??
                  [],
              resolution: '${item['width'] ?? 0} x ${item['height'] ?? 0}',
              copyright: 'Pexels License',
            );
          }
        })
        .where((image) => image.url.isNotEmpty)
        .toList();
  }

  Future<void> _fetchMoreFeaturedWallpapers() async {
    try {
      _featuredWallpaperPage++;

      List<dynamic> apiResponse;
      if (_selectedApi == 'Unsplash') {
        apiResponse = await _unsplashApi.fetchWallpapers(
            page: _featuredWallpaperPage,
            query: 'popular'); // Fetch popular images
      } else {
        apiResponse = await PexelsApi.getPhotos(
            'popular', _featuredWallpaperPage); // Fetch popular images
      }

      if (apiResponse.isEmpty) {
        // If no popular images, fallback to random regular wallpapers
        apiResponse = await _fetchWallpapers();
        apiResponse.shuffle(); // Randomize the list
        apiResponse = apiResponse.sublist(0, 5); // Take only 5 images
      }

      List<ImageDetails> newWallpapers = _processApiResponse(apiResponse);

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

      List<ImageDetails> newWallpapers = _processApiResponse(apiResponse);

      setState(() {
        _wallpapers.addAll(newWallpapers);
        _isWallpaperLoading = false;
      });

      print('Successfully added ${newWallpapers.length} new wallpapers');
      _wallpapersFuture.value = Future.value(_wallpapers);
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
      if (index == 0) {
        // "For You" tab
        _currentTab = _buildWallpaperGrid();
        _wallpapersFuture =
            ValueNotifier(_fetchWallpapers()); // Reset and fetch wallpapers
      } else if (index == 1) {
        // "Explore" tab
        _currentTab = ExploreTab(
          selectedApi: _selectedApi,
          setWallpaper: _setWallpaper,
        );
      } else if (index == 2) {
        // "Account" tab
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => AccountScreen(
                  selectedApi: _selectedApi,
                  onApiChanged: onApiChanged,
                  onPop: () {
                    setState(() {
                      _selectedIndex = 0;
                      _currentTab =
                          _buildWallpaperGrid(); // Reset to 'For You' tab
                    });
                  })),
        );
      }
    });
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

  Future<void> _setWallpaper(
      String imageUrl, int wallpaperManagerOption) async {
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
    return FutureBuilder(
      future: _fetchMoreFeaturedWallpapers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
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
              reverse:
                  false, // Set reverse to false for right-to-left navigation
              itemBuilder: (BuildContext context, int index) {
                return GestureDetector(
                  onTap: () {
                    _showImageDetailsModal(context, _featuredWallpapers[index]);
                  },
                  child: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: _featuredWallpapers[index].url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        alignment: Alignment.center,
                        placeholder: (context, url) =>
                            const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
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
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Widget _buildWallpaperGrid() {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!_isWallpaperLoading &&
            scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 500) {
          _fetchMoreWallpapers();
        }
        return true;
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 250.0,
            floating: true,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildFeaturedWallpaper(),
            ),
          ),
          SliverToBoxAdapter(
            child: SearchBarWidget(
              onSearch: (query) {
                _searchQuery = query;
                _wallpapersFuture = ValueNotifier(
                    _fetchWallpapers(query: query)); // Update the future
              },
            ),
          ),
          ValueListenableBuilder<Future<List<ImageDetails>>>(
            valueListenable: _wallpapersFuture,
            builder: (context, future, _) {
              return FutureBuilder<List<ImageDetails>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      _wallpapers.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  } else if (snapshot.hasError) {
                    return SliverToBoxAdapter(
                      child: Center(child: Text('Error: ${snapshot.error}')),
                    );
                  } else {
                    return SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                          if (index == _wallpapers.length) {
                            return _isWallpaperLoading
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : const SizedBox.shrink();
                          } else {
                            return GestureDetector(
                              onTap: () {
                                _showImageDetailsModal(
                                    context, _wallpapers[index]);
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
                                    placeholder: (context, url) => const Center(
                                        child: CircularProgressIndicator()),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.error),
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                        childCount: _wallpapers.length + 1,
                      ),
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
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
                                  onPressed: () =>
                                      _downloadImage(imageDetails.url),
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
                              _selectedApi == 'Unsplash'
                                  ? CircleAvatar(
                                      backgroundImage: imageDetails
                                              .artistAvatarUrl.isNotEmpty
                                          ? NetworkImage(
                                              imageDetails.artistAvatarUrl)
                                          : const AssetImage(
                                                  'assets/placeholder.png')
                                              as ImageProvider,
                                    )
                                  : CircleAvatar(
                                      backgroundColor: Colors.blue,
                                      child: Text(imageDetails.artistName[0]
                                          .toUpperCase()),
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
              : _currentTab,
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
            const SizedBox(height: 20),
            const Text('Select Theme:'),
            RadioListTile<ThemeMode>(
              title: const Text('System'),
              value: ThemeMode.system,
              groupValue: MyApp.of(context)._themeMode,
              onChanged: (ThemeMode? value) {
                setState(() {
                  MyApp.of(context)._themeMode = value!;
                  MyApp.of(context).setState(() {}); // Trigger rebuild of MyApp
                });
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: MyApp.of(context)._themeMode,
              onChanged: (ThemeMode? value) {
                setState(() {
                  MyApp.of(context)._themeMode = value!;
                  MyApp.of(context).setState(() {}); // Trigger rebuild of MyApp
                });
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: MyApp.of(context)._themeMode,
              onChanged: (ThemeMode? value) {
                setState(() {
                  MyApp.of(context)._themeMode = value!;
                  MyApp.of(context).setState(() {}); // Trigger rebuild of MyApp
                });
              },
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
  int selectedOption = 0; // 0: Home Screen, 1: Lock Screen

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
              widget.setWallpaper(
                  widget.imageUrl, WallpaperManager.HOME_SCREEN);
            } else if (selectedOption == 1) {
              widget.setWallpaper(
                  widget.imageUrl, WallpaperManager.LOCK_SCREEN);
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
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}

// Separate StatefulWidget for the search bar
class SearchBarWidget extends StatefulWidget {
  final Function(String) onSearch;

  const SearchBarWidget({Key? key, required this.onSearch}) : super(key: key);

  @override
  _SearchBarWidgetState createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isSearchExpanded = !_isSearchExpanded;
            if (!_isSearchExpanded) {
              _searchController.clear();
              widget.onSearch(''); // Clear search query when collapsing
            }
          });
        },
        backgroundColor: Colors.white,
        elevation: 4,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: _isSearchExpanded
              ? MediaQuery.of(context).size.width - 96 // Adjust width as needed
              : 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
                _isSearchExpanded ? 24 : 24), // Adjust radius as needed
          ),
          child: Row(
            children: [
              Expanded(
                child: _isSearchExpanded
                    ? TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onSubmitted: (query) {
                          widget.onSearch(query);
                        },
                      )
                    : const SizedBox(), // Empty SizedBox when collapsed
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.search,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
