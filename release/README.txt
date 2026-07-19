HOW TO INSTALL THE UPDATE
========================

This update was downloaded from the internet, so your computer will not let you simply double-click the script for security reasons.

Choose the section below that matches your operating system.

-----------------------------------------------
MAC & LINUX  ->  use "flash_mac_linux.sh"
-----------------------------------------------
1. Open the "Terminal" app on your computer.
   - Mac: Press [Cmd + Space], type "Terminal", and press Enter.
   - Linux: Press [Ctrl + Alt + T].

2. Type the word bash followed by a single space:
   bash
   (IMPORTANT: Do NOT press Enter yet!)

3. Drag the "flash_mac_linux.sh" file from this folder and drop it directly into the Terminal window.
   - Your screen should look something like: bash /Users/name/Downloads/flash_mac_linux.sh

4. Now press Enter.

The script will handle the rest! It will automatically install openFPGALoader if needed, find the .fs file, and flash your Chromatic.

-----------------------------------------------
WINDOWS  ->  use "flash_windows.bat"
-----------------------------------------------
Prerequisites (only needed once):
   a. Download openFPGALoader for Windows from:
      https://github.com/trabucayre/openFPGALoader/releases
   b. Extract "openFPGALoader.exe" and place it in THIS folder
      (next to flash_windows.bat), or anywhere on your PATH.
   c. Replace the GWU2X driver with WinUSB using Zadig
      (https://zadig.akeo.ie/):
        - Options > List All Devices, select "GWU2X"
        - Target driver: WinUSB, then click "Replace Driver".

To run the updater:
1. Open File Explorer and navigate to this folder.
2. Double-click "flash_windows.bat".
   - If Windows blocks it, right-click the file and choose "Run" or
     "Run as administrator".
3. Follow the on-screen prompts.

-----------------------------------------------
NOTE FOR ALL PLATFORMS
-----------------------------------------------
Ensure your Chromatic is plugged in via USB and powered ON before flashing.
