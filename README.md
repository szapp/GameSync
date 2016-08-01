GameSync
========

This tool enables synchronizing files and directories with dropbox that don't lie inside the dropbox path. While this is
very much possible by creating symbolic links, this can get confusing, cause de-sync and windows offers no easy way of
creating symbolic links.

This tool was written with old games in mind, that don't run on a cloud-syncing platform (like
[Steam](http://steampowered.com)) that secures all game saves online. With **GameSync** game saves of old games can be
backed up and/or made accessible from multiple computers connected to the same dropbox account. Especially as old games
become less stable on modern machines, having backups of game saves will come in handy.

Nevertheless, this tool is not limited to using with game saves only - in fact only the name of the tool suggests that.
Anything outside the dropbox path may be synchronized.

![](http://i.imgur.com/rduZluJ.png)

Installation
------------

1. [Download](bin/build) or [build](#building) **GameSync**
2. Create a designated directory in your dropbox (e.g. ``C:\User\Dropbox\GameSync\``).
3. Create a shortcut of the GameSync.exe on your desktop and point the working directory of the shortcut to the directory created above.
4. Store the [sync.ini](sync.ini) to the said directory in your dropbox and adjust it in [this manner](#syncini).

Creating a shortcut pointing the working directory to the dropbox directory tells **GameSync** where to look for the
[sync.ini](sync.ini) and where to synchronize the items to. Since the [sync.ini](sync.ini) is inside the dropbox itself,
there is no need to configure and maintain a separate [sync.ini](sync.ini) for each computer.

Once it is fully set up, the recommended use is to first start dropbox. Once dropbox is fully synchronized and still
running in the background, start **GameSync**. **GameSync** will synchronize between all [selected](#syncini) items and
show the changes, as well as write all events to a log file (sync.log) in the same dropbox directory. **GameSync**
should be run before and after playing a game/altering files (while dropbox is running in the background).

Sync.ini
--------

### Item list

The first part of [sync.ini](sync.ini) is a list of **all** items (named by their dropbox directory) that should be
synchronized. If, for example, using **GameSync** to secure the game saves of three different games (Call of Duty 4,
Company of Heroes and all UPlay games), create directories for each of them in your designated dropbox directory from
above and enter their names like the following.

**Note:** The item number (in front of each equal sign) needs to steadily increase, otherwise the items will not be
recognized.

```ini
; All items (by dropbox folder)
[main]
item1=CoD4
item2=CoH
item3=UPlay
```

### Default paths

The second part holds the default paths to the respective **local** game directories. This is only necessary or
recommended for games that share the same paths across different computers. For all other items, the default path can be
omitted. Nevertheless, the default paths may be overwritten for different computers.
In this example, the game saves of Call of Duty 4 don't lie in the same path for all computers. So no default path is
set.

```ini
; Default locations (optional)
[.default]
CoH=%Userprofile%\Documents\My Games\Company of Heroes\Savegames\
Uplay=C:\Program Files (x86)\Uplay\savegames\f0842177-04a1-b821-59cc-facb1513ca21\
```

### Computer-specific paths

The last part stores computer-specific paths for the items by
[computer name](https://support.vitalsource.com/hc/en-us/articles/201965227-How-to-locate-your-machine-name).

In this example:

While all games are on the desktop computer (PC-DESKTOP), the laptop (PC-LAPTOP) does not have Company
of Heroes installed. Omitting it in the list will not sync it and ignore that item for this computer.

Although, there is a default path for the UPlay game saves, it differs on PC-DESKTOP and is overwritten for that
computer, while PC-LAPTOP uses the default path by specifying ``default``.

```ini
; Computer specific
; File/Folder for each item (if item not present, omit)
; Specify 'default' for default location (see above)

[PC-DESKTOP]
CoD4=D:\Games\Call of Duty 4 - Modern Warfare\players\|*.cfg ; Ignore all *.cfg files
CoH=default
Uplay=D:\Programs\Ubisoft\Ubisoft Game Launcher\savegames\f0842177-04a1-b821-59cc-facb1513ca21\

[PC-LAPTOP]
CoD4=C:\Games\Call of Duty 4 - Modern Warfare\players\|*.cfg ; Ignore all *.cfg files
Uplay=default
; CoH is not required on this machine (so ignore it)
```

To only sync individual files, don't specify a directory but the complete path to the file to sync.

To omit certain files in a game save directory, end the directory path with a pipe and the file pattern to ignore,
see CoD4 in the above example.

Building
--------

This is *not* a dropbox plug-in. **GameSync** runs independently of dropbox. No files in the dropbox installation will
be modified, no binary files of dropbox are altered or included in this software.

To build **GameSync** from source the latest Version of [AutoHotkey](http://autohotkey.com) is recommended. After
compiling, the icons need to be added to the executable. For that
[resource hacker](http://www.angusj.com/resourcehacker/) is recommended. Take the existing executable in the
[build directory](bin/build/) as reference.
