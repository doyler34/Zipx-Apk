<a id="readme-top"></a>


<br></br></br>

<p align="center">
  Zipx Movies
</p>

</br></br>

## Description

Zipx Movies is a Flutter application designed to provide users with a seamless experience for searching and browsing movies. Leveraging the power of the TMDB API, the app allows users to discover new releases, search for their favorite films, and bookmark movies locally without requiring account creation. The application is built using the BLoC pattern for state management and CLEAN architecture to ensure a maintainable and scalable codebase.

Key features include:
*   **Movie Discovery:** Browse popular, top-rated, and upcoming movies.
*   **Search Functionality:** Quickly find movies by title.
*   **Local Bookmarking:** Save your favorite movies locally for easy access.
*   **Clean Architecture:** Well-structured codebase for easy understanding and contribution.
*   **BLoC Pattern:** Robust state management for a smooth user experience.

The application is designed to be simple and intuitive, allowing users to quickly find the movies they're looking for. While multi-language support is not fully implemented, the groundwork has been laid, and contributions are welcome to complete this feature.

<br>
<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Installation

Follow these steps to get Zipx Movies up and running on your local machine:

### 1. Clone the Repository

Clone the Zipx Movies repository to your local machine using Git:


flutter pub get
> **Important:** Before running the app, you need to set up your TMDB API key. You can obtain an API key from [TMDB](https://www.themoviedb.org/settings/api). Once you have the key, open the app, go to the settings page, and enter your TMDB API key. Without the API key, the app will not be able to load any movie data.

### 2. Run the App

Run the Zipx Movies application on your preferred device or emulator:

*   **API Key Issues:** Ensure you have correctly entered your TMDB API key in the settings page. Double-check for any typos.
*   **Dependency Conflicts:** If you encounter any dependency conflicts, try running `flutter pub upgrade` to update the packages to their latest compatible versions.
*   **Build Errors:** If you face any build errors, try cleaning the project using `flutter clean` and then running `flutter pub get` again.

<br>
<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Usage

Zipx Movies is designed to be intuitive and easy to use. Here's a quick guide to the main features:

*   **Home Screen:** Displays a list of popular, top-rated, and upcoming movies. Scroll through the lists to discover new movies.
*   **Search:** Tap the search icon in the navigation bar to search for movies by title. Enter your search query and press Enter to view the results.
*   **Movie Details:** Tap on a movie to view its details, including the title, overview, rating, and cast.
*   **Bookmarks:** To bookmark a movie, tap the bookmark icon on the movie details page. To view your bookmarked movies, navigate to the bookmarks screen using the navigation bar.
*   **Settings:** Access the settings screen to enter your TMDB API key and customize the app's theme.

<br>
<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Packages

Here's a brief overview of the packages used in Zipx Movies:

*   **adaptive_theme:** Provides adaptive theme support (light/dark mode).
*   **animate_do:**  Offers various animation effects.
*   **auto_size_text:** Automatically resizes text to fit within its bounds.
*   **blur:** Implements blur effects for UI elements.
*   **carousel_slider:** Creates a carousel slider for displaying images and other content.
*   **cupertino_icons:** Provides access to the standard set of  Cupertino (iOS) icons.
*   **custom_refresh_indicator:**  Allows for custom refresh indicator designs.
*   **dio:** A powerful HTTP client for making API requests.
*   **equatable:** Simplifies value equality in Dart.
*   **extended_image:**  An enhanced image widget with caching and error handling.
*   **flex_color_scheme:**  Provides a wide range of pre-made color schemes.
*   **flutter_bloc:**  Helps implement the BLoC pattern for state management.
*   **flutter_native_splash:**  Creates a native splash screen for the app.
*   **font_awesome_flutter:**  Provides Font Awesome icons.
*   **get_it:**  A service locator for dependency injection.
*   **google_fonts:**  Provides access to Google Fonts.
*   **go_router:**  A declarative routing package for Flutter.
*   **hive_flutter:**  A lightweight NoSQL database for Flutter.
*   **internet_connection_checker:** Checks for internet connectivity.
*   **loading_animation_widget:** Offers a variety of loading animations.
*   **readmore:**  A widget that allows you to collapse and expand long text.
*   **youtube_player_iframe:**  A YouTube player widget for Flutter, built on webview_flutter.
*   **build_runner:**  A tool for generating code.
*   **device_preview:**  Allows you to preview your app on different devices.
*   **flutter_launcher_icons:**  Generates launcher icons for different platforms.
*   **hive_generator:**  Generates Hive adapters for custom classes.

<br>
<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Contributing

Contributions are welcome! If you'd like to contribute to Zipx Movies, please follow these guidelines:

1.  **Reporting Bugs:** If you find a bug, please create a new issue on the [GitHub repository](https://github.com/doyler34/zipx-apk/issues). Be sure to include detailed steps to reproduce the bug.
2.  **Suggesting Enhancements:** If you have an idea for a new feature or enhancement, please create a new issue on the [GitHub repository](https://github.com/doyler34/zipx-apk/issues).
3.  **Submitting Pull Requests:** If you'd like to submit a pull request, please follow these steps:
    *   Fork the repository.
    *   Create a new branch for your changes.
    *   Make your changes and commit them with descriptive commit messages.
    *   Submit a pull request to the main branch.

<br>
<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Credits

*   Powered by the [TMDB API](https://www.themoviedb.org/documentation/api).

<br>
<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Support

If you have any questions or need help, please contact me. You can also report issues on the [GitHub repository](https://github.com/doyler34/zipx-apk/issues).

<br>
<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Future Enhancements

One of the key features that is not fully implemented is multi-language support. The groundwork for this feature has been laid, but it requires further contributions to complete. If you're interested in contributing to this feature, please feel free to submit a pull 

<br>
<p align="right">(<a href="#readme-top">back to top</a>)</p>
