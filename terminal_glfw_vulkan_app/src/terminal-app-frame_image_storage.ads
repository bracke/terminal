with Ada.Finalization;
with Terminal.App.Render_Model;

--  Owns one frame's image commands together with any buffers borrowed by
--  those commands.  Keeping command and owner slots behind one append and
--  truncate API prevents the parallel arrays from drifting apart.
package Terminal.App.Frame_Image_Storage is
   package RM renames Terminal.App.Render_Model;

   type Storage is new Ada.Finalization.Limited_Controlled with private;

   procedure Ensure_Capacity
     (S        : in out Storage;
      Required : Positive;
      Success  : out Boolean);

   procedure Append
     (S       : in out Storage;
      Command : RM.Image_Command);

   procedure Append
     (S       : in out Storage;
      Command : RM.Image_Command;
      Decoded : in out RM.Image_Data_Access;
      Encoded : in out RM.Image_Data_Access;
      Preview : in out RM.Image_Data_Access);

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
   type Buffer_Ownership is record
      Decoded : RM.Image_Data_Access := null;
      Encoded : RM.Image_Data_Access := null;
      Preview : RM.Image_Data_Access := null;
   end record;
   type Buffer_Ownership_Array is
     array (Positive range <>) of Buffer_Ownership;
   type Buffer_Ownership_Array_Access is access Buffer_Ownership_Array;

   type Storage is new Ada.Finalization.Limited_Controlled with record
      Items  : RM.Image_Array_Access := null;
      Owners : Buffer_Ownership_Array_Access := null;
      Length : Natural := 0;
   end record;
end Terminal.App.Frame_Image_Storage;
