with Ada.Unchecked_Deallocation;
with Terminal.Common.Bytes;
with Terminal.App.Cleanup_Diagnostics;
with System;

package body Terminal.App.Owned_Image_Data is
   use type Image_Data_Access;
   use type RM.Image_Data_View;
   use type System.Address;

   procedure Free is new Ada.Unchecked_Deallocation
     (Terminal.Common.Bytes.Byte_Array, Image_Data_Access);

   procedure Release (Item : in out Owner) is
   begin
      if Item.Value /= null then
         Free (Item.Value);
      end if;
   end Release;

   procedure Allocate (Item : in out Owner; Length : Positive) is
   begin
      if Item.Value /= null then
         raise Program_Error with "image-data owner is already populated";
      end if;
      Item.Value := new Terminal.Common.Bytes.Byte_Array (1 .. Length);
   end Allocate;

   procedure Move (Source : in out Owner; Target : in out Owner) is
   begin
      if Source'Address = Target'Address then
         return;
      elsif Target.Value /= null then
         raise Program_Error with "image-data move target is already populated";
      end if;
      Target.Value := Source.Value;
      Source.Value := null;
   end Move;

   function Is_Empty (Item : Owner) return Boolean is (Item.Value = null);

   function Unsafe_View (Item : Owner) return RM.Image_Data_View is
     (RM.Image_Data_View (Item.Value));

   function Owns
     (Item : Owner; Data : RM.Image_Data_View) return Boolean is
     (Item.Value /= null and then Data = RM.Image_Data_View (Item.Value));

   procedure Assert_Populated (Item : Owner);

   function Length (Item : Owner) return Natural is
     (if Item.Value = null then 0 else Item.Value'Length);

   function Element
     (Item : Owner; Offset : Positive) return Terminal.Common.Bytes.Byte is
   begin
      Assert_Populated (Item);
      if Offset > Item.Value'Length then
         raise Constraint_Error with "image-data offset outside owner extent";
      end if;
      return Item.Value (Item.Value'First + Offset - 1);
   end Element;

   procedure Replace_Element
     (Item   : in out Owner;
      Offset : Positive;
      Value  : Terminal.Common.Bytes.Byte) is
   begin
      Assert_Populated (Item);
      if Offset > Item.Value'Length then
         raise Constraint_Error with "image-data offset outside owner extent";
      end if;
      Item.Value (Item.Value'First + Offset - 1) := Value;
   end Replace_Element;

   procedure Assert_Populated (Item : Owner) is
   begin
      if Item.Value = null then
         raise Program_Error with "image-data owner is empty";
      end if;
   end Assert_Populated;

   procedure Fill
     (Item  : in out Owner;
      Value : Terminal.Common.Bytes.Byte) is
   begin
      Assert_Populated (Item);
      Item.Value.all := (others => Value);
   end Fill;

   procedure Copy
     (Item   : in out Owner;
      Source : Terminal.Common.Bytes.Byte_Array;
      Offset : Positive := 1)
   is
      First : Positive;
      Last  : Natural;
   begin
      Assert_Populated (Item);
      if Offset > Item.Value'Length
        or else Source'Length > Item.Value'Length - Offset + 1
      then
         raise Constraint_Error with "image-data copy exceeds owner extent";
      end if;
      First := Item.Value'First + Offset - 1;
      Last := First + Source'Length - 1;
      Item.Value (First .. Last) := Source;
   end Copy;

   procedure Modify
     (Item    : in out Owner;
      Process : not null access procedure
        (Data : in out Terminal.Common.Bytes.Byte_Array)) is
   begin
      Assert_Populated (Item);
      Process (Item.Value.all);
   end Modify;

   procedure Read
     (Item    : Owner;
      Process : not null access procedure
        (Data : Terminal.Common.Bytes.Byte_Array)) is
   begin
      Assert_Populated (Item);
      Process (Item.Value.all);
   end Read;

   overriding procedure Finalize (Item : in out Owner) is
   begin
      Release (Item);
   exception
      when E : others =>
         Item.Value := null;
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Image_Install,
            E,
            "finalize owned image data");
   end Finalize;
end Terminal.App.Owned_Image_Data;
