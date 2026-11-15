package body Terminal.App.Borrowed_Stream is
   package body Adapter is
   procedure Open
     (Data    : in out Terminal.App.Borrowed_Bytes.Cursor;
      Storage : System.Address;
      Length  : Natural) is
   begin
      Terminal.App.Borrowed_Bytes.Open (Data, Storage, Length);
   end Open;

   function Read
     (Data   : in out Terminal.App.Borrowed_Bytes.Cursor;
      Buffer : out External_Byte_Array) return External_Result
   is
      Amount : constant Natural :=
        Natural'Min
          (Terminal.App.Borrowed_Bytes.Remaining (Data), Buffer'Length);
   begin
      if Amount > 0 then
         for I in 0 .. Amount - 1 loop
            Buffer (Buffer'First + I) := External_Byte
              (Terminal.App.Borrowed_Bytes.Read_Byte (Data));
         end loop;
      end if;
      return Success
        (External_Count (Amount),
         Terminal.App.Borrowed_Bytes.Remaining (Data) = 0);
   end Read;

   function Offset
     (Data : Terminal.App.Borrowed_Bytes.Cursor) return External_Offset is
   begin
      return External_Offset (Terminal.App.Borrowed_Bytes.Offset (Data));
   end Offset;

   function Skip
     (Data  : in out Terminal.App.Borrowed_Bytes.Cursor;
      Count : External_Count) return External_Result
   is
      Requested : constant Natural :=
        (if Count <= 0 then 0
         elsif Count > External_Count (Natural'Last)
         then Natural'Last else Natural (Count));
      Amount : constant Natural :=
        Terminal.App.Borrowed_Bytes.Skip (Data, Requested);
   begin
      return Success
        (External_Count (Amount),
         Terminal.App.Borrowed_Bytes.Remaining (Data) = 0);
   end Skip;
   end Adapter;
end Terminal.App.Borrowed_Stream;
