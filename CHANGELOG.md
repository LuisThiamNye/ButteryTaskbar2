
## 2.2.0 Peak User Experience Edition
23 July 2021

- Added a friendly icon.
- New feature: a graphical user interface for configuring the program. Access it via the tray icon.
	- Four options:
		- Enable/disable the entire taskbar-hiding functionality.
		- Enable/disable the shortcut to toggle the above option.
		- Control whether scrolling the screen edge reveals the taskbar.
		- Auto-start at login, with a caveat:
			- If you use this option, the program will not run as administrator and hence will not function properly when the focused window is running as administrator. But perhaps this is a nice convenience for people who do not want to bother taking my continued advice of creating an entry in Task Scheduler (see the README).
	- These four settings are automatically saved to a binary config file in AppData/Roaming.
	- The program checks GitHub for newer versions, and when it is out of date, the menu shows an update button that opens the releases page in your browser.