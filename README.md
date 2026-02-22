# PixelPaper

**PixelPaper** is a high-performance, minimalist Flutter application designed to bridge the gap between physical documents and digital management. It allows users to capture images, enhance them via a professional-grade editor, and compile them into organized PDF documents.

---

## Project Goals
The primary objective of this project is to provide a **private-first, offline-capable** document management tool.
* **Efficiency:** Rapid capture-to-PDF workflow with background saving.
* **Flexibility:** Choice between private internal storage or visible external storage.
* **Control:** Visual PDF editing, allowing users to reorder, delete, or add pages to existing documents.

---

## Key Features

### Smart Capture & Editing
* **Source Versatility:** Import documents from the camera or the existing photo gallery.
* **Pro Image Suite:** Integrated image editing (cropping, filtering, annotations) via `pro_image_editor`.
* **Optimized Performance:** Images are processed at 80% quality (1920px max) to balance visual clarity with file size efficiency.

### PDF Management
* **Instant Creation:** Batch select images to generate a PDF document immediately.
* **Visual PDF Editor:** A unique interface to open existing PDFs, view thumbnails of every page, reorder them via drag-and-drop, or append new scans.
* **PDF Actions:** Rename, Share via system sheets, Print, or Pin favorite documents to the top of the list.

### Customization & Privacy
* **Dual Storage Modes:** Switch between **Internal Storage** (app-private) and **External Storage** (visible in phone's file manager).
* **Personalized UI:** Dynamic Material 3 theming with multiple seed colors and a toggleable Dark Mode.
* **Localization:** Built-in support for English and Italian.

---

## Tech Stack

| Category | Packages Used |
| :--- | :--- |
| **State Management** | `provider` |
| **PDF Processing** | `pdf`, `syncfusion_flutter_pdf`, `printing` |
| **Storage** | `shared_preferences`, `path_provider` |
| **UI Components** | `flutter_expandable_fab`, `cupertino_icons` |
| **Utilities** | `image_picker`, `share_plus`, `package_info_plus` |

---

## Project Structure
```text
lib/
├── main.dart               # Entry point and app configuration
├── app_state.dart          # Global state management (Provider)
├── main_screen.dart        # Main dashboard with bottom navigation
├── gallery_screen.dart     # Captured images grid and selection logic
├── files_screen.dart       # PDF document listing and management
├── pdf_editor_screen.dart  # Visual PDF page reordering and editing
├── pdf_preview_screen.dart # Document viewer and sharing interface
└── settings_modal.dart     # UI configuration and localization settings

assets/
└── lang.json               # Localization strings (EN, IT)
```
