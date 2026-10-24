with Terminal.App.Platform_Media;

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
         UTF8_Mouse_Coordinates => True,
         SGR_Mouse_Coordinates => True,
         URXVT_Mouse_Coordinates => True,
         Synchronized_Update   => True,
         OSC52_Clipboard       => True,
         OSC52_App_Local_Selections => True,
         OSC8_Hyperlinks       => True,
         Truecolor             => True,
         Tmux_DCS_Passthrough  => True,
         Kitty_Direct_Graphics => True,
         Kitty_Unicode_Placeholders => True,
         Kitty_File_Transfer   => False,
         Kitty_Temporary_Transfer =>
           Terminal.App.Platform_Media.Local_File_Transfers_Available,
         Kitty_Shared_Memory   =>
           Terminal.App.Platform_Media.Shared_Memory_Transfers_Available,
         ITerm2_File_Downloads => False);
   end Profile;

   function Core_Graphics_Profile
     return Terminal.Core.Graphics_Capability_Profile is
   begin
      return Core_Graphics_Profile
        (Kitty_File_Transfer      => False,
         Kitty_Temporary_Transfer => True,
         Kitty_Shared_Memory      => True,
         ITerm2_File_Downloads    => False);
   end Core_Graphics_Profile;

   function Core_Graphics_Profile
     (Kitty_File_Transfer      : Boolean;
      Kitty_Temporary_Transfer : Boolean;
      Kitty_Shared_Memory      : Boolean;
      ITerm2_File_Downloads    : Boolean := False)
      return Terminal.Core.Graphics_Capability_Profile is
   begin
      return
     ((Kitty_Direct_RGB         => True,
       Kitty_Direct_RGBA        => True,
       Kitty_Indexed_RGB        => True,
       Kitty_Indexed_RGBA       => True,
       Kitty_Direct_PNG         => True,
       Kitty_Direct_JPEG        => True,
       Kitty_Direct_GIF         => True,
       Kitty_Zlib_Compression   => True,
       Kitty_File_Transfer      =>
         Kitty_File_Transfer
           and then Terminal.App.Platform_Media.Local_File_Transfers_Available,
       Kitty_Temporary_Transfer =>
         Kitty_Temporary_Transfer
           and then Terminal.App.Platform_Media.Local_File_Transfers_Available,
       Kitty_Shared_Memory      =>
         Kitty_Shared_Memory
           and then
             Terminal.App.Platform_Media.Shared_Memory_Transfers_Available,
       Sixel                    => True,
       ITerm2_Inline_Images     => True,
       ITerm2_File_Downloads    =>
         ITerm2_File_Downloads
           and then Terminal.App.Platform_Media.File_Downloads_Available));
   end Core_Graphics_Profile;

   function Graphics_Feature_Report
     (Profile : Terminal.Core.Graphics_Capability_Profile) return String is
   begin
      if Profile.ITerm2_Inline_Images
        and then Profile.ITerm2_File_Downloads
      then
         return (if Profile.Sixel then "FSx" else "F");
      else
         return (if Profile.Sixel then "Sx" else "");
      end if;
   end Graphics_Feature_Report;

   function Profile_Status_Label
     (Profile : Terminal_Profile) return String is
   begin
      if Profile.Truecolor
        and then Profile.OSC52_Clipboard
        and then Profile.OSC52_App_Local_Selections
        and then Profile.OSC8_Hyperlinks
        and then Profile.Kitty_Direct_Graphics
        and then Profile.Kitty_Unicode_Placeholders
      then
         return
           "xterm-256color truecolor profile; Kitty placeholders; "
           & "OSC 52 selections app-local";
      else
         return "reduced terminal profile";
      end if;
   end Profile_Status_Label;

   function Multiplexer_Status_Label
     (Profile : Terminal_Profile) return String is
   begin
      if Profile.Tmux_DCS_Passthrough then
         return "tmux DCS passthrough enabled";
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
