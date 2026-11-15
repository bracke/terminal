with System.Address_To_Access_Conversions;
with System.Storage_Elements;

package body Terminal.App.Borrowed_Bytes is
   use type System.Address;
   use type System.Storage_Elements.Storage_Offset;

   package Byte_Addresses is new System.Address_To_Access_Conversions
     (Terminal.Common.Bytes.Byte);

   procedure Open
     (Item    : in out Cursor;
      Storage : System.Address;
      Length  : Natural) is
   begin
      if Length > 0 and then Storage = System.Null_Address then
         raise Constraint_Error with
           "nonempty borrowed byte storage requires a valid address";
      end if;
      Item.Storage := Storage;
      Item.Length := Length;
      Item.Position := 0;
   end Open;

   function Remaining (Item : Cursor) return Natural is
     (Item.Length - Item.Position);

   function Offset (Item : Cursor) return Natural is (Item.Position);

   function Read_Byte
     (Item : in out Cursor) return Terminal.Common.Bytes.Byte
   is
      Result : Terminal.Common.Bytes.Byte;
   begin
      if Item.Position >= Item.Length then
         raise Constraint_Error with "borrowed byte cursor is exhausted";
      end if;
      Result := Byte_Addresses.To_Pointer
        (Item.Storage
         + System.Storage_Elements.Storage_Offset (Item.Position)).all;
      Item.Position := Item.Position + 1;
      return Result;
   end Read_Byte;

   function Skip
     (Item  : in out Cursor;
      Count : Natural) return Natural
   is
      Amount : constant Natural := Natural'Min (Remaining (Item), Count);
   begin
      Item.Position := Item.Position + Amount;
      return Amount;
   end Skip;
end Terminal.App.Borrowed_Bytes;
