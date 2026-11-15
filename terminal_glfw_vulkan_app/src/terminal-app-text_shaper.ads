with Ada.Finalization;
with Terminal.App.Render_Model;
private with Terminal.App.Text_Shaper_State;

package Terminal.App.Text_Shaper is
   Max_Status_Label_Length : constant := 64;

   subtype Run_Kind is Terminal.App.Render_Model.Text_Run_Kind;
   subtype Shape_Status is Terminal.App.Render_Model.Text_Run_Shape_Status;

   type Backend_Status is
     (Backend_Ok,
      Backend_Unavailable,
      Backend_Load_Failed);

   type Shaper is new Ada.Finalization.Limited_Controlled with private;

   procedure Reset (Item : in out Shaper);

   procedure Configure_Font
     (Item   : in out Shaper;
      Path   : String;
      Status : out Backend_Status);

   procedure Add_Fallback_Font
     (Item   : in out Shaper;
      Path   : String;
      Status : out Backend_Status);

   function Backend_Available (Item : Shaper) return Boolean;

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

   --  Classify one terminal cell without constructing a full text-run record.
   procedure Properties_Of
     (Codepoint : Natural;
      Direction : out Terminal.App.Render_Model.Text_Run_Direction;
      Script    : out Terminal.App.Render_Model.Text_Run_Script);

   procedure Prepare
     (Item   : in out Shaper;
      Run    : in out Terminal.App.Render_Model.Text_Run_Command;
      Status : out Shape_Status);

private
   type Shaper is new Ada.Finalization.Limited_Controlled with record
      Data : Terminal.App.Text_Shaper_State.State;
   end record;
   overriding procedure Finalize (Item : in out Shaper);
end Terminal.App.Text_Shaper;
