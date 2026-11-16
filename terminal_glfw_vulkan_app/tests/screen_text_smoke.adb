with AUnit.Assertions;
with Terminal.App.Screen_Text;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Screen_Text_Smoke is
   use AUnit.Assertions;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   Core : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;

   function Bytes (Text : String) return Terminal.Common.Bytes.Byte_Array is
      Result : Terminal.Common.Bytes.Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) :=
           Terminal.Common.Bytes.Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end Bytes;
begin
   Terminal.Core.Initialize (Core, 3, 6, 4, Init);
   Assert (Init = Terminal.Core.Ok, "screen text core initialized");
   Terminal.Core.Feed
     (Core, Bytes ("one" & ASCII.CR & ASCII.LF & "two "), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "screen text input accepted");
   declare
      Snapshot : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (Core);
   begin
      Assert
        (Terminal.App.Screen_Text.Visible (Snapshot) =
           "one" & ASCII.LF & "two " & ASCII.LF,
         "visible text trims empty cells but retains explicit spaces and rows");
      Assert
        (Terminal.App.Screen_Text.Visible (Snapshot, 4) = "one" & ASCII.LF,
         "visible text stops at the bounded cluster boundary");
      Terminal.Core.Release (Snapshot);
   end;
end Screen_Text_Smoke;
