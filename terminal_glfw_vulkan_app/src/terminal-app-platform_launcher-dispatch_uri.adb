separate (Terminal.App.Platform_Launcher)
procedure Dispatch_URI
  (Preferred_Program : String;
   Fallback_Program  : String;
   URI               : String;
   Status            : out Launch_Status;
   Start             : not null access procedure
     (Program : String;
      URI     : String;
      Status  : out Launch_Status)) is
begin
   --  Both native implementations eventually pass URI through a nul-terminated
   --  platform string.  Reject an embedded terminator at this boundary so a
   --  direct caller cannot make the operating system see a different target
   --  from the Ada value that was validated or displayed.
   if (for some Ch of URI => Ch = ASCII.NUL) then
      Status := Launch_Failed;
   elsif Preferred_Program'Length > 0 then
      Start (Preferred_Program, URI, Status);
   elsif Fallback_Program'Length > 0 then
      Start (Fallback_Program, URI, Status);
   else
      Status := Launcher_Unavailable;
   end if;
exception
   when others =>
      Status := Launch_Failed;
end Dispatch_URI;
