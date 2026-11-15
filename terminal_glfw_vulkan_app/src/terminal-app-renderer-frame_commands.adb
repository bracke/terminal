with Terminal.App.Frame_Image_Storage;
with Terminal.App.Owned_Image_Data;

package body Terminal.App.Renderer.Frame_Commands is
   package FIS renames Terminal.App.Frame_Image_Storage;

   function Count (R : Renderer) return Natural is
     (FIS.Count (R.Frame_State.Frame_Images));

   function Commands (R : Renderer) return RM.Image_Array_View is
     (FIS.Commands (R.Frame_State.Frame_Images));

   function Capacity (R : Renderer) return Natural is
     (FIS.Capacity (R.Frame_State.Frame_Images));

   procedure Append_Borrowed_Frame
     (R                : in out Renderer;
      Command          : RM.Image_Command;
      Borrowed_Object  : not null Image_Object_Access;
      Frame_Number     : Positive;
      Use_As_Decoded   : Boolean := True;
      Use_As_Preview   : Boolean := True) is
   begin
      if FIS.Is_Full (R.Frame_State.Frame_Images) then
         R.Frame_State.Frame_Command_Overflowed := True;
      else
         FIS.Append_Borrowed_Frame
           (R.Frame_State.Frame_Images,
            Command,
            Borrowed_Object,
            Frame_Number,
            Use_As_Decoded,
            Use_As_Preview);
      end if;
   end Append_Borrowed_Frame;

   procedure Append
     (R               : in out Renderer;
      Command         : RM.Image_Command;
      Decoded         : in out Terminal.App.Owned_Image_Data.Owner;
      Encoded         : in out Terminal.App.Owned_Image_Data.Owner;
      Preview         : in out Terminal.App.Owned_Image_Data.Owner) is
   begin
      if FIS.Is_Full (R.Frame_State.Frame_Images) then
         R.Frame_State.Frame_Command_Overflowed := True;
         Terminal.App.Owned_Image_Data.Release (Decoded);
         Terminal.App.Owned_Image_Data.Release (Encoded);
         Terminal.App.Owned_Image_Data.Release (Preview);
      else
         FIS.Append
           (R.Frame_State.Frame_Images,
            Command,
            Decoded,
            Encoded,
            Preview);
      end if;
   end Append;

   procedure Truncate (R : in out Renderer; New_Count : Natural) is
   begin
      FIS.Truncate (R.Frame_State.Frame_Images, New_Count);
   end Truncate;
end Terminal.App.Renderer.Frame_Commands;
