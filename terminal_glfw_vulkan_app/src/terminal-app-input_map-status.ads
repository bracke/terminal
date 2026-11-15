with Terminal.Core;

private package Terminal.App.Input_Map.Status is
   function Paste_Label (Modes : Terminal.Core.Mode_Snapshot) return String;
   function Focus_Label (Modes : Terminal.Core.Mode_Snapshot) return String;
   function Keyboard_Label (Modes : Terminal.Core.Mode_Snapshot) return String;
   function Key_Mode_Label (Modes : Terminal.Core.Mode_Snapshot) return String;
   function Input_Label (Modes : Terminal.Core.Mode_Snapshot) return String;
   function Mouse_Reporting_Enabled
     (Modes : Terminal.Core.Mode_Snapshot) return Boolean;
   function Mouse_Label (Modes : Terminal.Core.Mode_Snapshot) return String;
end Terminal.App.Input_Map.Status;
