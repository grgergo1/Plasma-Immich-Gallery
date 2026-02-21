# Immich Gallery

A KDE Plasma 6 desktop widget that displays photos from your [Immich](https://immich.app) photo server.

## Features

- **Slideshow mode** — crossfade transitions, configurable interval, hover navigation buttons
- **Daily photo mode** — one photo per calendar day, resets at midnight
- Photo sources: recent, favorites, random, albums, or by person
- Multi-select albums and people
- Shuffle, border, and opacity controls

## Requirements

- KDE Plasma 6
- A running [Immich](https://immich.app) instance with an API key

## Installation

```bash
# Clone the repository
git clone https://github.com/NotDonnovan/Plasma-Immich-Gallery.git

# Install
cd Plasma-Immich-Gallery/
kpackagetool6 --install ./ --type Plasma/Applet
```

## Configuration

Open the widget settings and provide:

- **Server URL** — e.g. `https://immich.example.com`
- **API Key** — generate one in Immich under Account Settings → API Keys

Then choose your view mode, photo source, and display preferences.
