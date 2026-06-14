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

^+r::
    Loop, 6
    {
        ; Randomly choose between a number (0-9) or a lowercase letter (a-z)
        Random, type, 1, 2
        if (type = 1)
        {
            Random, char, 48, 57   ; ASCII codes for 0-9
        }
        else
        {
            Random, char, 97, 122  ; ASCII codes for a-z
        }
        String .= Chr(char)
    }
    SendInput, %String%
    String := "" ; Clear the variable for the next run
return