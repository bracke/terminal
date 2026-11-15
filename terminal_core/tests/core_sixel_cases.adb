with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.Core.Snapshot_Testing;
with Core_String_Smoke_Support;

procedure Core_Sixel_Cases is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Clipboard_Operation;
   use type Terminal.Core.Clipboard_Target;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Graphics_Protocol_Kind;
   use type Terminal.Core.Initialize_Status;
   use Core_String_Smoke_Support;

   T           : Terminal.Core.Terminal;
   Init        : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;
begin
   Terminal.Core.Initialize (T, 2, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "sixel shared palette initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "[?1070l"
         & ASCII.ESC & "Pq#5;2;100;0;0~" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "sixel shared palette feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (not Terminal.Core.Modes (T).Sixel_Private_Colors
         and then S.Graphics.Pending
         and then not S.Graphics.Sixel_Private_Colors,
         "sixel palette mode should be captured with each graphics event");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 4, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "oversized sixel cursor initialize failed");
   Terminal.Core.Set_Graphics_Resource_Limits
     (T, (Pixel_Dimension => 64, others => <>));
   Terminal.Core.Set_Cell_Pixel_Size (T, Width => 8, Height => 10);
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "[2;3H"
         & ASCII.ESC & "Pq""1;1;1;999999999~" & ASCII.ESC & "\"),
      Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok,
      "oversized sixel cursor feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Graphics.Pending
         and then S.Cursor.Row = 2
         and then S.Cursor.Col = 3,
         "oversized rejected sixel must not perform unbounded cursor work");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 4, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "sixel aspect cursor initialize failed");
   Terminal.Core.Set_Cell_Pixel_Size (T, Width => 8, Height => 10);
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "[1;3H"
         & ASCII.ESC & "Pq""2;1;8;6~" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "sixel aspect cursor feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Cursor.Row = 3 and then S.Cursor.Col = 3,
         "sixel cursor advance should include Pan/Pad vertical scaling");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 4, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "sixel DCS aspect initialize failed");
   Terminal.Core.Set_Cell_Pixel_Size (T, Width => 8, Height => 10);
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "[1;3H"
         & ASCII.ESC & "P5q~" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "sixel DCS aspect feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Cursor.Row = 3 and then S.Cursor.Col = 3,
         "sixel DCS aspect selector should affect cursor advancement");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 4, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "sixel cursor initialize failed");
   Terminal.Core.Set_Cell_Pixel_Size (T, Width => 8, Height => 10);
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "[2;3H"
         & ASCII.ESC & "Pq""1;1;8;15~" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "sixel cursor feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Graphics.Pending
         and then S.Graphics.Row = 2
         and then S.Graphics.Col = 3,
         "scrolling sixel should retain its starting cursor cell");
      Assert
        (S.Cursor.Row = 4 and then S.Cursor.Col = 3,
         "scrolling sixel should advance to the next complete text line");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 4, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "DECSDM initialize failed");
   Terminal.Core.Set_Cell_Pixel_Size (T, Width => 8, Height => 10);
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "[3;4H" & ASCII.ESC & "[?80h"
         & ASCII.ESC & "Pq~" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "DECSDM sixel feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      M : constant Terminal.Core.Mode_Snapshot := Terminal.Core.Modes (T);
   begin
      Assert
        (M.Sixel_Display_Mode
         and then S.Graphics.Row = 1
         and then S.Graphics.Col = 1,
         "DECSDM should place sixel graphics at the page origin");
      Assert
        (S.Cursor.Row = 3 and then S.Cursor.Col = 4,
         "DECSDM should leave the text cursor unchanged");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 4, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "sixel right-scroll initialize failed");
   Terminal.Core.Set_Cell_Pixel_Size (T, Width => 8, Height => 10);
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "[2;2H" & ASCII.ESC & "[?8452h"
         & ASCII.ESC & "Pq""1;1;17;6~" & ASCII.ESC & "\"),
      Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok, "sixel right-scroll feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      M : constant Terminal.Core.Mode_Snapshot := Terminal.Core.Modes (T);
   begin
      Assert
        (M.Sixel_Scrolls_Right
         and then S.Cursor.Row = 2
         and then S.Cursor.Col = 5,
         "sixel right-scroll mode should move past the raster width");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 4, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "sixel newline initialize failed");
   Terminal.Core.Set_Cell_Pixel_Size (T, Width => 8, Height => 6);
   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "Pq?--" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "sixel newline feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Cursor.Row = 3,
         "sixel cursor movement must use the rendered raster height");
      Terminal.Core.Release (S);
   end;

end Core_Sixel_Cases;
