with System;
with Terminal.Common.Bytes;

private package Terminal.App.Borrowed_Bytes is
   type Cursor is limited private;

   procedure Open
     (Item    : in out Cursor;
      Storage : System.Address;
      Length  : Natural);

   function Remaining (Item : Cursor) return Natural;
   function Offset (Item : Cursor) return Natural;
   function Read_Byte
     (Item : in out Cursor) return Terminal.Common.Bytes.Byte;
   function Skip
     (Item  : in out Cursor;
      Count : Natural) return Natural;

private
   type Cursor is limited record
      Storage  : System.Address := System.Null_Address;
      Length   : Natural := 0;
      Position : Natural := 0;
   end record;
end Terminal.App.Borrowed_Bytes;
