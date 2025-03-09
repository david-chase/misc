; Press Ctrl + Shift + D to insert the formatted date (YYYY.MM.DD)
^+d::
FormatTime, CurrentDateTime,, yyyy.MM.dd
SendInput %CurrentDateTime%
return

; Press Ctrl + Shift + T to insert the current time in 24-hour format (HH:MM)
^+t::
FormatTime, CurrentTime,, HH:mm
SendInput %CurrentTime%
return
