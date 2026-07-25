with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Cursor_Smoke is
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

   procedure Feed_Text (Text : String; Message : String) is
   begin
      Terminal.Core.Feed (T, To_Bytes (Text), Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, Message);
   end Feed_Text;

   procedure Assert_Cursor
     (Row     : Positive;
      Col     : Positive;
      Message : String)
   is
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Cursor.Row = Row and then S.Cursor.Col = Col,
         Message
         & " row"
         & Positive'Image (S.Cursor.Row)
         & " col"
         & Positive'Image (S.Cursor.Col));
      Terminal.Core.Release (S);
   end Assert_Cursor;
begin
   Terminal.Core.Initialize (T, 5, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "initialize failed");

   Feed_Text (ASCII.ESC & "[4;3H", "CUP feed failed");
   Assert_Cursor (4, 3, "CUP should position cursor");

   Feed_Text (ASCII.ESC & "[7`", "HPA feed failed");
   Assert_Cursor (4, 7, "HPA should set absolute column");

   Feed_Text (ASCII.ESC & "[2a", "HPR feed failed");
   Assert_Cursor (4, 9, "HPR should move right");

   Feed_Text (ASCII.ESC & "[2d", "VPA feed failed");
   Assert_Cursor (2, 9, "VPA should set absolute row");

   Feed_Text (ASCII.ESC & "[2e", "VPR feed failed");
   Assert_Cursor (4, 9, "VPR should move down");

   Feed_Text (ASCII.ESC & "[99a" & ASCII.ESC & "[99e", "cursor clamp feed failed");
   Assert_Cursor (5, 10, "HPR/VPR should clamp at screen edge");
end Core_Cursor_Smoke;
