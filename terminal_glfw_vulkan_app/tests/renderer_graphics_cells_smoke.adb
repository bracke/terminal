with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.App.Render_Model;
with Terminal.App.Renderer;
with Terminal.App.Renderer.Testing;

procedure Renderer_Graphics_Cells_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.App.Render_Model.Image_Data_View;
   use type Terminal.App.Render_Model.Rectangle_Layer;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   R : Terminal.App.Renderer.Renderer;
   Status : Terminal.App.Renderer.Init_Status;
   T : Terminal.Core.Terminal;
   Core_Status : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   procedure Render_And_Complete_Graphics
     (Target : in out Terminal.Core.Terminal)
   is
      Rendered : Boolean := False;
   begin
      loop
         declare
            Event : Terminal.Core.Graphics_Event;
         begin
            Terminal.Core.Peek_Graphics_Event (Target, Event);
            exit when not Event.Pending;
            declare
               Snap : Terminal.Core.Render_Snapshot :=
                 Terminal.Core.Snapshot (Target);
               Result : Terminal.Core.Kitty_Graphics_Result;
            begin
               Snap.Graphics := Event;
               Terminal.App.Renderer.Render (R, Snap, Render_Status);
               Result := Terminal.App.Renderer.Graphics_Result (R, Event);
               Terminal.Core.Release (Snap);
               Terminal.Core.Complete_Graphics_Event (Target, Event, Result);
               Terminal.App.Renderer.Commit_Graphics_Events (R);
               Rendered := True;
            end;
            exit when Render_Status /= Terminal.App.Renderer.Ok;
         end;
      end loop;
      if not Rendered then
         declare
            Snap : Terminal.Core.Render_Snapshot :=
              Terminal.Core.Snapshot (Target);
         begin
            Terminal.App.Renderer.Render (R, Snap, Render_Status);
            Terminal.Core.Release (Snap);
         end;
      end if;
   end Render_And_Complete_Graphics;

   procedure Assert_Close
     (Actual : Float; Expected : Float; Message : String)
   is
   begin
      Assert (abs (Actual - Expected) < 0.001, Message);
   end Assert_Close;
begin
   Terminal.App.Renderer.Initialize_Headless (R, Status);
   Assert (Status = Terminal.App.Renderer.Ok, "renderer initialize failed");
   Terminal.Core.Initialize (T, 1, 1, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "core initialize failed");

   Render_And_Complete_Graphics (T);
   Assert (Render_Status = Terminal.App.Renderer.Ok, "render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert (Frame.Rectangle_Count >= 3, "expected background, cell, cursor");
      Assert
        (Frame.Width =
           Terminal.App.Renderer.Cell_Width (R)
           + Terminal.App.Renderer.Content_Margin * 2,
         "frame width should include horizontal content margins");
      Assert
        (Frame.Height =
           Terminal.App.Renderer.Cell_Height (R)
           + Terminal.App.Renderer.Content_Margin * 2,
         "frame height should include vertical content margins");
      Assert
        (Frame.Rectangles (2).X = Float (Terminal.App.Renderer.Content_Margin),
         "first cell should be inset horizontally");
      Assert
        (Frame.Rectangles (2).Y = Float (Terminal.App.Renderer.Content_Margin),
         "first cell should be inset vertically");
      Assert
        (Frame.Rectangles (1).Layer =
           Terminal.App.Render_Model.Rectangle_Base_Background
         and then Frame.Rectangles (2).Layer =
           Terminal.App.Render_Model.Rectangle_Base_Background
         and then Frame.Rectangles (3).Layer =
           Terminal.App.Render_Model.Rectangle_Foreground,
         "default background and cursor rectangle layers");
      Assert
        (Frame.Rectangles (3).Height <= Float (Terminal.App.Renderer.Cell_Height (R)),
         "cursor block should fit within the terminal cell");
   end;

   Terminal.Core.Initialize (T, 1, 2, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "image placeholder renderer initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => 16#1B#, 2 => Byte (Character'Pos ('[')),
       3 => Byte (Character'Pos ('3')), 4 => Byte (Character'Pos ('8')),
       5 => Byte (Character'Pos (';')), 6 => Byte (Character'Pos ('5')),
       7 => Byte (Character'Pos (';')), 8 => Byte (Character'Pos ('4')),
       9 => Byte (Character'Pos ('2')), 10 => Byte (Character'Pos ('m')),
       11 => 16#F4#, 12 => 16#8E#, 13 => 16#BB#, 14 => 16#AE#),
      Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok,
      "image placeholder renderer feed failed");
   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (Snap, 1, 1).Image.Is_Placeholder,
         "renderer input should expose image-cell metadata");
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "image placeholder renderer render failed");
   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert
        (Frame.Glyph_Count = 0 and then Frame.Text_Run_Count = 0,
         "unresolved image placeholder must not render a missing glyph");
   end;

   Terminal.Core.Initialize (T, 1, 2, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "virtual kitty placement renderer initialize failed");
   declare
      Placeholder : constant String :=
        Character'Val (16#F4#) & Character'Val (16#8E#)
        & Character'Val (16#BB#) & Character'Val (16#AE#);
      Row_Zero : constant String :=
        Character'Val (16#CC#) & Character'Val (16#85#);
      Col_One : constant String :=
        Character'Val (16#CC#) & Character'Val (16#8D#);
      Input : constant String :=
        ASCII.ESC & "_Gf=32,s=2,v=1,a=T,i=42,p=7,U=1,c=2,r=1;"
        & "/wAA/wD/AP8=" & ASCII.ESC & "\"
        & ASCII.ESC & "[38;5;42;58;5;7m"
        & Placeholder & Row_Zero & Row_Zero
        & Placeholder & Row_Zero & Col_One;
   begin
      Terminal.Core.Feed (T, To_Bytes (Input), Feed_Status);
   end;
   Assert
     (Feed_Status = Terminal.Core.Ok,
      "virtual kitty placement renderer feed failed");
   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Event : constant Terminal.Core.Graphics_Event := Snap.Graphics;
      Result : Terminal.Core.Kitty_Graphics_Result;
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Result := Terminal.App.Renderer.Graphics_Result (R, Event);
      Terminal.Core.Release (Snap);
      Terminal.Core.Complete_Graphics_Event (T, Event, Result);
      Terminal.App.Renderer.Commit_Graphics_Events (R);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "virtual kitty placement renderer render failed");
   Render_And_Complete_Graphics (T);
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "virtual kitty placeholder renderer render failed");
   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert
        (Frame.Image_Count = 2,
         "virtual placement should emit one image tile per placeholder cell");
      Assert
        (Frame.Glyph_Count = 0 and then Frame.Text_Run_Count = 0,
         "resolved image placeholders must remain outside text rendering");
      Assert_Close (Frame.Images (1).U0, 0.0, "first tile U0");
      Assert_Close (Frame.Images (1).U1, 0.5, "first tile U1");
      Assert_Close (Frame.Images (2).U0, 0.5, "second tile U0");
      Assert_Close (Frame.Images (2).U1, 1.0, "second tile U1");
      Assert_Close (Frame.Images (1).V0, 0.0, "first tile V0");
      Assert_Close (Frame.Images (1).V1, 1.0, "first tile V1");
      Assert
        (Frame.Images (1).Width =
           Float (Terminal.App.Renderer.Cell_Width (R))
         and then Frame.Images (2).Width =
           Float (Terminal.App.Renderer.Cell_Width (R)),
         "virtual placement tiles should occupy individual cells");
   end;
   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Snap.Graphics := (others => <>);
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "retained virtual kitty placement render failed");
   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert
        (Frame.Image_Count = 2,
         "virtual placement should outlive its transmission event");
   end;

   declare
      Palette_T : Terminal.Core.Terminal;
      Palette_Init : Terminal.Core.Initialize_Status;
      Palette_Feed : Terminal.Core.Feed_Status;
      procedure Feed_And_Render (Text : String; Label_Text : String) is
         Event : Terminal.Core.Graphics_Event;
         Snap : Terminal.Core.Render_Snapshot;
      begin
         Terminal.Core.Feed (Palette_T, To_Bytes (Text), Palette_Feed);
         Assert (Palette_Feed = Terminal.Core.Ok, Label_Text & " feed");
         Terminal.Core.Peek_Graphics_Event (Palette_T, Event);
         Assert (Event.Pending, Label_Text & " event");
         Snap := Terminal.Core.Snapshot (Palette_T);
         Snap.Graphics := Event;
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
         Terminal.Core.Discard_Graphics_Event (Palette_T);
         Assert (Render_Status = Terminal.App.Renderer.Ok, Label_Text & " render");
      end Feed_And_Render;
   begin
      Terminal.Core.Initialize (Palette_T, 2, 10, 100, Palette_Init);
      Assert
        (Palette_Init = Terminal.Core.Ok,
         "shared sixel palette terminal initialize");
      Terminal.Core.Set_Graphics_Stream_ID (Palette_T, 3_100);
      Feed_And_Render
        (ASCII.ESC & "[?1070l"
         & ASCII.ESC & "Pq#5;2;100;0;0~" & ASCII.ESC & "\",
         "shared sixel palette definition");
      Feed_And_Render
        (ASCII.ESC & "Pq#5~" & ASCII.ESC & "\",
         "shared sixel palette reuse");
      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Frame.Image_Count = 2
            and then Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Decoded_Bytes (1) = 16#FF#
            and then Frame.Images (1).Decoded_Bytes (2) = 0
            and then Frame.Images (1).Decoded_Bytes (3) = 0,
            "shared sixel palette should affect subsequent graphics");
      end;
      Feed_And_Render
        (ASCII.ESC & "[?1070h"
         & ASCII.ESC & "Pq#5~" & ASCII.ESC & "\",
         "private sixel palette reset");
      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Frame.Image_Count >= 1
            and then Frame.Images (1).Decoded_Bytes (1) = 16#FF#
            and then Frame.Images (1).Decoded_Bytes (2) = 16#FF#
            and then Frame.Images (1).Decoded_Bytes (3) = 16#FF#,
            "private sixel palettes should not inherit shared registers");
      end;
      Terminal.App.Renderer.Release_Graphics_Stream (R, 3_100);
      Terminal.Core.Finalize (Palette_T);
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "_Ga=d,d=A;" & ASCII.ESC & "\"),
      Feed_Status);
   Render_And_Complete_Graphics (T);
   Assert
     (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 2,
      "screen-wide deletion must preserve virtual placement prototypes");

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "_Ga=d,d=Z,z=0;" & ASCII.ESC & "\"),
      Feed_Status);
   Render_And_Complete_Graphics (T);
   Assert
     (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 2,
      "z-index deletion must preserve virtual placement prototypes");

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "_Ga=d,d=i,i=42,p=7;" & ASCII.ESC & "\"),
      Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok,
      "soft virtual placement delete feed failed");
   Render_And_Complete_Graphics (T);
   Assert
     (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 0,
      "lowercase delete should remove the virtual placement");

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "_Ga=p,i=42,p=7,U=1,c=2,r=1;" & ASCII.ESC & "\"),
      Feed_Status);
   Render_And_Complete_Graphics (T);
   Assert
     (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 2,
      "lowercase delete should retain reusable image data");

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "_Ga=d,d=I,i=42,p=7;" & ASCII.ESC & "\"),
      Feed_Status);
   Render_And_Complete_Graphics (T);
   Assert
     (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 0,
      "uppercase delete should remove the placement and image data");

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "_Ga=p,i=42,p=7,U=1,c=2,r=1;" & ASCII.ESC & "\"),
      Feed_Status);
   Render_And_Complete_Graphics (T);
   Assert
     (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 0,
      "uppercase delete should prevent image-data reuse");
   Terminal.Core.Finalize (T);
   Terminal.App.Renderer.Finalize (R);
end Renderer_Graphics_Cells_Smoke;
