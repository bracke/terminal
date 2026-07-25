with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Response_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

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
begin
   Terminal.Core.Initialize (T, 5, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "initialize failed");

   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[5n"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "DSR status feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 4,
      "DSR status response length");

   declare
      Buffer : Byte_Array (1 .. 8);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes (Buffer, Last, To_Bytes (ASCII.ESC & "[0n"), "DSR status");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "DSR status should drain");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "[3;4H" & ASCII.ESC & "[6n"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "CPR feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 6,
      "CPR response length");

   declare
      First  : Byte_Array (1 .. 3);
      Second : Byte_Array (1 .. 8);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, First, Last);
      Assert_Bytes (First, Last, To_Bytes (ASCII.ESC & "[3"), "CPR first drain");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 3,
         "CPR partial response length");

      Terminal.Core.Read_Response (T, Second, Last);
      Assert_Bytes (Second, Last, To_Bytes (";4R"), "CPR second drain");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "CPR should drain");
   end;
end Core_Response_Smoke;
