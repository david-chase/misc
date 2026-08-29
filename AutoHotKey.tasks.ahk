; Save a bunch of keystrokes for use with Obsidian tasks
!+m::
SendInput {Text}🟡 MEDIUM
return

!+h::
SendInput {Text}🟠 HIGH 
return

!+l::
SendInput {Text}🔵 LOW  
return

!+d::
FormatTime, CurrentDateTime,, yyyy.MM.dd
SendInput 📅``%CurrentDateTime%``{Space}
return

!+t::
FormatTime, CurrentTime,, HH:mm
SendInput 🕒``%CurrentTime%``{Space}
return

!+c::
FormatTime, CurrentDateTime,, yyyy.MM.dd
SendInput ✅``%CurrentDateTime%``{Space}
return