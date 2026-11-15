with Ada.Finalization;
with Terminal.App.Render_Model;

--  Internal bridge used by frame storage to pin store-owned byte views.
--  The Image_Store parent keeps the counter and deferred-release mechanics
--  private; clients cannot manufacture or inspect borrow state.
package Terminal.App.Image_Store.Frame_Borrows is
   type Token is new Ada.Finalization.Limited_Controlled with private;
   procedure Acquire
     (Item   : in out Token;
      Object : Image_Object_Access);
   procedure Acquire_Frame
     (Item   : in out Token;
      Object : Image_Object_Access;
      Number : Positive;
      Data   : out Terminal.App.Render_Model.Image_Data_View);
   procedure Release (Item : in out Token);
   procedure Move (Source, Target : in out Token);
   overriding procedure Finalize (Item : in out Token);
private
   type Token is new Ada.Finalization.Limited_Controlled with record
      Hold : Frame_Borrow_Hold;
   end record;
end Terminal.App.Image_Store.Frame_Borrows;
