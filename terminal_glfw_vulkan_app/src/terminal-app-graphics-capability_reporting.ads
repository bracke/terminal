private package Terminal.App.Graphics.Capability_Reporting is
   function Capability
     (Protocol            : Graphics_Protocol;
      Rendering_Available : Boolean) return Protocol_Capability;
   function Color_Emoji
     (Color_Font_Available : Boolean) return Emoji_Capability;
   function Name (Protocol : Graphics_Protocol) return String;
   function Name
     (Protocol : Terminal.Core.Graphics_Protocol_Kind) return String;
   function Status_Label
     (Protocol            : Graphics_Protocol;
      Rendering_Available : Boolean) return String;
end Terminal.App.Graphics.Capability_Reporting;
