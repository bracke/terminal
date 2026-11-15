with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Response_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   Response_Capacity : constant Natural := Terminal.Core.Max_Title_Length + 16;

   T : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   procedure Assert_Bytes
     (Actual  : Byte_Array;
      Last    : Natural;
      Expect  : Byte_Array;
      Message : String)
   is
   begin
      Assert (Last = Expect'Length, Message & " length");
      for I in Expect'Range loop
         Assert
           (Actual (Actual'First + I - Expect'First) = Expect (I),
            Message & " byte" & Natural'Image (I - Expect'First + 1));
      end loop;
   end Assert_Bytes;

   procedure Run_Status_And_Identity_Cases is separate;
   procedure Run_Mode_And_Status_String_Cases is separate;
   procedure Run_Window_Operation_Cases is separate;
   procedure Run_Overflow_Cases is separate;
begin
   Terminal.Core.Initialize (T, 5, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "initialize failed");

   Run_Status_And_Identity_Cases;
   Run_Mode_And_Status_String_Cases;
   Run_Window_Operation_Cases;
   Run_Overflow_Cases;
end Core_Response_Smoke;
