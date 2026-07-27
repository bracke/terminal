package body Terminal.App is
   function Trim_Image (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Trim_Image;

   function Profile return Terminal_Profile is
   begin
      return
        (Bracketed_Paste       => True,
         Focus_Reporting       => True,
         Xterm_Mouse_Reporting => True,
         SGR_Mouse_Coordinates => True,
         Synchronized_Update   => True,
         OSC52_Clipboard       => True,
         OSC52_App_Local_Selections => True,
         OSC8_Hyperlinks       => True,
         Truecolor             => True,
         Tmux_DCS_Passthrough  => True);
   end Profile;

   function Profile_Status_Label
     (Profile : Terminal_Profile) return String is
   begin
      if Profile.Truecolor
        and then Profile.OSC52_Clipboard
        and then Profile.OSC52_App_Local_Selections
        and then Profile.OSC8_Hyperlinks
      then
         return "xterm-256color truecolor profile; OSC 52 selections app-local";
      else
         return "reduced terminal profile";
      end if;
   end Profile_Status_Label;

   function Multiplexer_Status_Label
     (Profile : Terminal_Profile) return String is
   begin
      if Profile.Tmux_DCS_Passthrough then
         return "tmux DCS passthrough enabled; full multiplexer sessions postponed";
      else
         return "terminal multiplexer passthrough disabled";
      end if;
   end Multiplexer_Status_Label;

   function Multiplexer_Diagnostic_Label
     (Diagnostics : Terminal.Core.Diagnostic_Snapshot) return String is
   begin
      if Diagnostics.Multiplexer_Passthrough = 0 then
         return "";
      elsif Diagnostics.Multiplexer_Passthrough = 1 then
         return "tmux passthrough handled 1 sequence";
      else
         return
           "tmux passthrough handled "
           & Trim_Image (Diagnostics.Multiplexer_Passthrough)
           & " sequences";
      end if;
   end Multiplexer_Diagnostic_Label;
end Terminal.App;
