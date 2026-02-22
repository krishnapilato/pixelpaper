import 'package:flutter/material.dart';
import 'app_state.dart';

void showSettingsModal(BuildContext context, AppState app) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true, // Required for custom heights > 50%
    backgroundColor:
        Colors.transparent, // Keeps the top corners perfectly rounded
    builder: (context) {
      // Set to 94% of screen height
      final screenHeight = MediaQuery.of(context).size.height;

      return Container(
        height: screenHeight * 0.94,
        padding: const EdgeInsets.only(
          top: 15,
          left: 20,
          right: 20,
          bottom: 20,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            // 1. MODERN DRAG HANDLE
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),

            // 2. HEADER
            Text(
              app.t('settings'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            const Divider(),

            // 3. MAIN CONTENT (Expanded takes up all middle space)
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  const SizedBox(height: 10),

                  // Language Selection
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.language, size: 28),
                    title: const Text(
                      'Language',
                      style: TextStyle(fontSize: 16),
                    ),
                    trailing: DropdownButton<String>(
                      value: app.language,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'it', child: Text('Italiano')),
                      ],
                      onChanged: (v) => app.updateSettings(lang: v),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Dark Mode Toggle
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.dark_mode, size: 28),
                    title: Text(
                      app.t('dark_mode'),
                      style: const TextStyle(fontSize: 16),
                    ),
                    trailing: Switch(
                      value: app.themeMode == ThemeMode.dark,
                      onChanged: (isDark) => app.updateSettings(
                        theme: isDark ? ThemeMode.dark : ThemeMode.light,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Storage Location Toggle
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_special, size: 28),
                    title: Text(
                      app.t('save_loc'),
                      style: const TextStyle(fontSize: 16),
                    ),
                    subtitle: Text(
                      app.useExternalStorage
                          ? app.t('ext_store')
                          : app.t('int_store'),
                    ),
                    trailing: Switch(
                      value: app.useExternalStorage,
                      onChanged: (v) => app.toggleStorageDirectory(),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // THEME COLORS SECTION
                  Text(
                    app.t('theme_color'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 15),

                  SizedBox(
                    height: 60,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children:
                          [
                                Colors.deepPurple,
                                Colors.blue,
                                Colors.green,
                                Colors.orange,
                                Colors.red,
                                Colors.teal,
                                Colors.pink,
                                Colors.indigo,
                                Colors.brown,
                                Colors.cyan,
                              ]
                              .map(
                                (c) => Padding(
                                  padding: const EdgeInsets.only(right: 15),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(30),
                                    onTap: () => app.updateSettings(color: c),
                                    child: CircleAvatar(
                                      backgroundColor: c,
                                      radius: 25,
                                      child: app.seedColor.value == c.value
                                          ? const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 24,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ],
              ),
            ),

            // 4. LICENSES BUTTON (Pushed to bottom above footer)
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.policy_outlined),
              title: Text(
                app.t('licenses'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                showLicensePage(
                  context: context,
                  applicationName: 'PixelPaper',
                  applicationVersion: '0.9.0',
                  applicationLegalese: '© 2026 Khova Krishna Pilato',
                );
              },
            ),

            // 5. FOOTER
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${app.t('author')}: Khova Krishna Pilato",
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                Text(
                  "${app.t('version')}: 0.4.2",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            // Extra padding for bottom navigation bars on newer phones
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      );
    },
  );
}
