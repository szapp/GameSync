/**
 * Author: szapp
 * Version: 1.0
 */
selfname := Substr(A_ScriptName, 1, InStr(A_ScriptName, ".", false, 0)-1) ; Name of the program (stripped of file extension)
config := "sync.ini" ; Configuration file (in working directory!)
log := "sync.log" ; Log file (in working directory!)
#SingleInstance, ignore ; Only one instance of this program is allowed (new ones replace the old one)
#NoTrayIcon ; No icon in tray
#NoEnv ; Environment variables are ignored
; SetWorkingDir, %A_ScriptDir%  ; Disabled to have the exe work on different working directories

; Run as administrator (enable operations in Programm Files)
if not A_IsAdmin
{ ; If not launched with administrator rights
	params := "/restart " ; No parameters need to be passed
	Run *RunAs %A_ScriptFullPath% %params%, %A_WorkingDir%, UseErrorLevel ; Call itself (with administrator privileges) and exit current instance
	Sleep, 2000 ; If the current instance is not replaced after two seconds, it probably failed
	MsgBox, 16, Initialization failed, The program could not be started. Please restart the application with administrative rights!
	ExitApp ; Exit current instance
}

; Check for config file
IfNotExist, %config%
{ ; If file not found
	MsgBox, 16, %selfname%, Error: %config% not found.
	GoSub, ExA ; Throw error and exit
}

; Check whether local machine is configured
IniRead, cmpexist, %config%, %A_ComputerName% ; Attempt to read section of the computer in config file
if !cmpexist
{ ; No results = There is no section (or entries) for this computer
	MsgBox, 16, %selfname%, Error: There is no configuration for this machine.
	GoSub, ExA ; Throw error and exit
}
cmpexist := "" ; Free up variable

; Retrieve names of all items
allitms := [] ; Create empty list for items
Loop { ; Iterate through 'main' section of config
	IniRead, itmexist, %config%, main, item%A_Index%, 0 ; Attempt to read next item
	if !itmexist
		break ; If this item does not exist, the list is compete, exit loop
	allitms.Insert(itmexist) ; Otherwise add value of item
}
itmexist := "" ; Free up variable

; Cross-reference all items with local machine config
syncitms := {} ; Create empty associative array
syncamount = 0 ; Amount of files in the array starts at zero
Loop, % allitms.maxIndex()
{ ; Iterate through the list of identified items (from 'main' section of config file)
	IniRead, itmexist, %config%, %A_ComputerName%, % allitms[A_Index], 0 ; Attempt to read path for current item
	if !itmexist
		continue ; Item not found = this item is not synchronized with this computer = igonre and continue
	syncitms[allitms[A_Index]] := itmexist ; Otherwise add name of item and its path to the list
	syncamout++ ; The list has grown by one
}
allitms := "" ; Free up variable

; Gui
SysGet, Coords, MonitorWorkArea ; Get screen dimensions
resx := CoordsRight-284 ; Determine x and y coordinates for GUI
resy := CoordsBottom-54
resy_thn := CoordsBottom-195 ; larger size
Gui, Font, s8, Tahoma ; Set Font for GUI
Gui, Color, white ; Set GUI background color
Gui, Add, ListView, x5 y5 h140 w250 -Hdr -HScroll +VScroll +0x2000 Hidden +0x4 Backgroundf1f5fb vlistv, Event ; ListView (will display the latest 8 events), no scrollbars
Gui, Add, ListView, x5 y5 h140 w250 -Hdr -HScroll +VScroll +0x4 Hidden Backgroundf1f5fb vlistvFULL, Event ; There is a hidden Control for reviewing the ALL events later
ImageListID := IL_Create(4)  ; Create an ImageList to hold 4 small icons
Gui, ListView, listv ; Focus on the visible ListView
LV_SetImageList(ImageListID)  ; Assign the above ImageList to the current ListView
Gui, ListView, listvFULL ; Both controls are exactly alike (besides one being hidden until needed)
LV_SetImageList(ImageListID)  ; Assign the above ImageList to the current ListView
Loop 4  ; Load the ImageList with a series of icons
    IL_Add(ImageListID, A_ScriptFullPath, A_Index+1)
Gui, Add, Text, x5 y5 w240 vitmdisp ; Create text field for displaying current file/event messages
Gui, Add, Progress, x5 y19 w250 h10 -Smooth Range0-%syncamout% vprgr, 0 ; Progressbar
Gui, +0x40000 -Border +MinSize +MaxSize +Disabled +ToolWindow +AlwaysOnTop ; GUI options (style)
Gui, Show, x%resx% y%resy% w260 h34, %selfname% ; Show GUI, set GUI coordinates

; Enumerate through items from item list
For item, local in syncitms ; For each item and its local path
{	; Retrieve list of files for each item
	if (local = "default")
	{ ; The path is the default path = retrieve path from default section in config
		IniRead, local, %config%, .default, %item%, 0 ; Attempt to read path for current item
		if !local
			continue ; Item not found = this item is not synchronized with this computer = igonre and continue
	}
	while InStr(local, "%")
	{ ; Replace environment variables
		envvar := SubStr(local, InStr(local, "%"), InStr(local, "%", false, 1, 2)+1-InStr(local, "%"))
		EnvGet, envval, % Trim(envvar, "`%") ; Get environment variable
		StringReplace, local, local, %envvar%, %envval%, All ; Replace all occurances of the string with the contents of the environment variable
	}
	files := getInvolvedFiles(A_WorkingDir "\" item "\" SubStr(local, (InStr(local, "|") ? InStr(local, "|") : InStr(local, "\", false, 0)+1)), local) ; Call function to get files (local and in repository)
	; Synchronize files (bi-directional)
	local := SubStr(local, 1, (InStr(local, "|") ? InStr(local, "|")-1 : StrLen(local))) ; Get rid of exclusion parameters (everything beyond '|'). Left with path.
	if (SubStr(local, StrLen(local)) != "\") ; If the path leads to a file,
		local := SubStr(local, 1, InStr(local, "\", false, 0)) ; Cut of file, to obtain path only
	local := Trim(local,"\") ; Strip the last slash
	; Loop, % files.maxIndex()
	For file in files ; For each item and its local path
	{ ; Iterate through all listed files
		GuiControl, , itmdisp, % SubStr(file, 1, 40) ((StrLen(file) > 40) ? "..." : "") ; Display current file in GUI text field
		loc := local "\" file ; Corresponding local file
		pat := A_WorkingDir "\" item "\" file ; Corresponding repository file
		if (SubStr(file,StrLen(file)) = "\")
		{ ; If the current file is a folder
			IfnotExist, %loc%
			{ ; Create it locally if not existant
				FileCreateDir, %loc%
				updateLog(item, file, 1, 1, ErrorLevel) ; Update event log an ListView in GUI (left, dir, [error])
			}
			IfnotExist, %pat%
			{ ; Create if in repository if not existant
				FileCreateDir, %pat%
				updateLog(item, file, 2, 1, ErrorLevel) ; Update event log an ListView in GUI (right, dir, [error])
			}
			continue ; Continue with next file in list
		} ; Otherwise, file is not a folder
		IfNotExist, %loc% ; Check whether file exists locally
			loc_t = 0 ; If it does not exist set last time of modification to zero
		else ; If it does exist get last time of modification
			FileGetTime, loc_t, %loc%
		IfNotExist, %pat% ; Check whether file exists in repository
			pat_t = 0 ; If it does not exist set last time of modification to zero
		else ; If it does exist get last time of modification
			FileGetTime, pat_t, %pat%
		if (loc_t = pat_t)
			continue ; If both files are up to date (or both are not existant), continue with next file in list
		FileSetAttrib, -R, %loc% ; Otherwise, remove ReadOnly flag from files
		FileSetAttrib, -R, %pat%
		if (loc_t > pat_t)
		{ ; If local file is newer
			FileCreateDir, % SubStr(pat, 1, InStr(pat, "\", false, 0)) ; For saftety reasons attempt to create directory at end of path (might already exist)
			FileCopy, %loc%, %pat%, 1 ; Copy (and overwrite) file to repository
			updateLog(item, file, 2, 0, ErrorLevel) ; right, no dir ,error
		}
		else
		{ ; If file in repository is newer
			FileCreateDir, % SubStr(loc, 1, InStr(loc, "\", false, 0)) ; For satety reasons attempt to create directory at end of path (might already exist)
			FileCopy, %pat%, %loc%, 1 ; Copy (and overwrite) local file
			updateLog(item, file, 1, 0, ErrorLevel) ; left, no dir ,error
		}
	}
	GuiControl, , prgr, %A_Index% ; Advance progress bar
}
done = 1 ; Procedure is done
if errmsg
{ ; If an error occured, let the user examine log
	GuiControl, +Cred, itmdisp ; Turn GUI text field red and display message
	GuiControl, , itmdisp, An error occured during synchronization!
	GuiControl, Hide, listv ; Hide visible ListView
	Gui, ListView, listvFULL ; To enable the full instance (with all events, not only the latest 8)
	LV_Modify(LV_GetCount(), "Vis") ; Scroll to the bottom
	LV_ModifyCol(1, 225) ; adjust column width, to prevent the horizontal scrollbar from appearing
	GuiControl, -HScroll, listvFULL ; For safety, remove horizontal scrollbar (does not have permanent effect)
	GuiControl, Show, listvFULL ; Show prepared full instance of ListView
	Gui, -Disabled ; Enable GUI, for the user to examine the event log
	GuiControl, Focus, listvFULL ; Focus keyboard\mouse controls on ListView (to enable scrolling right away)
	return ; Wait for the user to press escape
}
else
{
	if !LV_GetCount() ; If the log is empty
	{ ; No change (all files are up to date)
		GuiControl, , itmdisp, Up to date ; Display message in GUI text field
		Sleep, 1000 ; Wait one second
		GoSub, GuiEscape ; Exit programm
	} ; Otherwise (there was change)
	wait = 2 ; Specify waiting period of two seconds
	Loop { ; Enable the user to examine results, when holding shift
		GuiControl, , itmdisp, Synchronization done. %A_Space% Hold %A_Space%[Shift] to examine. ; Display message in GUI text field
		KeyWait, LShift, D T%wait% ; Wait the waiting period for the user to press down (and hold) shift
		if ErrorLevel ; If shift was not pressed in time,
			GoSub, GuiEscape ; Exit programm
		GuiControl, , itmdisp, Synchronization done. %A_Space%Relase [Shift] to exit. ; Display message in GUI text field
		GuiControl, Hide, listv ; Hide visible ListView
		Gui, ListView, listvFULL ; To enable the full instance (with all events, not only the latest eight)
		LV_Modify(LV_GetCount(), "Vis") ; Scroll to the bottom
		LV_ModifyCol(1, 225) ; adjust column width, to prevent the horizontal scrollbar from appearing
		GuiControl, -HScroll, listvFULL ; For safety, remove horizontal scrollbar (does not have permanent effect)
		GuiControl, Show, listvFULL ; Show prepared full instance of ListView
		Gui, -Disabled ; Enable GUI, for the user to examine the event log
		GuiControl, Focus, listvFULL ; Focus keyboard\mouse controls on ListView (to enable scrolling right away)
		KeyWait, LShift ; Wait for the user to release shift (as long as shift is held, the user can examine the events in ListView, i.e. scroll through the log)
		GuiControl, Hide, listvFULL ; If shift is released hide full list
		GuiControl, Show, listv ; And show only latest eight events (prevents from having a vertical scrollbar)
		Gui, +Disabled ; Disable the GUI again
		wait = 1 ; Specify a waiting period of only one second from here on out
	} ; Let the user press and release shift (examine the list) as often as they want
}

; Exit procdures
GuiEscape: ; Gui is closed
GuiClose:
if !done ; Only granted if synchronization is complete
	return
ExA: ; Just an extra label to exit without 'done'-restriction
; no extra clean up necesarry
ExitApp

Esc:: ; Escape button is pressed, but window not in focus
GoSub, GuiEscape ; Same effect as 'GuiEscape'

; Functions
getInvolvedFiles(item, local) { ; Concatination function for addFiles
	return addFiles(item, addFiles(local)) ; Retrieve file list from local files, add files from repository and return the full list
}
addFiles(path, concat=0) { ; Find all files
	if !concat ; Specify empty array if there is none so far (none passed to the function)
		concat := {}
	StringReplace, path, path, /, \, All ; Correct path slashes
	exclude := SubStr(path, (InStr(path, "|") ? InStr(path, "|") : StrLen(path)+1)) ; Extensions to exclude are retrieved from the path with '|', e.g. C:\Item\|*.cfg|*.ini
	if exclude
	{ ; If there is something to exclude
		exclude .= "|" ; Add '|' at the end to make sure every element is enclosed by '|'
		path := SubStr(path, 1, InStr(path, "|")-1) ; Strip the path from the exclusion parameters
	}
	IfNotExist, %path% ; If the file does not exist,
		return concat ; It is not added to the file list
	if (SubStr(path, StrLen(path)) = "\")
	{ ; Ig the path is a folder (ends with "\")
		relativecutoff := StrLen(path)+1 ; For cutting off absolute path (only relative path remains)
		Loop, %path%*.*, 1, 1
		{ ; Iterate through all files (find files)
			if (!InStr(A_LoopFileAttrib,"D")
			&&   A_LoopFileExt
			&&   InStr(exclude, "|*." A_LoopFileExt "|", false)) ; Skip unwanted files (excluded extensions '|')
				continue
			if InStr(exclude, "|" A_LoopFileName "|", false) ; Skip unwanted files (files without path '|')
				continue
			relpath := SubStr(A_LoopFileLongPath, relativecutoff) . (InStr(A_LoopFileAttrib,"D") ? "\" : "") ; Cutting of absolute path (relative path remains)
			if InStr(exclude, "|" relpath "|", false) ; Skip unwanted files/folders (files/folders with path '|')
				continue
			concat[relpath] := "item" ; Add the file
		}
		return concat ; End here and return file list
	}
	; Else: Path is one file
	relpath := SubStr(path,InStr(path,"\",false,0)+1) ; Cutting of absolute path (relative path remains)
	concat[relpath] := "item" ; Add the file
	return concat ; End here and return file list
}
updateLog(itm, this, lr, dir=0, err=0) { ; Updates the event messages (in log and on screen)
	global
	if err ; Specify that an error occured (important for later)
		errmsg = 1
	FormatTime, datetime, A_Now, yy-MM-dd HH:mm:ss ; Current time
	ms := datetime " " (lr-1 ? (err ? "=/>" : "==>") : (err ? "</=" : "<==")) " [" itm "] " (err ? "ERROR: Could not " (dir ? "create directory" : "synchronize") : (dir ? "Created directory" : "Synchronized")) " '" this "' " (lr-1 ? "in repository." : "locally.") "`n"
	if !LV_GetCount() ; If this is the first event, write headline/separator to log file, and enlarge GUI
	{
		FileAppend, %datetime% ---- %A_ComputerName% --------------------------------------------------------------`n, %log%
		GuiControl, Show, listv
		GuiControl, Move, itmdisp, y146
		GuiControl, Move, prgr, y160
		Gui, -MinSize -MaxSize
		Gui, Show, h175 y%resy_thn%
		Gui, +MinSize +MaxSize
	}
	FileAppend, %ms%, %log% ; Add event to log file
	Gui, ListView, listv ; Switch to visible control
	if (LV_GetCount() >= 8)
		LV_Delete(1)
	LV_Add("Icon" (lr+2*err), " [" itm "]: " this) ; Add event at end of ListView
	Gui, ListView, listvFULL ; Switch to hidden control (needs to stay up to date)
	LV_Add("Icon" (lr+2*err), " [" itm "]: " this) ; Add event here as well
}
