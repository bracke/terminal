with Terminal.App.Render_Model;

package Terminal.App.Text_Shaper is
   Max_Status_Label_Length : constant := 64;

   subtype Run_Kind is Terminal.App.Render_Model.Text_Run_Kind;
   subtype Shape_Status is Terminal.App.Render_Model.Text_Run_Shape_Status;

   type Backend_Status is
     (Backend_Ok,
      Backend_Unavailable,
      Backend_Load_Failed);

   procedure Configure_Font
     (Path        : String;
      Pixel_Size  : Positive;
      Status      : out Backend_Status);

   procedure Add_Fallback_Font
     (Path        : String;
      Pixel_Size  : Positive;
      Status      : out Backend_Status);

   function Backend_Available return Boolean;

   function Backend_Status_Label (Status : Backend_Status) return String;
   function Shape_Status_Label (Status : Shape_Status) return String;

   function Classify
     (Run : Terminal.App.Render_Model.Text_Run_Command) return Run_Kind;

   function Requires_Backend (Kind : Run_Kind) return Boolean;

   function Direction_Of
     (Run : Terminal.App.Render_Model.Text_Run_Command)
      return Terminal.App.Render_Model.Text_Run_Direction;

   function Script_Of
     (Run : Terminal.App.Render_Model.Text_Run_Command)
      return Terminal.App.Render_Model.Text_Run_Script;

   procedure Prepare
     (Run    : in out Terminal.App.Render_Model.Text_Run_Command;
      Status : out Shape_Status);
end Terminal.App.Text_Shaper;
