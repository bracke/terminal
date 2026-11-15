with Ada.Unchecked_Deallocation;

package body Terminal.App.Shared_Image_Data is
   use type Control_Access;
   use type RM.Image_Data_View;

   procedure Free_Data is new Ada.Unchecked_Deallocation
     (Terminal.Common.Bytes.Byte_Array, Image_Data_Access);
   procedure Free_Control is new Ada.Unchecked_Deallocation
     (Control_Block, Control_Access);

   protected body Reference_Counter is
      procedure Acquire is
      begin
         if Count = Natural'Last then
            raise Storage_Error with "shared image reference count exhausted";
         elsif Count = 0 then
            raise Program_Error with "acquiring released shared image data";
         end if;
         Count := Count + 1;
      end Acquire;

      procedure Release (Is_Last : out Boolean) is
      begin
         if Count = 0 then
            raise Program_Error with "shared image reference count underflow";
         end if;
         Count := Count - 1;
         Is_Last := Count = 0;
      end Release;
   end Reference_Counter;

   procedure Reset (Item : in out Handle) is
      Previous : Control_Access := Item.Control;
      Is_Last  : Boolean := False;
   begin
      Item.Control := null;
      if Previous = null then
         return;
      end if;
      Previous.References.Release (Is_Last);
      if Is_Last then
         Free_Data (Previous.Data);
         Free_Control (Previous);
      end if;
   end Reset;

   procedure Set
     (Item   : in out Handle;
      Source : RM.Image_Data_View;
      Length : Natural)
   is
      Replacement : Control_Access := null;
   begin
      if Source = null or else Length = 0 then
         Reset (Item);
         return;
      elsif Length > Source'Length then
         raise Constraint_Error with "shared image source is too short";
      end if;
      Replacement := new Control_Block;
      begin
         Replacement.Data :=
           new Terminal.Common.Bytes.Byte_Array'(1 .. Length => 0);
         Replacement.Data.all :=
           Source (Source'First .. Source'First + Length - 1);
      exception
         when others =>
            Free_Data (Replacement.Data);
            Free_Control (Replacement);
            raise;
      end;
      Reset (Item);
      Item.Control := Replacement;
   end Set;

   function View (Item : Handle) return RM.Image_Data_View is
     (if Item.Control = null
      then null
      else RM.Image_Data_View (Item.Control.Data));

   overriding procedure Adjust (Item : in out Handle) is
   begin
      if Item.Control /= null then
         Item.Control.References.Acquire;
      end if;
   end Adjust;

   overriding procedure Finalize (Item : in out Handle) is
   begin
      Reset (Item);
   end Finalize;
end Terminal.App.Shared_Image_Data;
