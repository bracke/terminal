with Terminal.App.Owned_Image_Data;

private package Terminal.App.Renderer.Frame_Commands is
   package RM renames Terminal.App.Render_Model;

   function Count (R : Renderer) return Natural;
   function Commands (R : Renderer) return RM.Image_Array_View;
   function Capacity (R : Renderer) return Natural;

   procedure Append_Borrowed_Frame
     (R                : in out Renderer;
      Command          : RM.Image_Command;
      Borrowed_Object  : not null Image_Object_Access;
      Frame_Number     : Positive;
      Use_As_Decoded   : Boolean := True;
      Use_As_Preview   : Boolean := True);
   procedure Append
     (R               : in out Renderer;
      Command         : RM.Image_Command;
      Decoded         : in out Terminal.App.Owned_Image_Data.Owner;
      Encoded         : in out Terminal.App.Owned_Image_Data.Owner;
      Preview         : in out Terminal.App.Owned_Image_Data.Owner);
   procedure Truncate (R : in out Renderer; New_Count : Natural);
end Terminal.App.Renderer.Frame_Commands;
