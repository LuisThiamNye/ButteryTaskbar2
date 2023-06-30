# Buttery Taskbar 2

Save space on your screen by hiding the taskbar when it's not needed. This goes beyond the built-in auto-hide feature; it prevents the taskbar being shown by the mouse cursor. To reveal the taskbar, press the Windows key to open the Start menu.

This is the successor to the original [Buttery Taskbar](https://github.com/CrypticButter/ButteryTaskbar) where you will find further rationale for this program. Version 2 has lower CPU and memory usage, and should work more reliably overall.

## Features and behaviour

- The taskbar is shown under these conditions:
	- Holding down the Windows key.
	- The Start menu or other special windows like the tray overflow window, notification area, action centre, or task view are active.
- Enable or disable functionality with the shortcut: `Ctrl` + `Win` + `F11`
- Tray icon. Click it (left or right) to close the program.

## Installation

The program is provided as a single executable and no installer. [Download it here](https://github.com/LuisThiamNye/ButteryTaskbar2/releases/) and just run the program.

**Make sure to set the taskbar to auto-hide in Windows Settings** (otherwise you'll end up with a large unusable gap).

If you want it to run at log-in, create an entry in Task Scheduler to do that. There are plenty of instructions online for how to make a program run at log-in with Task Scheduler.

Important: In the properties window of the Task Scheduler entry you create for Buttery Taskbar:
- In the "General" tab, **check** "Run with highest privileges". This means Buttery Taskbar can work when you are using apps ran as administrator.
- In the "Conditions" tab, consider **uncheck**ing "Start the task only if the computer is on AC power" (for laptops).
- In the "Settings" tab, **uncheck** "Stop the task if it runs longer than".

## Further details

- The taskbar's visibility is updated each time you switch focus between windows (including opening the Start menu).
- There is intentionally a short delay after releasing the Windows key before the taskbar is allowed to hide again.