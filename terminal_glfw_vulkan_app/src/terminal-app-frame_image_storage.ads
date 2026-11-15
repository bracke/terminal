with Ada.Finalization;
with Terminal.App.Render_Model;
with Terminal.App.Image_Store;
with Terminal.App.Image_Store.Frame_Borrows;
with Terminal.App.Owned_Image_Data;

--  Owns one frame's image commands together with any buffers borrowed by
--  those commands.  Keeping command and owner slots behind one append and
--  truncate API prevents the parallel arrays from drifting apart.
private package Terminal.App.Frame_Image_Storage is
   package RM renames Terminal.App.Render_Model;

   type Storage is new Ada.Finalization.Limited_Controlled with private;

   procedure Ensure_Capacity
     (S        : in out Storage;
      Required : Positive;
      Success  : out Boolean);

   procedure Append
     (S       : in out Storage;
      Command : RM.Image_Command);

   procedure Append_Borrowed_Frame
     (S                : in out Storage;
      Command          : RM.Image_Command;
      Borrowed_Object  : not null Terminal.App.Image_Store.Image_Object_Access;
      Frame_Number     : Positive;
      Use_As_Decoded   : Boolean := True;
      Use_As_Preview   : Boolean := True);

   procedure Append
     (S       : in out Storage;
      Command : RM.Image_Command;
      Decoded : in out Terminal.App.Owned_Image_Data.Owner;
      Encoded : in out Terminal.App.Owned_Image_Data.Owner;
      Preview : in out Terminal.App.Owned_Image_Data.Owner);

   procedure Truncate (S : in out Storage; New_Count : Natural);
   procedure Reset (S : in out Storage);
   procedure Release (S : in out Storage);
   overriding procedure Finalize (S : in out Storage);

   function Count (S : Storage) return Natural;
   function Capacity (S : Storage) return Natural;
   function Is_Full (S : Storage) return Boolean;
   function Commands (S : Storage) return RM.Image_Array_View;
   function Element
     (S     : Storage;
      Index : Positive) return RM.Image_Command;

private
   type Buffer_Ownership is limited record
      Decoded : Terminal.App.Owned_Image_Data.Owner;
      Encoded : Terminal.App.Owned_Image_Data.Owner;
      Preview : Terminal.App.Owned_Image_Data.Owner;
      Borrow : Terminal.App.Image_Store.Frame_Borrows.Token;
   end record;
   type Frame_Slot is limited record
      Owner   : Buffer_Ownership;
   end record;
   type Frame_Slot_Array is array (Positive range <>) of Frame_Slot;

   type Frame_Arena (Capacity : Positive) is limited record
      Slots     : Frame_Slot_Array (1 .. Capacity);
      Published : RM.Image_Array_Access := null;
   end record;
   type Frame_Arena_Access is access Frame_Arena;

   type Storage is new Ada.Finalization.Limited_Controlled with record
      Arena  : Frame_Arena_Access := null;
      Length : Natural := 0;
   end record;
end Terminal.App.Frame_Image_Storage;
