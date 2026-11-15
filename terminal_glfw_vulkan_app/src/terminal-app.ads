with Terminal.Common.Identity;
with Terminal.Common.Graphics_Limits;
with Terminal.Core;

package Terminal.App is
   type App_Status is (Ok, Initialization_Failed, Runtime_Failed);
   Max_Status_Label_Length : constant := 96;
   --  Protocol-side object retention is independent of how a renderer packs
   --  the subset of images visible in one frame.
   --  Kept as a public compatibility name; the authoritative value is shared
   --  by the parser, renderer, configuration, and Vulkan submission layers.
   Max_Graphics_Image_Objects : constant Positive :=
     Terminal.Common.Graphics_Limits.Max_Image_Objects;

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
   end record;

   function Profile return Terminal_Profile;
   function Graphics_Feature_Report
     (Profile : Terminal.Core.Graphics_Capability_Profile) return String;
   function Profile_Status_Label
     (Profile : Terminal_Profile) return String;
   function Multiplexer_Status_Label
     (Profile : Terminal_Profile) return String;
   function Multiplexer_Diagnostic_Label
     (Diagnostics : Terminal.Core.Diagnostic_Snapshot) return String;
   function Feed_Rank (Status : Terminal.Core.Feed_Status) return Natural;
end Terminal.App;
