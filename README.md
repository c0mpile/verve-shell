# Verve Shell

<div align="center">

**An opinionated, high-performance Wayland shell built on Quickshell**

_Logic-First Backend • Visual-First Frontend • Minimal Diff Philosophy_

</div>

---

## Vision

This is a specialized fork of [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell), designed around the principle of **surgical modifications**: extending functionality with the absolute minimum number of lines changed. 

Rather than reimplementing core features, this fork preserves the upstream architecture while strategically enhancing user experience in targeted areas. All styling remains strictly bound to `Noctalia.Theme` variables to ensure consistency across modifications.

**Philosophy**: Extension over modification. Preservation over refactoring. Surgical precision over broad rewrites.

---

## Feature Matrix

### Upstream Noctalia Core

The foundation this fork builds upon:

- **Wayland-Native Support**: Niri, Hyprland, Sway, MangoWC, labwc
- **Modular Plugin System**: Extensible architecture for bars, panels, desktop widgets
- **Material You Theming**: Dynamic color generation via Matugen (rebranded as Noctalia theme)
- **Unified UI Scaling**: Consistent scaling across all components
- **Built-in Services**: Audio, Battery, Network, Location, Power Profile management
- **Quickshell Foundation**: High-performance QML-based rendering engine

### Surgical Enhancements (This Fork)

Targeted improvements with minimal upstream divergence:

#### Wallhaven Integration Improvements
_(Note: Base integration exists upstream; these are UX refinements)_

- **Responsive Window/Grid Resizing**: Wallpaper picker adapts to different screen sizes
- **Enhanced Preview Scaling**: Improved image preview rendering for better visual feedback
- **Flexible API Key Configuration**: 
  - Set via Settings UI
  - **OR** via environment variable: `env = NOCTALIA_WALLHAVEN_API_KEY,<your_key>` (Hyprland config)
- **Persistent Browsing State**: Browser remembers current page across sessions
- **Direct Page Navigation**: Type page number into input field, click next page button to jump directly
- **Improved Input Handling**: Enhanced query fallback logic and key event handling

#### Wallpaper Picker v2
_(New "Opinionated" Standard)_

- **Multi-Select Engine**: Utilizes a `selectedFiles` buffer for efficient batch management and cleaning.
- **Safety Interlocks**: System logic prevents the deletion of the currently active wallpaper on any monitor.
- **State-Aware UI**: Dynamic selection counter bound to `Noctalia.Theme` variables, shifting between accent and error states to communicate potential actions.

---

## Technical Architecture

### Quickshell Foundation

This shell leverages Quickshell's component architecture, with a strict reliance on **Quickshell IO** for all filesystem operations:

- **Quickshell IO**: Native filesystem handling for performance and reliability (avoiding shell outs where possible).
- **PanelWindow**: High-performance overlay windows for bars and panels
- **LazyLoader**: Deferred component initialization for faster startup
- **Variants System**: Conditional component loading based on compositor detection
- **Service Pattern**: Singleton services initialized in `shell.qml`

### Theming Philosophy

All visual customizations are bound to `Noctalia.Theme` variables. This ensures:

- **Rice Consistency**: Custom colors integrate seamlessly with Material You generation
- **Upstream Compatibility**: Theme updates from upstream don't break custom styling
- **Surgical Merges**: Color conflicts auto-resolve to preserve custom aesthetics

### Services Architecture

Services follow a strict initialization order in `shell.qml`:

```qml
WallpaperService.init();
WallpaperCacheService.init();
AppThemeService.init();
ColorSchemeService.init();
// ... additional services
```

This ensures dependency resolution and prevents race conditions during shell startup.

---

## Setup & Safety

> [!CAUTION]
> **Critical Pre-Deployment Warning**
> 
> A broken shell configuration can kill your entire GUI session. Before deploying this fork:
> 
> ```bash
> # Backup your existing Quickshell configuration
> cp -r ~/.config/quickshell ~/.config/quickshell.backup
> ```

### Requirements

- **Compositor**: Wayland compositor (Niri, Hyprland, Sway, MangoWC, or labwc recommended)
- **Runtime**: Quickshell
- **Dependencies**: See [Noctalia Official Docs](https://docs.noctalia.dev/) for full dependency list
- **Optional**: Wallhaven API key for extended wallpaper browsing

---

## Credits & Documentation

### Original Noctalia Team

This fork is built upon the exceptional work of:

- **Repository**: [noctalia-dev/noctalia-shell](https://github.com/noctalia-dev/noctalia-shell)
- **Lead Developers**: [Ly-sec](https://github.com/Ly-sec), [ItsLemmy](https://github.com/ItsLemmy)
- **Contributors**: [Full contributor graph](https://github.com/noctalia-dev/noctalia-shell/graphs/contributors)

### Documentation Resources

- **[Noctalia Official Documentation](https://docs.noctalia.dev/)**: Comprehensive setup, configuration, and plugin development guides
- **[Quickshell Documentation](https://quickshell.org/docs/)**: Core framework reference for QML components and bindings

---

## License

MIT License - see [LICENSE](./LICENSE) for details.

This fork maintains the same MIT license as the upstream project. Modifications are allowed under MIT terms, with proper attribution to the original Noctalia team required.
