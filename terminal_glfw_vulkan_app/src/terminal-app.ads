with Terminal.Common.Identity;
with Terminal.Core;

package Terminal.App is
   type App_Status is (Ok, Initialization_Failed, Runtime_Failed);
   Max_Status_Label_Length : constant := 96;

   Term_Name : constant String := "xterm-256color";
   Color_Term : constant String := "truecolor";
   Term_Program : constant String := Terminal.Common.Identity.Program_Name;
   Term_Program_Version : constant String := Terminal.Common.Identity.Program_Version;

   type Terminal_Profile is record
      Bracketed_Paste       : Boolean := True;
      Focus_Reporting       : Boolean := True;
      Xterm_Mouse_Reporting : Boolean := True;
      UTF8_Mouse_Coordinates : Boolean := True;
      SGR_Mouse_Coordinates : Boolean := True;
      URXVT_Mouse_Coordinates : Boolean := True;
      Synchronized_Update   : Boolean := True;
      OSC52_Clipboard       : Boolean := True;
      OSC52_App_Local_Selections : Boolean := True;
      OSC8_Hyperlinks       : Boolean := True;
      Truecolor             : Boolean := True;
      Tmux_DCS_Passthrough  : Boolean := True;
      Kitty_Direct_Graphics : Boolean := True;
      Kitty_Unicode_Placeholders : Boolean := True;
      Kitty_File_Transfer   : Boolean := False;
      Kitty_Temporary_Transfer : Boolean := True;
      Kitty_Shared_Memory   : Boolean := True;
      ITerm2_File_Downloads : Boolean := False;
   end record;

   function Profile return Terminal_Profile;
   function Core_Graphics_Profile
     return Terminal.Core.Graphics_Capability_Profile;
   function Core_Graphics_Profile
     (Kitty_File_Transfer      : Boolean;
      Kitty_Temporary_Transfer : Boolean;
      Kitty_Shared_Memory      : Boolean;
      ITerm2_File_Downloads    : Boolean := False)
      return Terminal.Core.Graphics_Capability_Profile;
   function Graphics_Feature_Report
     (Profile : Terminal.Core.Graphics_Capability_Profile) return String;
   function Profile_Status_Label
     (Profile : Terminal_Profile) return String;
   function Multiplexer_Status_Label
     (Profile : Terminal_Profile) return String;
   function Multiplexer_Diagnostic_Label
     (Diagnostics : Terminal.Core.Diagnostic_Snapshot) return String;
end Terminal.App;
