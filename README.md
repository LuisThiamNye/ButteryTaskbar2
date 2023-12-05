# Buttery Taskbar 2

<p align="center">
<img width="540" src="https://github.com/LuisThiamNye/miscellaneous-media/blob/8714fceb0cc01309fd2402f4887c2ee7e106656c/buttery-taskbar-feature-image.png">
</p>

Save space on your screen by hiding the taskbar when it's not needed. This goes beyond the built-in auto-hide feature; it prevents the taskbar being shown by the mouse cursor. To reveal the taskbar, press the Windows key to open the Start menu.

**New:** Don't want to use the keyboard? Now you can scroll with the mouse at the bottom of the screen to show the Start menu as well!

This is the successor to the original [Buttery Taskbar](https://github.com/CrypticButter/ButteryTaskbar) where you will find further rationale for this program. Version 2 has lower CPU and memory usage, and should work more reliably overall.

<img width="260"
     align="right"
     src="https://github.com/LuisThiamNye/miscellaneous-media/blob/f1283d276b8d6d0a9899d2a7c9c3baca74ca3c8b/buttery-taskbar-screenshot-2.3.0.png">

## Features and behaviour

- The taskbar is shown under these conditions:
	- Holding down the Windows key.
	- The Start menu or other special windows like the tray overflow window, notification area, action centre, or task view are active.
- Scroll at the bottom edge of the primary monitor to open the Start menu (optional).
- Tray icon for accessing the settings menu, which also shows available software updates.
- Enable or disable functionality with the shortcut: `Ctrl` + `Win` + `F11` (optional, disabled by default).
- Option to automatically enable/disable Windows taskbar auto-hide when disabling Buttery Taskbar.

## Installation

The program is provided as a single executable and no installer. [Download it here](https://github.com/LuisThiamNye/ButteryTaskbar2/releases/) and just run the program.

If you want it to run at log-in, I recommend creating an entry in Task Scheduler. There are plenty of instructions online for how to make a program run at log-in with Task Scheduler.

Important: In the properties window of the Task Scheduler entry you create for Buttery Taskbar:
- In the "General" tab, **check** "Run with highest privileges". This means Buttery Taskbar can work when you are using apps ran as administrator.
- In the "Conditions" tab, consider **uncheck**ing "Start the task only if the computer is on AC power" (for laptops).
- In the "Settings" tab, **uncheck** "Stop the task if it runs longer than".

You might notice that in Buttery Taskbar's tray menu, there is a "start at log-in" option. Keep this turned off if you followed the above steps. Unlike the Task Scheduler method, this option will not start Buttery Taskbar as administrator, and hence Buttery Taskbar will not work properly when the current focused window is running as administrator.

## Further details

- The taskbar's visibility is updated each time you switch focus between windows (including opening the Start menu).
- There is intentionally a short delay after releasing the Windows key before the taskbar is allowed to hide again.

## Donations

Bitcoin: `bc1qhgfyn3f2c56xwmsalekfntkxjgj6t73dt4ymjj`

Ethereum: `0x8AABE26364304267537da5fa956081a6925D2e40`

Cardano: `addr1q85zwgetxpru4g6fyvsz4h292mwaru2we22u8xckwv8yqrmgrzy93wur7z4zzmhj8eyr3dw5dyj97crvvxafdxjddags6xgeef`
