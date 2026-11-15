with Ada.Finalization;
with Terminal.Common.Bytes;
with Terminal.App.Render_Model;

--  Explicit single-owner boundary for heap-backed image data.
package Terminal.App.Owned_Image_Data is
   package RM renames Terminal.App.Render_Model;

   type Owner is new Ada.Finalization.Limited_Controlled with private;

   procedure Release (Item : in out Owner);
   procedure Allocate (Item : in out Owner; Length : Positive);
   procedure Move (Source : in out Owner; Target : in out Owner);
   function Is_Empty (Item : Owner) return Boolean;
   --  The returned access value does not pin Item. It is valid only while Item
   --  remains populated and unmoved. Prefer Read or Modify unless a surrounding
   --  object explicitly retains Item for the complete lifetime of the view.
   function Unsafe_View (Item : Owner) return RM.Image_Data_View;
   function Owns
     (Item : Owner; Data : RM.Image_Data_View) return Boolean;
   function Length (Item : Owner) return Natural with Inline;
   function Element
     (Item : Owner; Offset : Positive) return Terminal.Common.Bytes.Byte
     with Inline;
   procedure Replace_Element
     (Item   : in out Owner;
      Offset : Positive;
      Value  : Terminal.Common.Bytes.Byte)
     with Inline;
   procedure Fill
     (Item  : in out Owner;
      Value : Terminal.Common.Bytes.Byte);
   procedure Copy
     (Item   : in out Owner;
      Source : Terminal.Common.Bytes.Byte_Array;
      Offset : Positive := 1);
   procedure Modify
     (Item    : in out Owner;
      Process : not null access procedure
        (Data : in out Terminal.Common.Bytes.Byte_Array));
   procedure Read
     (Item    : Owner;
      Process : not null access procedure
        (Data : Terminal.Common.Bytes.Byte_Array));

   overriding procedure Finalize (Item : in out Owner);

private
   type Image_Data_Access is access all Terminal.Common.Bytes.Byte_Array;
   type Owner is new Ada.Finalization.Limited_Controlled with record
      Value : Image_Data_Access := null;
   end record;
end Terminal.App.Owned_Image_Data;
