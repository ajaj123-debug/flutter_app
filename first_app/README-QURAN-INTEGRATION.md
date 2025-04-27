# Quran Integration Guide

This document provides information about the integration of the Quran feature in the app.

## Overview

The Quran feature allows users to browse and read all 114 surahs of the Quran. It uses a SQLite database (`quran.sqlite`) that contains all the surahs with their Arabic text and metadata.

## Database Structure

The `quran.sqlite` database has a table with the following columns:

1. `id` - Surah number (1 to 114)
2. `name_ar` - Surah name in Arabic
3. `name_pron_en` - Surah name in English
4. `class` - Whether the surah is Makki or Madani
5. `verses_number` - Number of verses in the surah
6. `content` - The full text of the surah

## Implementation Details

### Database Access

- The database file is stored in the `assets` folder and copied to the device's storage on first run
- `QuranDatabaseService` handles the database operations using the `sqflite` package
- The service implements a singleton pattern to ensure only one instance exists

### Performance Considerations

- Lazy loading is implemented by only loading the full surah text when a user opens a specific surah
- The main list of surahs only loads metadata, not the full text content
- The SQLite database itself provides efficient querying capabilities

### UI Components

- `QuranScreen` - Main screen showing the list of all surahs
- `SurahDetailScreen` - Screen showing the full text of a selected surah
- `SurahTile` - Widget representing a single surah in the list

## Required Dependencies

The following dependencies are used:

- `sqflite` - For SQLite database operations
- `path` - For file path operations

## Fonts

The app uses existing Arabic fonts from the app to display the Quran text:

- `ScheherazadeNew` - Used for displaying Arabic text

## Usage

To access the Quran feature, the user can tap on the "Al-Quran" tile in the home screen's feature grid.

## Future Improvements

Potential improvements for the Quran feature:

1. Add search functionality to search for specific text within the Quran
2. Add bookmarks to save favorite verses
3. Implement audio recitation
4. Add translations in different languages
5. Add tafsir (interpretation) functionality
6. Add verse-by-verse navigation

## Troubleshooting

If you encounter issues with the Quran feature:

1. Ensure the `quran.sqlite` file is correctly placed in the assets folder
2. Check that the `pubspec.yaml` correctly references the database file
3. Verify that required dependencies (`sqflite`, `path`) are added to the project
4. Check for any error messages in the console logs 