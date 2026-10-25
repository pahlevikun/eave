Platform identity exports

  web/     favicon.ico, favicon-*.png, site.webmanifest, head-snippet.html
  android/ chrome PNGs, mipmap-*, play-store-icon.png, adaptive-icon.xml
  ios/     AppIcon.appiconset/, apple-touch-icon.png
  platform-shape-preview.html

The web manifest and head snippet use the sibling web/ios/android layout.
When copying selected files to an application, update relative paths for that deployment.
These are brand handoff files; they do not imply mobile application support.
