with Terminal.Core;

package Terminal.App is
   type App_Status is (Ok, Initialization_Failed, Runtime_Failed);
   Max_Status_Label_Length : constant := 96;

   Term_Name : constant String := "xterm-256color";
   Color_Term : constant String := "truecolor";

   type Terminal_Profile is record
      Bracketed_Paste       : Boolean := True;
      Focus_Reporting       : Boolean := True;
      Xterm_Mouse_Reporting : Boolean := True;
      SGR_Mouse_Coordinates : Boolean := True;
      Synchronized_Update   : Boolean := True;
      OSC52_Clipboard       : Boolean := True;
      OSC52_App_Local_Selections : Boolean := True;
      OSC8_Hyperlinks       : Boolean := True;
      Truecolor             : Boolean := True;
      Tmux_DCS_Passthrough  : Boolean := True;
   end record;

   function Profile return Terminal_Profile;
   function Profile_Status_Label
     (Profile : Terminal_Profile) return String;
   function Multiplexer_Status_Label
     (Profile : Terminal_Profile) return String;
   function Multiplexer_Diagnostic_Label
     (Diagnostics : Terminal.Core.Diagnostic_Snapshot) return String;
end Terminal.App;
