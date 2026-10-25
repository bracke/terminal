with Ada.Text_IO;
with AUnit.Assertions;
with Interfaces;
with System;
with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.App.Hyperlinks;
with Terminal.App.Image_Media;
with Terminal.App.Render_Model;
with Terminal.App.Renderer;
with Terminal.App.Renderer.Testing;
with Terminal.App.Scrollback_View;
with Terminal.App.Splits;
with Terminal.App.Tabs;

procedure Renderer_Metrics_Smoke is
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Graphics_Resource_Limits;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.App.Image_Media.Decode_Status;
   use type Terminal.App.Render_Model.Image_Decode_Status;
   use type Terminal.App.Render_Model.Image_Decoded_Source_Kind;
   use type Terminal.App.Render_Model.Image_Data_Access;
   use type Terminal.App.Render_Model.Image_Data_View;
   use type Terminal.App.Render_Model.Image_Protocol;
   use type Terminal.App.Render_Model.Rectangle_Layer;
   use type Terminal.App.Render_Model.Text_Run_Direction;
   use type Terminal.App.Render_Model.Text_Run_Kind;
   use type Terminal.App.Render_Model.Text_Run_Script;
   use type Terminal.App.Render_Model.Text_Run_Shape_Status;
   use type System.Address;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use type Terminal.Core.Feed_Status;


   use type Terminal.Core.Graphics_ID;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Kitty_Graphics_Result_Code;
   use type Terminal.App.Splits.Split_Status;
   use type Terminal.App.Tabs.Tab_Status;

   --  AUnit's Assert outside a test case raises with no word of what
   --  failed; say it on standard error first, so a CI log names the check.
   procedure Assert (Condition : Boolean; Message : String);

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "FAILED: " & Message);
         AUnit.Assertions.Assert (False, Message);
      end if;
   end Assert;

   R      : Terminal.App.Renderer.Renderer;
   Status : Terminal.App.Renderer.Init_Status;
   T      : Terminal.Core.Terminal;
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

   function Trimmed_Natural (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Trimmed_Natural;

   function Bounded_Image_Label (Text : String) return String is
     (if Text'Length <= Terminal.App.Renderer.Max_Status_Label_Length
      then Text
      else Text
        (Text'First
         .. Text'First + Terminal.App.Renderer.Max_Status_Label_Length - 1));

   function Repeat_Char (Ch : Character; Count : Natural) return String is
      Result : String (1 .. Count);
   begin
      for I in Result'Range loop
         Result (I) := Ch;
      end loop;
      return Result;
   end Repeat_Char;

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
     (Actual  : Float;
      Expected : Float;
      Message  : String)
   is
      Diff : constant Float := abs (Actual - Expected);
   begin
      Assert (Diff < 0.001, Message);
   end Assert_Close;
begin
   Terminal.App.Renderer.Initialize_Headless (R, Status);
   Assert (Status = Terminal.App.Renderer.Ok, "renderer initialize failed");
   Assert
     (Terminal.App.Renderer.Cell_Height (R) >= 16,
      "cell height should keep at least the requested pixel size");
   Assert
     (Terminal.App.Renderer.Cell_Width (R) > 8,
      "cell width should include measured glyph advance and breathing room");


   Terminal.Core.Initialize (T, 1, 32, 100, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "hyperlink overlay initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "]8;id=abc;https://example.test" & ASCII.ESC & "\"
         & "x"
         & ASCII.ESC & "]8;;" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "hyperlink overlay feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Link : constant Terminal.Core.Hyperlink :=
        Terminal.App.Hyperlinks.Link_At (Snap, (Row => 1, Col => 1));
   begin
      Terminal.App.Renderer.Set_Hovered_Link (R, (others => <>));
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "plain hyperlink render failed");

      declare
         Plain_Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Terminal.App.Renderer.Set_Hovered_Link (R, Link);
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Assert
           (Render_Status = Terminal.App.Renderer.Ok,
            "hovered hyperlink render failed");

         declare
            Hover_Frame : constant Terminal.App.Render_Model.Frame_Commands :=
              Terminal.App.Renderer.Testing.Last_Frame (R);
         begin
            Assert (Link.Active, "hovered link should be active");
            Assert
              (Hover_Frame.Rectangle_Count >= Plain_Frame.Rectangle_Count + 2,
               "hovered link should add underline and status background rectangles");
            Assert
              (Hover_Frame.Glyph_Count > Plain_Frame.Glyph_Count,
               "hovered link should draw status label glyphs");
         end;
      end;

      Terminal.App.Renderer.Set_Hovered_Link (R, (others => <>));
      Terminal.Core.Release (Snap);
   end;

   Terminal.Core.Initialize (T, 1, 1, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "core reinitialize failed");

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "_Gf=32,a=T,C=1;AAAA" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "kitty graphics feed failed");

   Render_And_Complete_Graphics (T);
   Assert (Render_Status = Terminal.App.Renderer.Ok, "graphics render failed");

   declare
      Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert (Diagnostics.Last_Image_Count = 1, "graphics image diagnostic count");
      Assert
        (Diagnostics.Last_Image_Protocol = Terminal.App.Render_Model.Image_Kitty,
         "graphics image diagnostic protocol");
      Assert
        (Diagnostics.Last_Image_Width =
         Terminal.App.Renderer.Cell_Width (R) * 6,
         "graphics image diagnostic width");
      Assert
        (Diagnostics.Last_Image_Height =
         Terminal.App.Renderer.Cell_Height (R) * 3,
         "graphics image diagnostic height");
      Assert
        (Diagnostics.Last_Image_Payload_Length = 18,
         "graphics image diagnostic payload length");
      Assert
        (Diagnostics.Last_Image_Payload_Preview_Complete,
         "graphics image diagnostic payload preview complete");
      Assert
        (Diagnostics.Last_Image_Encoded_Preview_Length = 4,
         "graphics image diagnostic encoded preview length");
      Assert
        (Diagnostics.Last_Image_Decoded_Preview_Length = 3,
         "graphics image diagnostic decoded preview length");
      Assert
        (Diagnostics.Last_Image_Decoded_Preview_Bytes (1) = 0
         and then Diagnostics.Last_Image_Decoded_Preview_Bytes (2) = 0
         and then Diagnostics.Last_Image_Decoded_Preview_Bytes (3) = 0,
         "graphics image diagnostic decoded preview bytes");
      Assert
        (Diagnostics.Last_Image_Preview_Decode_Complete,
         "graphics image diagnostic preview decode complete");
      Assert
        (Diagnostics.Last_Image_Decode_Status =
         Terminal.App.Render_Model.Image_Decode_Ok,
         "graphics image diagnostic preview decode status");
      Assert
        (Diagnostics.Last_Image_Placeholder,
         "graphics image diagnostic placeholder flag");
      Assert (Frame.Image_Count = 1, "graphics image command count");
      Assert
        (Frame.Images (1).Protocol = Terminal.App.Render_Model.Image_Kitty,
         "graphics image protocol");
      Assert (Frame.Images (1).Payload_Length = 18, "graphics payload length");
      Assert
        (Frame.Images (1).Payload_Preview_Complete,
         "graphics payload preview complete");
      Assert
        (Frame.Images (1).Encoded_Preview_Length = 4,
         "graphics encoded preview length");
      Assert
        (Frame.Images (1).Decoded_Preview_Length = 3,
         "graphics decoded preview length");
      Assert
        (Frame.Images (1).Decoded_Preview_Bytes (1) = 0
         and then Frame.Images (1).Decoded_Preview_Bytes (2) = 0
         and then Frame.Images (1).Decoded_Preview_Bytes (3) = 0,
         "graphics decoded preview bytes");
      Assert
        (Frame.Images (1).Preview_Decode_Complete,
         "graphics preview decode complete");
      Assert
        (Frame.Images (1).Decode_Status =
         Terminal.App.Render_Model.Image_Decode_Ok,
         "graphics preview decode status");
      Assert
         (Terminal.App.Renderer.Image_Status_Label (Diagnostics) =
          Bounded_Image_Label
            ("image kitty size="
         & Trimmed_Natural (Terminal.App.Renderer.Cell_Width (R) * 6)
         & "x"
         & Trimmed_Natural (Terminal.App.Renderer.Cell_Height (R) * 3)
         & " payload=18 payload-complete preview=3/4 bytes=000000 placeholder decoded"),
         "graphics image diagnostic status label");
      Assert
        (Frame.Images (1).Width =
         Float (Terminal.App.Renderer.Cell_Width (R) * 6),
         "graphics placeholder parsed width");
      Assert
        (Frame.Images (1).Height =
         Float (Terminal.App.Renderer.Cell_Height (R) * 3),
         "graphics placeholder parsed height");
   end;

   declare
      Payload : constant String := "Gf=32,a=T,C=1,s=1,v=1,c=1,r=1;/wAA/w==";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "raw kitty graphics feed failed");

      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "raw graphics render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 1
            and then Diagnostics.Last_Image_Pixel_Height = 1,
            "raw graphics image diagnostic pixel metadata");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "raw graphics image should be textured");
         Assert
           (Frame.Images (1).Raw_Format = 32
            and then Frame.Images (1).Pixel_Width = 1
            and then Frame.Images (1).Pixel_Height = 1,
            "raw graphics command pixel metadata");
         Assert
           (Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Buffer
            and then Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Encoded_Source_Bytes = null,
            "anonymous transmit-and-display should retain decoded pixels");
         Assert
           (Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 0) = 16#FF#
            and then Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 3) = 16#FF#,
            "raw graphics retained row bytes");
         Assert
           (Frame.Images (1).Decoded_Row_Stride_Bytes = 4,
            "raw graphics command should carry decoded row stride");
         Assert
           (not Frame.Images (1).Placeholder,
            "raw graphics command should be textured");
         Assert
           (Terminal.App.Renderer.Image_Status_Label (Diagnostics) =
            Bounded_Image_Label
              ("image kitty size="
            & Trimmed_Natural
              (Natural'Min
                 (Terminal.App.Renderer.Cell_Width (R),
                  Terminal.App.Renderer.Cell_Height (R)))
            & "x"
            & Trimmed_Natural
              (Natural'Min
                 (Terminal.App.Renderer.Cell_Width (R),
                  Terminal.App.Renderer.Cell_Height (R)))
            & " pixels=1x1 format=32 payload=0"
            & " payload-complete preview=4/0 bytes=FF0000FF textured decoded"),
            "raw graphics image diagnostic status label");
      end;
   end;

   --  The anonymous a=T image is now a real persistent placement. Retire it
   --  before the independent explicit-ID object tests below.
   Terminal.App.Renderer.Release_Graphics_Stream (R, 0);
   Terminal.Core.Set_Graphics_Stream_ID (T, 4_100);

   declare
      Store_Payload : constant String :=
        "Gf=32,a=t,i=77,s=1,v=1,c=1,r=1;/wAA/w==";
      Place_Payload : constant String := "Gi=77,a=p,C=1,c=2,r=1;";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Store_Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "kitty object store feed failed");
      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "kitty object store render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
      begin
         Assert
           (Diagnostics.Last_Image_Count = 0,
            "kitty transmit-only command should not display");
         Assert
           (Diagnostics.Kitty_Image_Object_Count > 0,
            "kitty transmit-only command should store");
      end;

      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Place_Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "kitty object placement feed failed");
      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "kitty object placement render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 1
            and then Diagnostics.Last_Image_Pixel_Height = 1,
            "kitty object placement diagnostic pixel metadata");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "kitty object placement should be textured");
         Assert
           (Frame.Images (1).Width = Float
              (declare
                  CW : constant Natural := Terminal.App.Renderer.Cell_Width (R);
                  Draw : constant Natural := Natural'Min
                    (CW * 2, Terminal.App.Renderer.Cell_Height (R));
                  Offset : constant Natural := (CW * 2 - Draw) / 2;
               begin Natural'Min (Draw, CW - Natural'Min (Offset, CW)))
            and then Frame.Images (1).Height = Float
              (Natural'Min
                 (Terminal.App.Renderer.Cell_Height (R),
                  Natural'Min
                    (Terminal.App.Renderer.Cell_Width (R) * 2,
                     Terminal.App.Renderer.Cell_Height (R)))),
            "kitty object placement is aspect-fitted then viewport-clipped");
         Assert
           (Frame.Images (1).Raw_Format = 32
            and then Frame.Images (1).Pixel_Width = 1
            and then Frame.Images (1).Pixel_Height = 1
            and then Frame.Images (1).Decoded_Byte_Length = 4
            and then Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Decoded_Bytes (1) = 16#FF#
            and then Frame.Images (1).Decoded_Bytes (2) = 16#00#
            and then Frame.Images (1).Decoded_Bytes (3) = 16#00#
            and then Frame.Images (1).Decoded_Bytes (4) = 16#FF#,
            "kitty object placement decoded bytes");
         Assert
           (not Frame.Images (1).Placeholder,
            "kitty object placement command should be textured");
      end;
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "_Ga=d,d=i,i=77;" & ASCII.ESC & "\"),
      Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok,
      "kitty object placement cleanup feed failed");
   Render_And_Complete_Graphics (T);
   Assert
     (Render_Status = Terminal.App.Renderer.Ok
      and then Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
      "kitty object placement cleanup failed");

   for ID in 100 .. 120 loop
      declare
         Payload : constant String :=
           "Gf=32,a=t,i="
           & Trimmed_Natural (ID)
           & ",s=1,v=1,c=1,r=1;/wAA/w==";
      begin
         Terminal.Core.Feed
           (T,
            To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
            Feed_Status);
         Assert
           (Feed_Status = Terminal.Core.Ok,
            "unbounded kitty object feed failed");

         Render_And_Complete_Graphics (T);
         Assert
           (Render_Status = Terminal.App.Renderer.Ok,
            "unbounded kitty object render failed");
      end;
   end loop;

   declare
      Place_Payload : constant String := "Gi=100,a=p,C=1,c=3,r=1;";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Place_Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "unbounded kitty object placement feed failed");
      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "unbounded kitty object placement render failed");

      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Frame.Images (1).Width = Float
              (declare
                  CW : constant Natural := Terminal.App.Renderer.Cell_Width (R);
                  Draw : constant Natural := Natural'Min
                    (CW * 3, Terminal.App.Renderer.Cell_Height (R));
                  Offset : constant Natural := (CW * 3 - Draw) / 2;
               begin Natural'Min (Draw, CW - Natural'Min (Offset, CW)))
            and then Frame.Images (1).Height = Float
              (Natural'Min
                 (Terminal.App.Renderer.Cell_Width (R) * 3,
                  Terminal.App.Renderer.Cell_Height (R)))
            and then Frame.Images (1).Raw_Format = 32
            and then Frame.Images (1).Decoded_Byte_Length = 4
            and then Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Decoded_Bytes (1) = 16#FF#
            and then Frame.Images (1).Decoded_Bytes (4) = 16#FF#
            and then not Frame.Images (1).Placeholder,
            "unbounded kitty object placement should keep first stored id");
      end;
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "_Ga=d,d=I,i=100;" & ASCII.ESC & "\"),
      Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok,
      "kitty object delete feed failed");
   Render_And_Complete_Graphics (T);
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "kitty object delete render failed");
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
      "kitty object delete should not emit an image command");
   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "_Gi=100,a=p,C=1,c=1,r=1;" & ASCII.ESC & "\"),
      Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok,
      "deleted kitty object placement feed failed");
   Render_And_Complete_Graphics (T);
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "deleted kitty object placement render failed");
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
      "deleted kitty object placement should not create a drawable");

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "_Ga=d;" & ASCII.ESC & "\"),
      Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok,
      "kitty object delete-all feed failed");
   Render_And_Complete_Graphics (T);
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "kitty object delete-all render failed");
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
      "kitty object delete-all should not emit an image command");

   --  Transmit-once/place-many clients need cropped placements to survive
   --  consumption of the APC event and remain independently deletable.
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC
         & "_Gq=2,a=t,i=500,f=32,s=2,v=1;/wAA/wD/AP8="
         & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "kitty transmit-only feed failed");
   Render_And_Complete_Graphics (T);
   Assert
     (Render_Status = Terminal.App.Renderer.Ok
      and then Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
      "kitty transmit-only command must not create a placement");

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC
         & "_Gq=2,a=p,i=500,p=1,x=0,y=0,w=1,h=1,c=1,r=1,C=1;"
         & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "first cropped placement feed failed");
   Render_And_Complete_Graphics (T);
   Assert
     (Render_Status = Terminal.App.Renderer.Ok
      and then Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 1,
      "first cropped placement render failed");

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC
         & "_Gq=2,a=p,i=500,p=2,x=1,y=0,w=1,h=1,c=1,r=1,C=1;"
         & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "second cropped placement feed failed");
   Render_And_Complete_Graphics (T);
   Assert
     (Render_Status = Terminal.App.Renderer.Ok
      and then Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 2,
      "multiple conventional Kitty placements should coexist");
   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert_Close (Frame.Images (1).U0, 0.5, "second placement crop U0");
      Assert_Close (Frame.Images (1).U1, 1.0, "second placement crop U1");
      Assert_Close (Frame.Images (2).U0, 0.0, "first placement crop U0");
      Assert_Close (Frame.Images (2).U1, 0.5, "first placement crop U1");
   end;

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Snap.Graphics := (others => <>);
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok
      and then Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 2,
      "conventional Kitty placements should persist without a new event");

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "_Gq=2,a=d,d=i,i=500,p=1;" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "placement delete feed failed");
   Render_And_Complete_Graphics (T);
   Assert
     (Render_Status = Terminal.App.Renderer.Ok
      and then Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 1,
      "placement-ID delete should preserve sibling placements");

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "_Gq=2,a=d,d=I,i=500,p=2;" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "placement data delete feed failed");
   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok
      and then Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
      "last placement data delete should release the image object");

   for ID in 510 .. 511 loop
      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "_Gq=2,a=T,i=" & Trimmed_Natural (ID)
            & ",f=32,s=1,v=1,c=1,r=1,C=1;/wAA/w=="
            & ASCII.ESC & "\"),
         Feed_Status);
      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "range-delete setup image render failed");
   end loop;
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 2,
      "range-delete setup should retain both placements");

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "_Gq=2,a=d,d=r,x=510,y=510;" & ASCII.ESC & "\"),
      Feed_Status);
   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 1,
      "lowercase ID range should delete only matching placements");

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "_Gq=2,a=p,i=510,c=1,r=1,C=1;" & ASCII.ESC & "\"),
      Feed_Status);
   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 2,
      "lowercase ID range should retain reusable image data");

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "_Gq=2,a=d,d=R,x=510,y=511;" & ASCII.ESC & "\"),
      Feed_Status);
   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
      "uppercase ID range should remove placements and image data");

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "_Gq=2,a=p,i=510,c=1,r=1,C=1;" & ASCII.ESC & "\"),
      Feed_Status);
   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
      "uppercase ID range should make deleted data unavailable");

   declare
      First_ID  : Natural := 0;
      Second_ID : Natural := 0;
      Chunk_ID  : Natural := 0;

      procedure Consume_Frame is
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
         Assert
           (Render_Status = Terminal.App.Renderer.Ok,
            "image-number command render failed");
      end Consume_Frame;
   begin
      Terminal.Core.Initialize (T, 1, 8, 10, Core_Status);
      Assert
        (Core_Status = Terminal.Core.Ok,
         "image-number core initialize failed");

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC
            & "_Gq=2,a=T,I=77,p=1,f=32,s=1,v=1,c=1,r=1,C=1;/wAA/w=="
            & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Frame;
      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert (Frame.Image_Count = 1, "first numbered image placement");
         First_ID := Natural (Frame.Images (1).Image_ID);
         Assert (First_ID > 0, "numbered image should receive a nonzero ID");
      end;

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC
            & "_Gq=2,a=T,I=77,p=2,f=32,s=1,v=1,c=1,r=1,C=1;AP8A/w=="
            & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Frame;
      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Frame.Image_Count = 2,
            "same image number should create a second image object");
         for I in 1 .. Frame.Image_Count loop
            declare
               ID : constant Natural := Natural (Frame.Images (I).Image_ID);
            begin
               if ID /= First_ID then
                  Second_ID := ID;
               end if;
            end;
         end loop;
         Assert
           (Second_ID > 0 and then Second_ID /= First_ID,
            "reused image number should allocate a distinct ID");
      end;

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "_Gq=2,a=p,I=77,p=3,c=1,r=1,C=1;" & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Frame;
      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
         Newest_Count : Natural := 0;
      begin
         for I in 1 .. Frame.Image_Count loop
            if Natural (Frame.Images (I).Image_ID) = Second_ID then
               Newest_Count := Newest_Count + 1;
            end if;
         end loop;
         Assert
           (Frame.Image_Count = 3,
            "number lookup should add a third placement");
         Assert
           (Newest_Count = 2,
            "number lookup should place only the newest matching image");
      end;

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "_Gq=2,a=d,d=n,I=77,p=3;" & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Frame;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 2,
         "number delete with placement ID should preserve sibling placement");

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "_Gq=2,a=d,d=N,I=77;" & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Frame;
      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Frame.Image_Count = 1
            and then Natural (Frame.Images (1).Image_ID) = First_ID,
            "uppercase number delete should remove newest data only");
      end;

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "_Gq=2,a=p,I=77,p=4,c=1,r=1,C=1;" & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Frame;
      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Frame.Image_Count = 2
            and then Natural (Frame.Images (1).Image_ID) = First_ID
            and then Natural (Frame.Images (2).Image_ID) = First_ID,
            "number lookup should fall back to the newest remaining image");
      end;

      declare
         Objects_Before : constant Natural :=
           Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count;
      begin
         Terminal.Core.Feed
           (T,
            To_Bytes
              (ASCII.ESC
               & "_Gq=2,a=T,i=999,I=88,f=32,s=1,v=1,C=1;/wAA/w=="
               & ASCII.ESC & "\"),
            Feed_Status);
         Consume_Frame;
         Assert
           (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
              Objects_Before
            and then Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 2,
            "mixed image ID and number must not mutate graphics state");
      end;

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "_Gq=2,a=d,d=R,x=" & Trimmed_Natural (First_ID)
            & ",y=" & Trimmed_Natural (Second_ID) & ";" & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Frame;

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC
            & "_Gq=2,a=T,I=99,p=5,f=32,s=1,v=1,c=1,r=1,C=1,m=1;/wAA"
            & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Frame;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 0,
         "first numbered chunk must not allocate or display early");

      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_Gq=2,m=0;/w==" & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Frame;
      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Frame.Image_Count = 1,
            "final numbered chunk should install and place its image");
         Chunk_ID := Natural (Frame.Images (1).Image_ID);
         Assert (Chunk_ID > 0, "chunked numbered image should receive an ID");
      end;

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "_Gq=2,a=p,I=99,p=6,c=1,r=1,C=1;" & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Frame;
      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Frame.Image_Count = 2
            and then Natural (Frame.Images (1).Image_ID) = Chunk_ID
            and then Natural (Frame.Images (2).Image_ID) = Chunk_ID,
            "number lookup should resolve a completed chunked transmission");
      end;

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "_Gq=2,a=d,d=N,I=99;" & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Frame;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 0,
         "numbered chunk cleanup should remove placements and data");
   end;

   declare
      procedure Consume_Relative_Frame is
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
         Assert
           (Render_Status = Terminal.App.Renderer.Ok,
            "relative placement command render failed");
      end Consume_Relative_Frame;

      Root_X       : Float := 0.0;
      Child_X      : Float := 0.0;
      Grandchild_X : Float := 0.0;
      Objects_Before : constant Natural :=
        Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count;
   begin
      Terminal.Core.Initialize (T, 1, 8, 10, Core_Status);
      Assert
        (Core_Status = Terminal.Core.Ok,
         "relative placement core initialize failed");

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC
            & "_Gq=2,a=T,i=600,p=1,f=32,s=1,v=1,c=1,r=1,C=1;"
            & "/wAA/w==" & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Relative_Frame;

      for ID in 601 .. 602 loop
         Terminal.Core.Feed
           (T,
            To_Bytes
              (ASCII.ESC & "_Gq=2,a=t,i=" & Trimmed_Natural (ID)
               & ",f=32,s=1,v=1;/wAA/w==" & ASCII.ESC & "\"),
            Feed_Status);
         Consume_Relative_Frame;
      end loop;

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC
            & "_Gq=2,a=p,i=601,p=2,P=600,Q=1,H=2,V=0,c=1,r=1;"
            & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Relative_Frame;
      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC
            & "_Gq=2,a=p,i=602,p=3,P=601,Q=2,H=1,V=0,c=1,r=1;"
            & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Relative_Frame;

      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Frame.Image_Count = 3,
            "relative placement chain should retain three images");
         for I in 1 .. Frame.Image_Count loop
            case Natural (Frame.Images (I).Image_ID) is
               when 600 => Root_X := Frame.Images (I).X;
               when 601 => Child_X := Frame.Images (I).X;
               when 602 => Grandchild_X := Frame.Images (I).X;
               when others => null;
            end case;
         end loop;
         Assert_Close
           (Child_X,
            Root_X + 2.0 * Float (Terminal.App.Renderer.Cell_Width (R)),
            "relative child should use the parent cell origin");
         Assert_Close
           (Grandchild_X,
            Child_X + Float (Terminal.App.Renderer.Cell_Width (R)),
            "relative placement chains should accumulate offsets");
      end;

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC
            & "_Gq=2,a=p,i=600,p=1,P=602,Q=3,H=1,V=0,c=1,r=1;"
            & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Relative_Frame;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 3,
         "cycle-forming placement replacement must be rejected");

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC
            & "_Gq=2,a=p,i=600,p=1,P=999,Q=1,H=1,V=0,c=1,r=1;"
            & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Relative_Frame;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 3,
         "placement with a missing parent must be rejected");

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "_Gq=2,a=d,d=i,i=600,p=1;" & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Relative_Frame;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 0
         and then
           Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
             Objects_Before + 3,
         "soft parent deletion cascades placements but retains reusable data");

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "_Gq=2,a=p,i=601,p=4,c=1,r=1,C=1;"
            & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Relative_Frame;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1,
         "cascaded child image data remains reusable after soft deletion");

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "_Gq=2,a=d,d=i,i=601,p=4;"
            & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Relative_Frame;

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "_Gq=2,a=d,d=I,i=600;" & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Relative_Frame;

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC
            & "_Gq=2,a=T,i=610,p=1,f=32,s=1,v=1,c=1,r=1,C=1;"
            & "/wAA/w==" & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Relative_Frame;
      for Placement_ID in 2 .. 9 loop
         Terminal.Core.Feed
           (T,
            To_Bytes
              (ASCII.ESC & "_Gq=2,a=p,i=610,p="
               & Trimmed_Natural (Placement_ID) & ",P=610,Q="
               & Trimmed_Natural (Placement_ID - 1)
               & ",H=0,V=0,c=1,r=1;" & ASCII.ESC & "\"),
            Feed_Status);
         Consume_Relative_Frame;
      end loop;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 9,
         "relative placement depth eight must be accepted");

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "_Gq=2,a=d,d=i,i=610,p=1;" & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Relative_Frame;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 0
         and then
           Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
             Objects_Before + 3,
         "soft relative chain deletion retains reusable image data");

      --  Soft deletion deliberately leaves all three transmitted image
      --  objects reusable.  Remove this test's objects explicitly so the
      --  following independent quota checks retain their original baseline.
      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "_Gq=2,a=d,d=R,x=600,y=610;"
            & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Relative_Frame;
   end;

   declare
      Placeholder : constant String :=
        Character'Val (16#F4#) & Character'Val (16#8E#)
        & Character'Val (16#BB#) & Character'Val (16#AE#);
      Row_Zero : constant String :=
        Character'Val (16#CC#) & Character'Val (16#85#);
      Objects_Before : constant Natural :=
        Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count;

      procedure Consume_Virtual_Parent_Frame is
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
         Assert
           (Render_Status = Terminal.App.Renderer.Ok,
            "virtual-parent relative placement render failed");
      end Consume_Virtual_Parent_Frame;
   begin
      Terminal.Core.Initialize (T, 1, 8, 10, Core_Status);
      Assert
        (Core_Status = Terminal.Core.Ok,
         "virtual-parent relative placement initialize failed");
      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC
            & "_Gq=2,a=T,i=42,p=7,U=1,f=32,s=1,v=1,c=1,r=1;"
            & "/wAA/w==" & ASCII.ESC & "\"
            & ASCII.ESC & "[38;5;42;58;5;7m"
            & Placeholder & Row_Zero & Row_Zero),
         Feed_Status);
      Consume_Virtual_Parent_Frame;

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "_Gq=2,a=t,i=611,f=32,s=1,v=1;/wAA/w=="
            & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Virtual_Parent_Frame;
      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC
            & "_Gq=2,a=p,i=611,p=1,P=42,Q=7,H=2,V=0,c=1,r=1;"
            & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Virtual_Parent_Frame;
      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
         Child_X : Float := 0.0;
      begin
         Assert
           (Frame.Image_Count = 2,
            "virtual parent and relative child should both render");
         for I in 1 .. Frame.Image_Count loop
            if Natural (Frame.Images (I).Image_ID) = 611 then
               Child_X := Frame.Images (I).X;
            end if;
         end loop;
         Assert_Close
           (Child_X,
            Float
              (Terminal.App.Renderer.Content_Margin
               + 2 * Terminal.App.Renderer.Cell_Width (R)),
            "relative child should use minimum virtual-placeholder origin");
      end;

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "_Gq=2,a=d,d=i,i=42,p=7;" & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Virtual_Parent_Frame;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 0
         and then
           Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
             Objects_Before + 2,
         "soft virtual-parent deletion cascades placements but retains data");

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "_Gq=2,a=d,d=I,i=42;" & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Virtual_Parent_Frame;
      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "_Gq=2,a=d,d=I,i=611;" & ASCII.ESC & "\"),
         Feed_Status);
      Consume_Virtual_Parent_Frame;
   end;

   Terminal.Core.Initialize (T, 1, 1, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "post image-number core restore failed");

   declare
      Objects_Before : constant Natural :=
        Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count;
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC
            & "_Gq=2,a=f,i=501,f=32,s=1,v=1;/wAA/w=="
            & ASCII.ESC & "\"),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "animation frame feed failed");
      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok
         and then Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0
         and then
           Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
             Objects_Before,
         "animation frame for a missing base image must not mutate the store");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "_Ga=t,i=502,f=32,s=1,v=1;/wAA/w=="
         & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "coordinate-delete setup feed failed");
   Render_And_Complete_Graphics (T);
   Assert
     (Render_Status = Terminal.App.Renderer.Ok
      and then Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
      "coordinate-delete transmit should remain hidden");
   --  Verify that cell+z deletion matches only the requested layer.
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "_Ga=p,i=502,p=9,c=1,r=1,z=5,C=1;"
         & ASCII.ESC & "\"),
      Feed_Status);
   Render_And_Complete_Graphics (T);
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 1,
      "coordinate-delete setup placement failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "_Ga=d,d=q,x=1,y=1,z=4;" & ASCII.ESC & "\"),
      Feed_Status);
   Render_And_Complete_Graphics (T);
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 1,
      "coordinate delete with another z-index must preserve placement");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "_Ga=d,d=Q,x=1,y=1,z=5;" & ASCII.ESC & "\"),
      Feed_Status);
   Render_And_Complete_Graphics (T);
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
      "coordinate and z-index delete should remove matching placement");

   declare
      Payload : constant String := "Gf=24,a=T,C=1,s=1,v=1,c=1,r=1;/wAA";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "raw RGB kitty graphics feed failed");
      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "raw RGB graphics render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Raw_Format = 24
            and then Diagnostics.Last_Image_Pixel_Width = 1
            and then Diagnostics.Last_Image_Pixel_Height = 1,
            "raw RGB graphics image diagnostic pixel metadata");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "raw RGB graphics image should be textured");
         Assert
           (Frame.Images (1).Raw_Format = 24
            and then Frame.Images (1).Decoded_Byte_Length = 3
            and then Frame.Images (1).Decoded_Row_Stride_Bytes = 3
            and then Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Buffer
            and then Frame.Images (1).Encoded_Source_Bytes = null,
            "raw RGB graphics command retained source metadata");
         Assert
           (Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 0) = 16#FF#
            and then Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 1) = 16#00#
            and then Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 2) = 16#00#,
            "raw RGB graphics encoded row source bytes");
         Assert
           (not Frame.Images (1).Placeholder,
            "raw RGB graphics command should be textured");
      end;
   end;

   Terminal.App.Renderer.Release_Graphics_Stream (R, 4_100);
   Terminal.Core.Set_Graphics_Stream_ID (T, 4_101);

   declare
      First_Chunk  : constant String := "Gf=32,a=T,C=1,s=2,v=1,c=2,r=1,m=1;/wAA";
      Middle_Chunk : constant String := "Gm=1;/wAA";
      Last_Chunk   : constant String := "Gm=0;//8=";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & First_Chunk & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "chunked raw kitty first chunk feed failed");

      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "chunked raw kitty first render failed");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
         "chunked raw kitty first chunk should wait for final chunk");

      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Middle_Chunk & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "chunked raw kitty middle chunk feed failed");

      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "chunked raw kitty middle render failed");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
         "chunked raw kitty middle chunk should wait for final chunk");

      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Last_Chunk & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "chunked raw kitty final chunk feed failed");

      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "chunked raw kitty final render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 2
            and then Diagnostics.Last_Image_Pixel_Height = 1,
            "chunked raw kitty image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Length = 8,
            "chunked raw kitty decoded byte length");
         Assert
         (Diagnostics.Last_Image_Decoded_Preview_Bytes (1) = 16#FF#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (2) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (3) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (4) = 16#FF#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (5) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (6) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (7) = 16#FF#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (8) = 16#FF#,
            "chunked raw kitty decoded bytes");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "chunked raw kitty image should be textured");
         Assert
           (Frame.Images (1).Pixel_Width = 2
            and then Frame.Images (1).Pixel_Height = 1
            and then Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Buffer
            and then Frame.Images (1).Encoded_Source_Bytes = null,
            "chunked raw kitty command retained source metadata");
         Assert
           (Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 0) = 16#FF#
            and then Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 7) = 16#FF#,
            "chunked raw kitty encoded row source bytes");
         Assert
           (not Frame.Images (1).Placeholder,
            "chunked raw kitty command should be textured");
      end;
   end;

   declare
      Chunk_T : Terminal.Core.Terminal;
      Chunk_Init : Terminal.Core.Initialize_Status;
      Chunk_Feed : Terminal.Core.Feed_Status;
      Event : Terminal.Core.Graphics_Event;
      Result : Terminal.Core.Kitty_Graphics_Result;
      Tabs : Terminal.App.Tabs.Tab_State;
      Splits : Terminal.App.Splits.Split_State;
      Objects_Before : constant Natural :=
        Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count;

      procedure Feed_Render
        (Text : String;
         Expected : Terminal.Core.Kitty_Graphics_Result_Code;
         Message : String)
      is
         --  Keep each protocol exchange isolated for source-level failure
         --  diagnostics.
         Snapshots : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
      begin
         Terminal.Core.Feed
           (Chunk_T,
            To_Bytes (ASCII.ESC & "_" & Text & ASCII.ESC & "\"),
            Chunk_Feed);
         Assert (Chunk_Feed = Terminal.Core.Ok, Message & " feed");
         Terminal.Core.Peek_Graphics_Event (Chunk_T, Event);
         if not Event.Pending then
            Assert
              (Expected = Terminal.Core.Kitty_No_Response,
               Message & " incomplete transaction result");
            return;
         end if;
         Snapshots (1) := Terminal.Core.Snapshot (Chunk_T);
         Snapshots (1).Graphics := Event;
         Terminal.App.Renderer.Render_App
           (R,
            Snapshots,
            1,
            Terminal.App.Tabs.Snapshot (Tabs),
            Terminal.App.Splits.Snapshot (Splits),
            Render_Status);
         Terminal.Core.Release (Snapshots (1));
         Assert (Render_Status = Terminal.App.Renderer.Ok, Message & " render");
         Result := Terminal.App.Renderer.Graphics_Result (R, Event);
         Assert (Result.Code = Expected, Message & " protocol result");
         Terminal.Core.Complete_Graphics_Event (Chunk_T, Event, Result);
         Terminal.App.Renderer.Commit_Graphics_Events (R);
      end Feed_Render;
   begin
      Terminal.Core.Initialize (Chunk_T, 2, 4, 10, Chunk_Init);
      Assert (Chunk_Init = Terminal.Core.Ok, "chunk validation initialize");
      Terminal.Core.Set_Graphics_Stream_ID (Chunk_T, 3_001);
      Terminal.App.Tabs.Initialize (Tabs);
      Terminal.App.Splits.Initialize (Splits);

      Feed_Render
        ("Gq=2,a=t,i=90,f=32,s=1,v=1,m=1;AAA",
         Terminal.Core.Kitty_EINVAL,
         "non-final chunk alignment rejection");
      Feed_Render
        ("Gq=2,a=t,i=91,f=32,s=1,v=1,m=1;"
         & Repeat_Char ('A', 4_097),
         Terminal.Core.Kitty_EINVAL,
         "oversized chunk rejection");
      Feed_Render
        ("Gq=2,a=t,i=91,f=32,s=1,v=1,m=2;AAAA",
         Terminal.Core.Kitty_EINVAL,
         "invalid chunk flag rejection");

      Feed_Render
        ("Gq=2,a=t,i=92,f=32,s=1,v=1,m=1;AAAA",
         Terminal.Core.Kitty_No_Response,
         "valid first chunk retention");
      Feed_Render
        ("Gm=0,i=92;AA==",
         Terminal.Core.Kitty_EINVAL,
         "continuation control rejection");

      Feed_Render
        ("Gq=2,a=t,i=94,f=32,s=1,v=1,m=1;/wAA",
         Terminal.Core.Kitty_No_Response,
         "delete-cancel first chunk retention");
      Feed_Render
        ("Gq=2,a=d,d=i,i=94",
         Terminal.Core.Kitty_OK,
         "delete command aborts partial upload");
      Feed_Render
        ("Gq=2,a=t,i=94,f=32,s=1,v=1,m=1;/wAA",
         Terminal.Core.Kitty_No_Response,
         "fresh chunk after delete cancellation");
      Feed_Render
        ("Gq=2,m=0;/w==",
         Terminal.Core.Kitty_OK,
         "completed chunk after delete cancellation");

      Feed_Render
        ("Gq=2,a=t,i=92,f=32,s=1,v=1;/wAA/w==",
         Terminal.Core.Kitty_OK,
         "post-rejection transaction recovery");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
           Objects_Before + 2,
         "valid transfer succeeds after malformed chunks");

      Feed_Render
        ("Gq=2,a=t,i=180,i=181,f=32,s=1,v=1;/wAA/w==",
         Terminal.Core.Kitty_EINVAL,
         "duplicate control rejection");
      Feed_Render
        ("Gq=2,a=t,i=182,f=32,s=bad,v=1;/wAA/w==",
         Terminal.Core.Kitty_EINVAL,
         "malformed numeric control rejection");
      Feed_Render
        ("Gq=2,a=p,i=92;AAAA",
         Terminal.Core.Kitty_EINVAL,
         "put action payload rejection");
      Feed_Render
        ("Gq=2,a=t,i=183,f=32,s=1,v=1",
         Terminal.Core.Kitty_EINVAL,
         "transmit action missing payload rejection");
      Feed_Render
        ("Gq=2,a=x,i=184",
         Terminal.Core.Kitty_ENOTSUP,
         "unsupported action rejection");

      Feed_Render
        ("Ga=q,i=200,f=32,s=1,v=1;/wAA/w==",
         Terminal.Core.Kitty_OK,
         "query validates direct raw payload");
      Feed_Render
        ("Ga=q,i=201,f=32,s=1,v=1;%%%%",
         Terminal.Core.Kitty_EINVAL,
         "query rejects invalid direct payload");
      Feed_Render
        ("Ga=q,i=202,f=32,s=1,v=1,o=z;eJz7z8DwHwAE/wH/",
         Terminal.Core.Kitty_OK,
         "query validates compressed direct payload");
      Feed_Render
        ("Ga=q,i=204,f=100,o=z;"
         & "eJzrDPBz5+WS4mJgYOD19HAJAtKMIMzBBCQnlAff"
         & "A0u4OIZUzEn+cf4AAwMzIyPDSYZjUx4BJRg8Xf1c1jklNAEA1dYQSw==",
         Terminal.Core.Kitty_EINVAL,
         "direct compressed PNG query requires inflated size");
      Feed_Render
        ("Ga=q,i=203,f=32,s=1,v=1,t=x;/wAA/w==",
         Terminal.Core.Kitty_ENOTSUP,
         "query rejects unsupported transfer medium");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
           Objects_Before + 2,
         "query validation must not retain image objects");

      Feed_Render
        ("Gq=2,a=T,i=95,f=32,s=1,v=1,c=1,r=1,C=1,o=z;"
         & "eJz7z8DwHwAE/wH/",
         Terminal.Core.Kitty_OK,
         "zlib raw direct transfer");
      Feed_Render
        ("Gq=2,a=T,i=96,f=100,S=70,c=1,r=1,C=1,o=z;"
         & "eJzrDPBz5+WS4mJgYOD19HAJAtKMIMzBBCQnlAff"
         & "A0u4OIZUzEn+cf4AAwMzIyPDSYZjUx4BJRg8Xf1c1jklNAEA1dYQSw==",
         Terminal.Core.Kitty_OK,
         "zlib PNG direct transfer");
      Feed_Render
        ("Gq=2,a=T,i=97,f=32,s=1,v=1,c=1,r=1,C=1,o=z,m=1;"
         & "eJz7z8Dw",
         Terminal.Core.Kitty_No_Response,
         "zlib raw first chunk");
      Feed_Render
        ("Gq=2,m=0;HwAE/wH/",
         Terminal.Core.Kitty_OK,
         "zlib raw final chunk");
      Feed_Render
        ("Gq=2,a=T,i=98,f=32,s=1,v=1,c=1,r=1,C=1,o=z;"
         & "eJz7z8DwHwAE/wHA",
         Terminal.Core.Kitty_EINVAL,
         "zlib checksum rejection");
      Feed_Render
        ("Gq=2,a=T,i=99,f=100,c=1,r=1,C=1,o=z;"
         & "eJzrDPBz5+WS4mJgYOD19HAJAtKMIMzBBCQnlAff"
         & "A0u4OIZUzEn+cf4AAwMzIyPDSYZjUx4BJRg8Xf1c1jklNAEA1dYQSw==",
         Terminal.Core.Kitty_EINVAL,
         "zlib PNG size requirement");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
           Objects_Before + 5,
         "zlib transfers install only validated image objects");
      Feed_Render
        ("Gq=2,a=T,f=32,s=1,v=1,c=1,r=1,C=1,o=z;"
         & "eJz7z8DwHwAE/wH/",
         Terminal.Core.Kitty_OK,
         "anonymous zlib raw display");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
           Objects_Before + 6,
         "anonymous zlib display retains an anonymous image object");

      Feed_Render
        ("Gq=2,a=t,i=110,f=32,s=2,v=1;/wAA/wD/AP8=",
         Terminal.Core.Kitty_OK,
         "geometry source transmission");
      Feed_Render
        ("Gq=2,a=p,i=110,p=10,C=1",
         Terminal.Core.Kitty_OK,
         "natural geometry placement");
      Feed_Render
        ("Gq=2,a=p,i=110,p=11,c=2,C=1",
         Terminal.Core.Kitty_OK,
         "one-sided geometry placement");
      Feed_Render
        ("Gq=2,a=p,i=110,p=12,c=2,r=2,C=1",
         Terminal.Core.Kitty_OK,
         "letterboxed geometry placement");
      Feed_Render
        ("Gq=2,a=p,i=110,p=13,c=0,C=1",
         Terminal.Core.Kitty_EINVAL,
         "zero column geometry rejection");
      Feed_Render
        ("Gq=2,a=p,i=110,p=14,x=2,C=1",
         Terminal.Core.Kitty_EINVAL,
         "empty source crop rejection");
      Feed_Render
        ("Gq=2,a=p,i=110,p=15,X="
         & Trimmed_Natural (Terminal.App.Renderer.Cell_Width (R))
         & ",C=1",
         Terminal.Core.Kitty_EINVAL,
         "out-of-cell x offset rejection");
      Feed_Render
        ("Gq=2,a=p,i=110,p=16,x=bad,C=1",
         Terminal.Core.Kitty_EINVAL,
         "malformed crop rejection");
      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
         Natural_Count : Natural := 0;
         Scaled_Count : Natural := 0;
         Scaled_Min_Y : Float := Float'Last;
         Scaled_Max_Y : Float := Float'First;
         Expected_Scaled_Width : constant Float :=
           Float (2 * Terminal.App.Renderer.Cell_Width (R));
         Expected_Scaled_Height : constant Float :=
           Float (Terminal.App.Renderer.Cell_Width (R));
      begin
         for I in 1 .. Frame.Image_Count loop
            if Frame.Images (I).Image_ID = 110 then
               if Frame.Images (I).Width = 2.0
                 and then Frame.Images (I).Height = 1.0
               then
                  Natural_Count := Natural_Count + 1;
               elsif Frame.Images (I).Width = Expected_Scaled_Width
                 and then Frame.Images (I).Height = Expected_Scaled_Height
               then
                  Scaled_Count := Scaled_Count + 1;
                  Scaled_Min_Y := Float'Min
                    (Scaled_Min_Y, Frame.Images (I).Y);
                  Scaled_Max_Y := Float'Max
                    (Scaled_Max_Y, Frame.Images (I).Y);
               end if;
            end if;
         end loop;
         Assert
           (Natural_Count = 1 and then Scaled_Count = 2,
            "placement geometry preserves natural size and aspect ratio");
         Assert
           (Scaled_Max_Y > Scaled_Min_Y,
            "two-axis placement centers letterboxed image content");
      end;
      Feed_Render
        ("Gq=2,a=T,f=32,s=2,v=1,C=1;/wAA/wD/AP8=",
         Terminal.Core.Kitty_OK,
         "anonymous natural geometry display");
      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
         Found : Boolean := False;
      begin
         for I in 1 .. Frame.Image_Count loop
            if Frame.Images (I).Protocol =
              Terminal.App.Render_Model.Image_Kitty
              and then Frame.Images (I).Image_ID = 0
              and then Frame.Images (I).Width = 2.0
              and then Frame.Images (I).Height = 1.0
            then
               Found := True;
            end if;
         end loop;
         Assert
           (Found,
            "anonymous placement derives natural geometry without an ID");
      end;

      Terminal.App.Renderer.Release_Graphics_Stream (R, 3_001);
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
           Objects_Before,
         "chunk validation stream cleanup");
      Terminal.Core.Finalize (Chunk_T);
   end;

   declare
      Quota_R : Terminal.App.Renderer.Renderer;
      Quota_Status : Terminal.App.Renderer.Init_Status;
      Quota_T : Terminal.Core.Terminal;
      Quota_Init : Terminal.Core.Initialize_Status;
      Quota_Feed : Terminal.Core.Feed_Status;
      Event : Terminal.Core.Graphics_Event;
      Result : Terminal.Core.Kitty_Graphics_Result;
      Tabs : Terminal.App.Tabs.Tab_State;
      Splits : Terminal.App.Splits.Split_State;

      procedure Feed_Quota
        (Text : String;
         Expected : Terminal.Core.Kitty_Graphics_Result_Code;
         Message : String)
      is
         Snapshots : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
         Local_Render_Status : Terminal.App.Renderer.Render_Status;
      begin
         Terminal.Core.Feed
           (Quota_T,
            To_Bytes (ASCII.ESC & "_" & Text & ASCII.ESC & "\"),
            Quota_Feed);
         Assert (Quota_Feed = Terminal.Core.Ok, Message & " feed");
         Terminal.Core.Peek_Graphics_Event (Quota_T, Event);
         Snapshots (1) := Terminal.Core.Snapshot (Quota_T);
         Snapshots (1).Graphics := Event;
         Terminal.App.Renderer.Render_App
           (Quota_R,
            Snapshots,
            1,
            Terminal.App.Tabs.Snapshot (Tabs),
            Terminal.App.Splits.Snapshot (Splits),
            Local_Render_Status);
         Terminal.Core.Release (Snapshots (1));
         Assert
           (Local_Render_Status = Terminal.App.Renderer.Ok,
            Message & " render");
         Result := Terminal.App.Renderer.Graphics_Result (Quota_R, Event);
         Assert (Result.Code = Expected, Message & " result");
         Terminal.Core.Complete_Graphics_Event (Quota_T, Event, Result);
         Terminal.App.Renderer.Commit_Graphics_Events (Quota_R);
      end Feed_Quota;
   begin
      Terminal.App.Renderer.Initialize_Headless (Quota_R, Quota_Status);
      Assert (Quota_Status = Terminal.App.Renderer.Ok, "quota renderer init");
      Terminal.App.Renderer.Set_Graphics_Resource_Limits
        (Quota_R,
         (Image_Objects => 2,
          Image_Bytes   => 8,
          Placements    => 2,
          Animation_Frames => 2,
          others => <>));
      Assert
        (Terminal.App.Renderer.Graphics_Resource_Limit (Quota_R) =
           (Image_Objects => 2,
            Image_Bytes => 8,
            Placements => 2,
            Animation_Frames => 2,
            others => <>),
         "configurable graphics quotas");
      Terminal.Core.Initialize (Quota_T, 2, 4, 10, Quota_Init);
      Assert (Quota_Init = Terminal.Core.Ok, "quota core init");
      Terminal.Core.Set_Graphics_Stream_ID (Quota_T, 3_002);
      Terminal.App.Tabs.Initialize (Tabs);
      Terminal.App.Splits.Initialize (Splits);

      Feed_Quota
        ("Gq=2,a=t,i=1,N=0,f=32,s=1,v=1;/wAA/w==",
         Terminal.Core.Kitty_OK,
         "quota first image");
      Feed_Quota
        ("Gq=2,a=t,i=2,N=1,f=32,s=1,v=1;AP8A/w==",
         Terminal.Core.Kitty_OK,
         "quota transient image");
      Feed_Quota
        ("Gq=2,a=t,i=3,N=0,f=32,s=1,v=1;AAD//w==",
         Terminal.Core.Kitty_OK,
         "quota eviction image");
      Assert
        (Terminal.App.Renderer.Diagnostics (Quota_R).Kitty_Image_Object_Count = 2
         and then
           Terminal.App.Renderer.Diagnostics (Quota_R).Kitty_Image_Object_Bytes = 8,
         "quota accounting after eviction");
      Feed_Quota
        ("Gq=2,a=p,i=2,p=1,c=1,r=1,C=1",
         Terminal.Core.Kitty_ENOENT,
         "transient image evicted first");
      Feed_Quota
        ("Gq=2,a=p,i=1,p=1,c=1,r=1,C=1",
         Terminal.Core.Kitty_OK,
         "older persistent-hint image retained");
      Feed_Quota
        ("Gq=2,a=p,i=3,p=1,c=1,r=1,C=1",
         Terminal.Core.Kitty_OK,
         "new image retained");
      Feed_Quota
        ("Gq=2,a=t,i=4,N=0,f=32,s=1,v=1;/////w==",
         Terminal.Core.Kitty_ENOMEM,
         "image quota response when all objects are placed");
      Feed_Quota
        ("Gq=2,a=p,i=1,p=2,c=1,r=1,C=1",
         Terminal.Core.Kitty_ENOMEM,
         "placement quota response");

      Terminal.App.Renderer.Release_Graphics_Stream (Quota_R, 3_002);
      Terminal.Core.Finalize (Quota_T);
      Terminal.App.Renderer.Finalize (Quota_R);
   end;

   Terminal.App.Renderer.Release_Graphics_Stream (R, 4_101);
   Terminal.Core.Set_Graphics_Stream_ID (T, 4_102);

   declare
      Segment_Count : constant Natural := 64;
   begin
      for I in 1 .. Segment_Count loop
         declare
            Prefix : constant String :=
              (if I = 1 then "Gf=32,a=T,C=1,s=48,v=1,c=12,r=1,m=1;"
               elsif I = Segment_Count then "Gm=0;"
               else "Gm=1;");
         begin
            Terminal.Core.Feed
              (T,
               To_Bytes
                 (ASCII.ESC & "_" & Prefix & "AAAA" & ASCII.ESC & "\"),
               Feed_Status);
            Assert
              (Feed_Status = Terminal.Core.Ok,
               "many-segment kitty chunk feed failed");

            declare
               Snap : Terminal.Core.Render_Snapshot :=
                 Terminal.Core.Snapshot (T);
            begin
               Terminal.App.Renderer.Render (R, Snap, Render_Status);
               Terminal.Core.Release (Snap);
            end;
            Assert
              (Render_Status = Terminal.App.Renderer.Ok,
               "many-segment kitty chunk render failed");

            if I < Segment_Count then
               Assert
                 (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
                  "many-segment kitty chunk should wait for final segment");
            end if;
         end;
      end loop;

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 48
            and then Diagnostics.Last_Image_Pixel_Height = 1,
            "many-segment kitty image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Encoded_Preview_Length = 0,
            "retained many-segment image no longer owns encoded chunks");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "many-segment kitty image should be textured");
         Assert
           (Frame.Images (1).Decoded_Byte_Length = 48 * 4
            and then Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Buffer
            and then Frame.Images (1).Encoded_Source_Bytes = null,
            "many-segment kitty command should retain decoded pixels");
         Assert
           (not Frame.Images (1).Placeholder,
            "many-segment kitty command should be textured");
      end;
   end;

   Terminal.App.Renderer.Release_Graphics_Stream (R, 4_102);
   Terminal.Core.Initialize (T, 1, 1, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "large chunked raw core reinitialize failed");
   Terminal.Core.Set_Graphics_Stream_ID (T, 4_103);

   declare
      Width          : constant Natural := 450;
      Height         : constant Natural := 300;
      Decoded_Length : constant Natural := Width * Height * 4;
      Encoded_Length : constant Natural := Decoded_Length / 3 * 4;
      Chunk_Length   : constant Natural := 4_096;
      Sent           : Natural := 0;

      procedure Feed_Chunk
        (Text    : String;
         Message : String;
         Final   : Boolean)
      is
      begin
         Terminal.Core.Feed
           (T,
            To_Bytes (ASCII.ESC & "_" & Text & ASCII.ESC & "\"),
            Feed_Status);
         Assert (Feed_Status = Terminal.Core.Ok, Message & " feed failed");

         if Final then
            declare
               Event : Terminal.Core.Graphics_Event;
            begin
               Terminal.Core.Peek_Graphics_Event (T, Event);
               Terminal.App.Renderer.Stage_Graphics_Event
                 (R, Event, Terminal.Core.Graphics_Event_Payload (T, Event));
            end;
         end if;

         Render_And_Complete_Graphics (T);
         Assert (Render_Status = Terminal.App.Renderer.Ok, Message & " render failed");
         if not Final then
            Assert
              (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
               Message & " should wait for final chunk");
         end if;
      end Feed_Chunk;
   begin
      Feed_Chunk
        ("Gf=32,a=T,C=1,s=450,v=300,c=1,r=1,m=1;"
         & Repeat_Char ('A', Chunk_Length),
         "large chunked raw kitty first chunk",
         False);
      Sent := Sent + Chunk_Length;

      while Sent + Chunk_Length < Encoded_Length loop
         Feed_Chunk
           ("Gm=1;" & Repeat_Char ('A', Chunk_Length),
            "large chunked raw kitty middle chunk",
            False);
         Sent := Sent + Chunk_Length;
      end loop;

      Feed_Chunk
        ("Gm=0;" & Repeat_Char ('A', Encoded_Length - Sent),
         "large chunked raw kitty final chunk",
         True);

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = Width
            and then Diagnostics.Last_Image_Pixel_Height = Height,
            "large chunked raw kitty image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Length =
            Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length,
            "large chunked raw kitty decoded diagnostics preview length");
         Assert
           (Diagnostics.Last_Image_Payload_Preview_Complete,
            "large chunked raw kitty payload should be complete");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "large chunked raw kitty image should be textured");
         Assert
           (Frame.Images (1).Pixel_Width = Width
            and then Frame.Images (1).Pixel_Height = Height
            and then Frame.Images (1).Decoded_Byte_Length = Decoded_Length
            and then Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Buffer
            and then Frame.Images (1).Encoded_Source_Bytes = null
            and then Frame.Images (1).Decoded_Preview_Length =
              Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length,
            "large chunked raw kitty command should retain decoded pixels");
         Assert
           (not Frame.Images (1).Placeholder,
            "large chunked raw kitty command should be textured");
      end;
   end;

   Terminal.App.Renderer.Release_Graphics_Stream (R, 4_103);
   Terminal.Core.Set_Graphics_Stream_ID (T, 4_104);

   declare
      Payload : constant String :=
        "Gf=32,a=T,C=1,s=33,v=32,c=1,r=1;" & Repeat_Char ('A', 5632);
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "large raw kitty graphics feed failed");
      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "large raw graphics render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 33
            and then Diagnostics.Last_Image_Pixel_Height = 32,
            "large raw graphics image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Length =
            Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length,
            "large raw graphics decoded preview length");
         Assert
           (Diagnostics.Last_Image_Payload_Preview_Complete,
            "large raw graphics payload should fit render buffer");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "large raw graphics image should be textured");
         Assert
           (Frame.Images (1).Pixel_Width = 33
            and then Frame.Images (1).Pixel_Height = 32
            and then Frame.Images (1).Decoded_Byte_Length = 33 * 32 * 4
            and then Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Buffer
            and then Frame.Images (1).Encoded_Source_Bytes = null
            and then Frame.Images (1).Decoded_Preview_Length =
              Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length,
            "large raw graphics command retained source metadata");
         Assert
           (not Frame.Images (1).Placeholder,
            "large raw graphics command should be textured");
      end;
   end;

   Terminal.App.Renderer.Release_Graphics_Stream (R, 4_104);
   Terminal.Core.Set_Graphics_Stream_ID (T, 4_105);

   declare
      Payload : constant String :=
        "Gf=32,a=T,C=1,s=129,v=128,c=1,r=1;" & Repeat_Char ('A', 88064);
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "over-64KiB raw kitty graphics feed failed");
      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "over-64KiB raw graphics render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 129
            and then Diagnostics.Last_Image_Pixel_Height = 128,
            "over-64KiB raw graphics image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Length =
            Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length,
            "over-64KiB raw graphics decoded preview length");
         Assert
           (Diagnostics.Last_Image_Payload_Preview_Complete,
            "over-64KiB raw graphics payload should fit render buffer");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "over-64KiB raw graphics image should be textured");
         Assert
           (Frame.Images (1).Pixel_Width = 129
            and then Frame.Images (1).Pixel_Height = 128
            and then Frame.Images (1).Decoded_Byte_Length = 129 * 128 * 4
            and then Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Buffer
            and then Frame.Images (1).Encoded_Source_Bytes = null
            and then Frame.Images (1).Decoded_Preview_Length =
              Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length,
            "over-64KiB raw graphics command retained source metadata");
         Assert
           (not Frame.Images (1).Placeholder,
            "over-64KiB raw graphics command should be textured");
      end;
   end;

   Terminal.App.Renderer.Release_Graphics_Stream (R, 4_105);
   Terminal.Core.Set_Graphics_Stream_ID (T, 4_106);

   declare
      Payload : constant String :=
        "Gf=32,a=T,C=1,s=16385,v=1024,c=40,r=20;AAAA";
      Allocation_Failures_Before : constant Interfaces.Unsigned_64 :=
        Terminal.App.Renderer.Diagnostics (R).Allocation_Failure_Count;
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "oversized raw kitty graphics feed failed");
      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "oversized raw graphics render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Frame.Image_Count = 0
            and then Diagnostics.Allocation_Failure_Count =
              Allocation_Failures_Before + 1,
            "oversized raw graphics is rejected before image allocation");
      end;
   end;

   declare
      Payload : constant String :=
        "File=name=pixel.png;size=69;inline=1;doNotMoveCursor=1;width=20px;height=40px;"
        & "preserveAspectRatio=1:"
        & "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJAMaU4gAAAABJRU5ErkJggg==";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "]1337;" & Payload & ASCII.BEL),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "iTerm2 PNG image feed failed");
      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "iTerm2 PNG image render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Protocol =
            Terminal.App.Render_Model.Image_ITerm2,
            "iTerm2 PNG image diagnostic protocol");
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 1
            and then Diagnostics.Last_Image_Pixel_Height = 1,
            "iTerm2 PNG image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Length = 4,
            "iTerm2 PNG image decoded byte length");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Bytes (1) = 16#FF#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (2) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (3) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (4) = 16#FF#,
            "iTerm2 PNG image first RGBA pixel");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "iTerm2 PNG image should be textured");
         Assert
           (Frame.Images (1).Protocol = Terminal.App.Render_Model.Image_ITerm2
            and then Frame.Images (1).Raw_Format = 32
            and then Frame.Images (1).Pixel_Width = 1
            and then Frame.Images (1).Pixel_Height = 1
            and then Frame.Images (1).Decoded_Row_Stride_Bytes = 4
            --  The 20x20 px box of a square image, clipped to the one-cell
            --  viewport, whose size comes from whatever font the host has.
            and then Frame.Images (1).Width =
              Float'Min (20.0, Float (Terminal.App.Renderer.Cell_Width (R)))
            and then Frame.Images (1).Height =
              Float'Min (20.0, Float (Terminal.App.Renderer.Cell_Height (R))),
            "iTerm2 PNG retained command is clipped to the viewport");
         Assert
           (Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Buffer
            and then Frame.Images (1).Encoded_Source_Bytes = null,
            "iTerm2 PNG retained command should borrow decoded pixels");
         Assert
           (not Frame.Images (1).Placeholder,
            "iTerm2 PNG image command should be textured");
      end;
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "]1337;File=size=70;inline=1;doNotMoveCursor=1:"
         & "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJAMaU4gAAAABJRU5ErkJggg=="
         & ASCII.BEL),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "iTerm2 size mismatch feed");
   Render_And_Complete_Graphics (T);
   Assert
     (Render_Status = Terminal.App.Renderer.Ok
      and then Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 2,
      "iTerm2 declared size remains a non-binding progress hint");

   declare
      Cursor_T : Terminal.Core.Terminal;
      Cursor_Init : Terminal.Core.Initialize_Status;
      Cursor_Feed : Terminal.Core.Feed_Status;
      Event : Terminal.Core.Graphics_Event;
      Outcome : Terminal.Core.Kitty_Graphics_Result;
      Cursor_Tabs : Terminal.App.Tabs.Tab_State;
      Cursor_Splits : Terminal.App.Splits.Split_State;
   begin
      Terminal.Core.Initialize (Cursor_T, 4, 4, 10, Cursor_Init);
      Assert
        (Cursor_Init = Terminal.Core.Ok,
         "iTerm2 cursor renderer initialize");
      Terminal.Core.Set_Graphics_Stream_ID (Cursor_T, 4_107);
      Terminal.Core.Feed
        (Cursor_T,
         To_Bytes
           (ASCII.ESC
            & "]1337;File=inline=1;width=1;height=2;preserveAspectRatio=0:"
            & "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJAMaU4gAAAABJRU5ErkJggg=="
            & ASCII.BEL & "x"),
         Cursor_Feed);
      Assert (Cursor_Feed = Terminal.Core.Ok, "iTerm2 cursor renderer feed");
      Terminal.Core.Peek_Graphics_Event (Cursor_T, Event);
      Terminal.App.Tabs.Initialize (Cursor_Tabs);
      Terminal.App.Splits.Initialize (Cursor_Splits);
      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (Cursor_T);
         Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
      begin
         Snaps (1) := Snap;
         Terminal.App.Renderer.Render_App
           (R,
            Snaps,
            1,
            Terminal.App.Tabs.Snapshot (Cursor_Tabs),
            Terminal.App.Splits.Snapshot (Cursor_Splits),
            Render_Status);
         Terminal.Core.Release (Snap);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "iTerm2 cursor renderer render");
      Outcome := Terminal.App.Renderer.Graphics_Result (R, Event);
      Assert
        (Outcome.Code = Terminal.Core.Kitty_OK,
         "iTerm2 successful rendering produces an internal cursor commit result");
      Assert
        (Outcome.Move_Cursor and then Outcome.Cursor_To_Line_Start,
         "iTerm2 default rendering requests next-line cursor movement");
      Assert
        (Outcome.Placement_Rows = 2,
         "iTerm2 cursor movement reflects rendered cell height");
      Terminal.Core.Complete_Graphics_Event (Cursor_T, Event, Outcome);
      Terminal.App.Renderer.Commit_Graphics_Events (R);
      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (Cursor_T);
      begin
         Assert
           (Terminal.Core.Cell_At (Snap, 3, 1).Text.Code_Point = 16#78#,
            "iTerm2 renderer commits cursor movement before trailing input");
         Terminal.Core.Release (Snap);
      end;
      Terminal.App.Renderer.Release_Graphics_Stream (R, 4_107);
      Terminal.Core.Finalize (Cursor_T);
   end;

   Terminal.App.Renderer.Release_Graphics_Stream (R, 4_106);

   declare
      Payload : constant String :=
        "Gf=100,a=T,C=1,c=1,r=1;iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJAMaU4gAAAABJRU5ErkJggg==";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "kitty PNG image feed failed");
      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "kitty PNG image render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Protocol =
            Terminal.App.Render_Model.Image_Kitty,
            "kitty PNG image diagnostic protocol");
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 1
            and then Diagnostics.Last_Image_Pixel_Height = 1,
            "kitty PNG image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Length = 4,
            "kitty PNG image decoded byte length");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Bytes (1) = 16#FF#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (2) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (3) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (4) = 16#FF#,
            "kitty PNG image first RGBA pixel");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "kitty PNG image should be textured");
         Assert
           (Frame.Images (1).Protocol = Terminal.App.Render_Model.Image_Kitty
            and then Frame.Images (1).Raw_Format = 32
            and then Frame.Images (1).Pixel_Width = 1
            and then Frame.Images (1).Pixel_Height = 1
            and then Frame.Images (1).Decoded_Row_Stride_Bytes = 4,
            "kitty PNG image command pixel metadata");
         Assert
           (Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Buffer
            and then Frame.Images (1).Encoded_Source_Bytes = null,
            "kitty PNG image command should retain decoded pixels");
         Assert
           (not Frame.Images (1).Placeholder,
            "kitty PNG image command should be textured");
      end;
   end;

   Terminal.App.Renderer.Release_Graphics_Stream (R, 4_106);
   Terminal.Core.Set_Graphics_Stream_ID (T, 4_107);

   declare
      First_Chunk : constant String :=
        "Gf=100,a=T,C=1,c=1,r=1,m=1;iVBORw0KGgoAAAANSUhEUgAA";
      Middle_Chunk : constant String :=
        "Gm=1;AAEAAAABCAIAAACQd1PeAAAA";
      Last_Chunk : constant String :=
        "Gm=0;DUlEQVR4nGP4z8AAAAMBAQDJAMaU4gAAAABJRU5ErkJggg==";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & First_Chunk & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "chunked kitty PNG first chunk feed failed");

      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "chunked kitty PNG first render failed");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
         "chunked kitty PNG first chunk should wait for final chunk");

      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Middle_Chunk & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "chunked kitty PNG middle chunk feed failed");

      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "chunked kitty PNG middle render failed");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
         "chunked kitty PNG middle chunk should wait for final chunk");

      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Last_Chunk & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "chunked kitty PNG final chunk feed failed");

      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "chunked kitty PNG final render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Protocol =
            Terminal.App.Render_Model.Image_Kitty,
            "chunked kitty PNG image diagnostic protocol");
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 1
            and then Diagnostics.Last_Image_Pixel_Height = 1,
            "chunked kitty PNG image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Length = 4,
            "chunked kitty PNG decoded byte length");
         Assert
           (Diagnostics.Last_Image_Encoded_Preview_Length = 0,
            "retained chunked PNG no longer owns encoded segments");
         Assert
           (Diagnostics.Last_Image_Staging_Byte_Length = 0,
            "retained chunked PNG no longer requires decode staging");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Bytes (1) = 16#FF#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (2) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (3) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (4) = 16#FF#,
            "chunked kitty PNG decoded bytes");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "chunked kitty PNG image should be textured");
         Assert
           (Frame.Images (1).Protocol = Terminal.App.Render_Model.Image_Kitty
            and then Frame.Images (1).Pixel_Width = 1
            and then Frame.Images (1).Pixel_Height = 1
            and then Frame.Images (1).Decoded_Row_Stride_Bytes = 4,
            "chunked kitty PNG command pixel metadata");
         Assert
           (Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Buffer
            and then Frame.Images (1).Encoded_Source_Bytes = null,
            "chunked kitty PNG command should retain decoded pixels");
         Assert
           (not Frame.Images (1).Placeholder,
            "chunked kitty PNG command should be textured");
      end;
   end;

   Terminal.App.Renderer.Release_Graphics_Stream (R, 4_107);
   Terminal.Core.Set_Graphics_Stream_ID (T, 4_108);

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "Pq~" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "sixel graphics feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "sixel graphics render failed");

   declare
      Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert
        (Diagnostics.Last_Image_Protocol =
         Terminal.App.Render_Model.Image_Sixel,
         "sixel graphics image diagnostic protocol");
      Assert
        (Diagnostics.Last_Image_Raw_Format = 32
         and then Diagnostics.Last_Image_Pixel_Width = 1
         and then Diagnostics.Last_Image_Pixel_Height = 6,
         "sixel graphics image diagnostic pixel metadata");
      Assert
        (Diagnostics.Last_Image_Decoded_Preview_Length = 24,
         "sixel graphics image decoded byte length");
      Assert
        (Diagnostics.Last_Image_Decoded_Preview_Bytes (1) = 16#FF#
         and then Diagnostics.Last_Image_Decoded_Preview_Bytes (2) = 16#FF#
         and then Diagnostics.Last_Image_Decoded_Preview_Bytes (3) = 16#FF#
         and then Diagnostics.Last_Image_Decoded_Preview_Bytes (4) = 16#FF#,
         "sixel graphics first RGBA pixel");
      Assert
        (not Diagnostics.Last_Image_Placeholder,
         "sixel graphics image should be textured");
      Assert
        (Frame.Images (1).Protocol = Terminal.App.Render_Model.Image_Sixel
         and then Frame.Images (1).Raw_Format = 32
         and then Frame.Images (1).Pixel_Width = 1
         and then Frame.Images (1).Pixel_Height = 6
         and then Frame.Images (1).Decoded_Row_Stride_Bytes = 4,
         "sixel graphics command pixel metadata");
      Assert
         (Frame.Images (1).Decoded_Bytes /= null
         and then Frame.Images (1).Decoded_Source =
           Terminal.App.Render_Model.Image_Decoded_Source_Buffer
         and then Frame.Images (1).Encoded_Source_Bytes = null,
         "sixel retained command should borrow resolved palette pixels");
      Assert
        (not Frame.Images (1).Placeholder,
         "sixel graphics command should be textured");
      Assert
        (Terminal.App.Renderer.Image_Status_Label (Diagnostics) =
         Bounded_Image_Label
           ("image sixel size="
         & "1"
         & "x"
         & "6"
         & " pixels=1x6 format=32 payload=0 payload-complete preview=24/0 bytes=FFFFFFFF textured decoded"),
         "sixel graphics image diagnostic status label");
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
      "retained sixel render failed");
   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert
        (Frame.Image_Count = 1
         and then Frame.Images (1).Protocol =
           Terminal.App.Render_Model.Image_Sixel,
         "sixel image should persist after its graphics event is consumed");
   end;

   Terminal.App.Renderer.Release_Graphics_Stream (R, 4_108);

   declare
      Aux_T : Terminal.Core.Terminal;
      Aux_Init : Terminal.Core.Initialize_Status;
      Aux_Feed : Terminal.Core.Feed_Status;
      Aux_Objects_Before : constant Natural :=
        Terminal.App.Renderer.Diagnostics (R).Image_Object_Count;
      Aux_Placements_Before : constant Natural :=
        Terminal.App.Renderer.Diagnostics (R).Placement_Count;

      procedure Feed_Render_And_Discard (Text : String; Label_Text : String) is
         Event : Terminal.Core.Graphics_Event;
         Snap : Terminal.Core.Render_Snapshot;
      begin
         Terminal.Core.Feed (Aux_T, To_Bytes (Text), Aux_Feed);
         Assert (Aux_Feed = Terminal.Core.Ok, Label_Text & " feed");
         Terminal.Core.Peek_Graphics_Event (Aux_T, Event);
         Assert (Event.Pending, Label_Text & " event");
         Snap := Terminal.Core.Snapshot (Aux_T);
         Snap.Graphics := Event;
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Assert (Render_Status = Terminal.App.Renderer.Ok, Label_Text & " render");
         Terminal.Core.Release (Snap);
         Terminal.Core.Discard_Graphics_Event (Aux_T);
      end Feed_Render_And_Discard;
   begin
      Terminal.Core.Initialize (Aux_T, 4, 10, 100, Aux_Init);
      Assert (Aux_Init = Terminal.Core.Ok, "auxiliary coexist terminal initialize");
      Terminal.Core.Set_Graphics_Stream_ID (Aux_T, 4_109);
      Feed_Render_And_Discard
        (ASCII.ESC & "Pq~" & ASCII.ESC & "\",
         "coexisting sixel image");
      Feed_Render_And_Discard
        (ASCII.ESC & "]1337;File=inline=1;doNotMoveCursor=1;width=1;height=1:"
         & "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJAMaU4gAAAABJRU5ErkJggg=="
         & ASCII.BEL,
         "coexisting iTerm2 image");
      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (Aux_T);
      begin
         Snap.Graphics := (others => <>);
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "coexisting auxiliary retained render");
      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
         Aux_Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Saw_Sixel : Boolean := False;
         Saw_ITerm2 : Boolean := False;
      begin
         for I in 1 .. Frame.Image_Count loop
            Saw_Sixel := Saw_Sixel
              or else Frame.Images (I).Protocol =
                Terminal.App.Render_Model.Image_Sixel;
            Saw_ITerm2 := Saw_ITerm2
              or else Frame.Images (I).Protocol =
                Terminal.App.Render_Model.Image_ITerm2;
         end loop;
         Assert
           (Frame.Image_Count = 2 and then Saw_Sixel and then Saw_ITerm2,
            "retained Sixel and iTerm2 images should coexist");
         Assert
           (Aux_Diagnostics.Image_Object_Count = Aux_Objects_Before + 2
            and then Aux_Diagnostics.Placement_Count =
              Aux_Placements_Before + 2
            and then Aux_Diagnostics.Kitty_Image_Object_Count =
              Aux_Diagnostics.Image_Object_Count
            and then Aux_Diagnostics.Kitty_Placement_Count =
              Aux_Diagnostics.Placement_Count,
            "shared graphics-store diagnostics are protocol-neutral");
      end;
      Terminal.App.Renderer.Release_Graphics_Stream (R, 4_109);
      Terminal.Core.Finalize (Aux_T);
   end;

   declare
      Retry_T : Terminal.Core.Terminal;
      Retry_Init : Terminal.Core.Initialize_Status;
      Retry_Feed : Terminal.Core.Feed_Status;
      Retry_Tabs : Terminal.App.Tabs.Tab_State;
      Retry_Splits : Terminal.App.Splits.Split_State;

      procedure Retry_Event (Text : String; Label_Text : String) is
         Event : Terminal.Core.Graphics_Event;
         Snapshots : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
         Objects_Before : constant Natural :=
           Terminal.App.Renderer.Diagnostics (R).Image_Object_Count;
         Placements_Before : constant Natural :=
           Terminal.App.Renderer.Diagnostics (R).Placement_Count;
      begin
         Terminal.Core.Feed (Retry_T, To_Bytes (Text), Retry_Feed);
         Assert (Retry_Feed = Terminal.Core.Ok, Label_Text & " feed");
         Terminal.Core.Peek_Graphics_Event (Retry_T, Event);
         Assert (Event.Pending, Label_Text & " event");
         Snapshots (1) := Terminal.Core.Snapshot (Retry_T);
         Snapshots (1).Graphics := Event;
         for Attempt in 1 .. 2 loop
            Terminal.App.Renderer.Render_App
              (R,
               Snapshots,
               1,
               Terminal.App.Tabs.Snapshot (Retry_Tabs),
               Terminal.App.Splits.Snapshot (Retry_Splits),
               Render_Status);
            Assert
              (Render_Status = Terminal.App.Renderer.Ok,
               Label_Text & " retry render");
            Assert
              (Terminal.App.Renderer.Diagnostics (R).Image_Object_Count =
                 Objects_Before + 1
               and then
                 Terminal.App.Renderer.Diagnostics (R).Placement_Count =
                   Placements_Before + 1,
               Label_Text & " retry does not duplicate resources");
         end loop;
         Terminal.Core.Release (Snapshots (1));
         Terminal.Core.Discard_Graphics_Event (Retry_T);
         Terminal.App.Renderer.Commit_Graphics_Events (R);
      end Retry_Event;
   begin
      Terminal.Core.Initialize (Retry_T, 4, 10, 100, Retry_Init);
      Assert (Retry_Init = Terminal.Core.Ok, "auxiliary retry initialize");
      Terminal.Core.Set_Graphics_Stream_ID (Retry_T, 4_110);
      Terminal.App.Tabs.Initialize (Retry_Tabs);
      Terminal.App.Splits.Initialize (Retry_Splits);
      Retry_Event
        (ASCII.ESC & "Pq~" & ASCII.ESC & "\",
         "Sixel presentation");
      Retry_Event
        (ASCII.ESC & "]1337;File=inline=1;doNotMoveCursor=1;width=1;height=1:"
         & "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJAMaU4gAAAABJRU5ErkJggg=="
         & ASCII.BEL,
         "iTerm2 presentation");
      Terminal.App.Renderer.Release_Graphics_Stream (R, 4_110);
      Terminal.Core.Finalize (Retry_T);
   end;

   while Terminal.Core.Pending_Graphics_Event_Count (T) > 0 loop
      Terminal.Core.Discard_Graphics_Event (T);
   end loop;
   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "_Gf=100,a=T,C=1;SG$=" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "partial kitty graphics feed failed");
   Render_And_Complete_Graphics (T);
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "partial graphics render failed");

   declare
      Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert
        (Diagnostics.Last_Image_Decoded_Preview_Length = 0,
         "partial graphics image diagnostic decoded preview length");
      Assert
        (Diagnostics.Last_Image_Decode_Status =
         Terminal.App.Render_Model.Image_Decode_Invalid_Byte,
         "partial graphics image diagnostic decode status");
      Assert
        (Diagnostics.Last_Image_Payload_Preview_Complete,
         "partial graphics image diagnostic payload preview complete");
      Assert
        (not Diagnostics.Last_Image_Preview_Decode_Complete,
         "partial graphics image diagnostic decode complete");
      Assert
        (Frame.Images (1).Decode_Status =
         Terminal.App.Render_Model.Image_Decode_Invalid_Byte,
         "partial graphics command decode status");
      Assert
        (Terminal.App.Renderer.Image_Status_Label (Diagnostics) =
         Bounded_Image_Label
           ("image kitty size="
         & Trimmed_Natural (Terminal.App.Renderer.Cell_Width (R) * 6)
         & "x"
         & Trimmed_Natural (Terminal.App.Renderer.Cell_Height (R) * 3)
         & " payload=19 payload-complete preview=0/4 placeholder partial invalid-byte"),
         "partial graphics image diagnostic status label");
   end;

   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[4 q"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "underline cursor feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "underline cursor render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert (Frame.Rectangle_Count >= 3, "expected underline cursor rectangle");
      Assert
        (Frame.Rectangles (3).Height <= 3.0,
         "underline cursor should be thin");
      Assert
        (Frame.Rectangles (3).Width =
           Float (Terminal.App.Renderer.Cell_Width (R)),
         "underline cursor should span the cell");
   end;

   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[6 q"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "bar cursor feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "bar cursor render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert (Frame.Rectangle_Count >= 3, "expected bar cursor rectangle");
      Assert
        (Frame.Rectangles (3).Width <= 3.0,
         "bar cursor should be thin");
      Assert
        (Frame.Rectangles (3).Height <= 16.0,
         "bar cursor should use font-sized height");
   end;

   Terminal.App.Renderer.Set_Framebuffer_Size (R, 100, 80);
   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "render with framebuffer extent failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert
        (Frame.Width = 100,
         "frame width should use the target framebuffer width");
      Assert
        (Frame.Height = 80,
         "frame height should use the target framebuffer height");
      Assert
        (Frame.Rectangles (2).X = Float (Terminal.App.Renderer.Content_Margin),
         "first cell should keep the horizontal content margin");
      Assert
        (Frame.Rectangles (2).Y = Float (Terminal.App.Renderer.Content_Margin),
         "first cell should keep the vertical content margin");
   end;

   Terminal.Core.Initialize (T, 1, 2, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "bold core initialize failed");
   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[1mA"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "bold feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "bold render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert (Frame.Glyph_Count = 2, "bold glyph should be drawn twice");
      Assert
        (Frame.Glyphs (2).X = Frame.Glyphs (1).X + 1.0,
         "bold duplicate glyph should be offset by one pixel");
      Assert
        (Frame.Glyphs (2).Y = Frame.Glyphs (1).Y,
         "bold duplicate glyph should keep baseline placement");
   end;

   Terminal.Core.Initialize (T, 1, 2, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "bold indexed core initialize failed");
   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[1;31mA"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "bold indexed feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "bold indexed render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert (Frame.Glyph_Count = 2, "bold indexed glyph should be drawn twice");
      Assert_Close (Frame.Glyphs (1).Color.R, 1.0, "bold red bright red");
      Assert_Close (Frame.Glyphs (1).Color.G, 0.36, "bold red bright green");
      Assert_Close (Frame.Glyphs (1).Color.B, 0.32, "bold red bright blue");
   end;

   Terminal.Core.Initialize (T, 1, 2, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "inverse bold indexed core initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "[1;31;44;7mA"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "inverse bold indexed feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "inverse bold indexed render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert (Frame.Glyph_Count = 2, "inverse bold glyph should be drawn twice");
      Assert_Close
        (Frame.Glyphs (1).Color.R,
         0.25,
         "inverse bold should use original background red");
      Assert_Close
        (Frame.Glyphs (1).Color.G,
         0.45,
         "inverse bold should use original background green");
      Assert_Close
        (Frame.Glyphs (1).Color.B,
         0.86,
         "inverse bold should use original background blue");
   end;

   Terminal.Core.Initialize (T, 1, 2, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "faint core initialize failed");
   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[2mA"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "faint feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "faint render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert (Frame.Glyph_Count >= 1, "faint glyph count");
      Assert
        (Frame.Glyphs (1).Color.R < 0.86,
         "faint glyph should dim default foreground red");
      Assert
        (Frame.Glyphs (1).Color.G < 0.88,
         "faint glyph should dim default foreground green");
      Assert
        (Frame.Glyphs (1).Color.B < 0.88,
         "faint glyph should dim default foreground blue");
   end;

   Terminal.Core.Initialize (T, 1, 2, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "conceal core initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "[8;4;9mA"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "conceal feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "conceal render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert (Frame.Glyph_Count = 0, "concealed glyph should not be drawn");
      Assert
        (Frame.Rectangle_Count >= 3,
         "concealed cell should still draw background and cursor rectangles");
      Assert
        (Frame.Rectangle_Count < 5,
         "concealed cell should not draw underline or strikethrough");
   end;

   Terminal.Core.Initialize (T, 1, 2, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "overline core initialize failed");
   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[53mA"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "overline feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "overline render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert (Frame.Rectangle_Count >= 5, "expected overline rectangle");
      Assert
        (Frame.Rectangles (3).Height = 1.0,
         "overline decoration should be one pixel high");
      Assert
        (Frame.Rectangles (3).Width =
           Float (Terminal.App.Renderer.Cell_Width (R)),
         "overline decoration should span the cell");
      Assert
        (Frame.Rectangles (3).Y =
           Float (Terminal.App.Renderer.Content_Margin),
         "overline decoration should sit at the cell top");
   end;

   Terminal.Core.Initialize (T, 1, 3, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "decoration core initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "[58;2;1;2;3;4mA" & ASCII.ESC & "[24;9mB"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "decoration feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "decoration render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert (Frame.Rectangle_Count >= 7, "expected decoration rectangles");
      Assert
        (Frame.Rectangles (3).Height = 1.0,
         "underline decoration should be one pixel high");
      Assert
        (Frame.Rectangles (3).Width =
           Float (Terminal.App.Renderer.Cell_Width (R)),
         "underline decoration should span the cell");
      Assert_Close
        (Frame.Rectangles (3).Color.R,
         1.0 / 255.0,
         "underline decoration red");
      Assert_Close
        (Frame.Rectangles (3).Color.G,
         2.0 / 255.0,
         "underline decoration green");
      Assert_Close
        (Frame.Rectangles (3).Color.B,
         3.0 / 255.0,
         "underline decoration blue");
      Assert
        (Frame.Rectangles (5).Height = 1.0,
         "strikethrough decoration should be one pixel high");
      Assert
        (Frame.Rectangles (5).Width =
           Float (Terminal.App.Renderer.Cell_Width (R)),
         "strikethrough decoration should span the cell");
   end;

   Terminal.Core.Initialize (T, 1, 4, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "underline substyle core initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "[4:2mA"
         & ASCII.ESC & "[4:3mB"
         & ASCII.ESC & "[4:4mC"
         & ASCII.ESC & "[4:5mD"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "underline substyle feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "underline substyle render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
      Found_Double_Line : Boolean := False;
      Found_Segment     : Boolean := False;
   begin
      Assert
        (Frame.Rectangle_Count >= 10,
         "underline substyles should emit multiple decoration rectangles");
      for I in 1 .. Frame.Rectangle_Count loop
         if Frame.Rectangles (I).Width =
           Float (Terminal.App.Renderer.Cell_Width (R))
         then
            for J in I + 1 .. Frame.Rectangle_Count loop
               if Frame.Rectangles (J).Width = Frame.Rectangles (I).Width
                 and then Frame.Rectangles (J).X = Frame.Rectangles (I).X
                 and then abs (Frame.Rectangles (J).Y - Frame.Rectangles (I).Y) = 2.0
               then
                  Found_Double_Line := True;
               end if;
            end loop;
         end if;

         if Frame.Rectangles (I).Width <= 2.0 then
            Found_Segment := True;
         end if;
      end loop;

      Assert
        (Found_Double_Line,
         "double underline should draw two separated full-width lines");
      Assert
        (Found_Segment,
         "curly or dotted underline should be segmented");
   end;

   Terminal.Core.Initialize (T, 1, 1, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "dense decoration core initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "[4:3;9;53mA"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "dense decoration feed failed");
   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "dense one-cell decorations fit the rectangle budget");
   Assert
     (Terminal.App.Renderer.Testing.Last_Frame (R).Rectangle_Count >= 9,
      "dense one-cell decorations are not silently truncated");

   Terminal.Core.Initialize (T, 1, 3, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "hover link core initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (Character'Val (16#1B#) & "[?25l"
         & Character'Val (16#1B#) & "]8;id=hover;https://example.test"
         & Character'Val (16#1B#) & "\"
         & "ab"
         & Character'Val (16#1B#) & "]8;;"
         & Character'Val (16#1B#) & "\"
         & "c"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "hover link feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Link : constant Terminal.Core.Hyperlink :=
        Terminal.App.Hyperlinks.Link_At (Snap, (Row => 1, Col => 1));
   begin
      Terminal.App.Renderer.Set_Hovered_Link (R, Link);
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "hover link render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert (Frame.Rectangle_Count >= 6, "expected hover link underlines");
      Assert
        (Frame.Rectangles (3).Height = 1.0,
         "hover underline first cell should be one pixel high");
      Assert
        (Frame.Rectangles (3).Y =
           Float
             (Terminal.App.Renderer.Content_Margin
              + Terminal.App.Renderer.Cell_Height (R) - 2),
         "hover underline first cell baseline");
      Assert
        (Frame.Rectangles (5).Height = 1.0,
         "hover underline second cell should be one pixel high");
      Assert
        (Frame.Rectangles (5).Width =
           Float (Terminal.App.Renderer.Cell_Width (R)),
         "hover underline second cell width");
   end;

   Terminal.App.Renderer.Set_Hovered_Link (R, (others => <>));

   Terminal.Core.Initialize (T, 1, 2, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "indexed color core initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "[38;5;196mA" & ASCII.ESC & "[48;5;232mB"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "indexed color feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "indexed color render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert (Frame.Glyph_Count >= 2, "indexed color glyph count");
      Assert_Close (Frame.Glyphs (1).Color.R, 1.0, "xterm 196 red");
      Assert_Close (Frame.Glyphs (1).Color.G, 0.0, "xterm 196 green");
      Assert_Close (Frame.Glyphs (1).Color.B, 0.0, "xterm 196 blue");
      Assert_Close
        (Frame.Rectangles (3).Color.R,
         8.0 / 255.0,
         "xterm 232 grayscale red");
      Assert_Close
        (Frame.Rectangles (3).Color.G,
         8.0 / 255.0,
         "xterm 232 grayscale green");
      Assert_Close
        (Frame.Rectangles (3).Color.B,
         8.0 / 255.0,
         "xterm 232 grayscale blue");
      Assert
        (Frame.Rectangles (3).Layer =
           Terminal.App.Render_Model.Rectangle_Cell_Background,
         "explicit cell background covers deep negative images");
   end;

   Terminal.Core.Initialize (T, 1, 3, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "cluster render core initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => Byte (Character'Pos ('a')),
       2 => 16#CC#, 3 => 16#81#,
       4 => 16#E2#, 5 => 16#80#, 6 => 16#8D#),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "cluster render feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "cluster render failed");

   declare
      Frame      : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
      Saw_Base   : Boolean := False;
      Saw_ZWJ    : Boolean := False;
   begin
      for I in 1 .. Frame.Glyph_Count loop
         if Frame.Glyphs (I).Codepoint = 16#61# then
            Saw_Base := True;
         elsif Frame.Glyphs (I).Codepoint = 16#200D# then
            Saw_ZWJ := True;
         end if;
      end loop;

      Assert (Saw_Base, "cluster render should draw base glyph");
      Assert (Frame.Text_Run_Count = 1, "cluster render text run count");
      Assert
        (Frame.Text_Runs (1).Shape_Status =
           Terminal.App.Render_Model.Shape_Ok,
         "cluster render shape status");
      Assert
        (Frame.Text_Runs (1).Shaped_Glyph_Count > 0,
         "cluster render shaped glyph count");
      Assert (not Saw_ZWJ, "cluster render should skip invisible ZWJ");
   end;

   Terminal.Core.Initialize (T, 1, 5, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "emoji cluster render core initialize failed");
   Terminal.Core.Feed
     (T,
      (1  => Byte (Character'Pos ('a')),
       2  => 16#F0#, 3  => 16#9F#, 4  => 16#91#, 5  => 16#A9#,
       6  => 16#E2#, 7  => 16#80#, 8  => 16#8D#,
       9  => 16#F0#, 10 => 16#9F#, 11 => 16#91#, 12 => 16#A8#,
       13 => 16#F0#, 14 => 16#9F#, 15 => 16#8F#, 16 => 16#BD#,
       17 => Byte (Character'Pos ('b'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "emoji cluster render feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "emoji cluster render failed");

   declare
      Frame       : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
      Saw_A       : Boolean := False;
      Saw_ZWJ     : Boolean := False;
      Saw_B       : Boolean := False;
   begin
      for I in 1 .. Frame.Glyph_Count loop
         if Frame.Glyphs (I).Codepoint = 16#61# then
            Saw_A := True;
         elsif Frame.Glyphs (I).Codepoint = 16#200D# then
            Saw_ZWJ := True;
         elsif Frame.Glyphs (I).Codepoint = 16#62# then
            Saw_B := True;
         end if;
      end loop;

      Assert (Saw_A, "emoji cluster render should draw prefix");
      Assert (Saw_B, "emoji cluster render should draw suffix");
      Assert (Frame.Text_Run_Count = 3, "emoji cluster render text run count");
      Assert
        (Frame.Text_Runs (2).Codepoint_Count = 4,
         "emoji cluster text run should preserve cluster length");
      Assert
        (Frame.Text_Runs (2).Codepoints (1) = 16#1F469#,
         "emoji cluster text run base");
      Assert
        (Frame.Text_Runs (2).Codepoints (2) = 16#200D#,
         "emoji cluster text run ZWJ");
      Assert
        (Frame.Text_Runs (2).Codepoints (3) = 16#1F468#,
         "emoji cluster text run joined scalar");
      Assert
        (Frame.Text_Runs (2).Codepoints (4) = 16#1F3FD#,
         "emoji cluster text run modifier");
      Assert
        (Frame.Text_Runs (2).Cell_Span = 2,
         "emoji cluster text run cell span");
      Assert
        (Frame.Text_Runs (2).Run_Kind =
           Terminal.App.Render_Model.Joined_Emoji_Cluster,
         "emoji cluster text run class");
      Assert
        (Frame.Text_Runs (2).Shape_Status
           in Terminal.App.Render_Model.Shape_Ok |
              Terminal.App.Render_Model.Needs_Shaping_Backend,
         "emoji cluster text run shape status");
      Assert
        (Frame.Text_Runs (2).Direction =
           Terminal.App.Render_Model.Direction_Left_To_Right,
         "emoji cluster text run direction");
      Assert
        (Frame.Text_Runs (2).Script =
           Terminal.App.Render_Model.Script_Emoji,
         "emoji cluster text run script");
      Assert
        ((Frame.Text_Runs (2).Shape_Status =
            Terminal.App.Render_Model.Shape_Ok
          and then not Frame.Text_Runs (2).Fallback_Glyphs
          and then Frame.Text_Runs (2).Shaped_Glyph_Count > 0)
         or else
           (Frame.Text_Runs (2).Shape_Status =
              Terminal.App.Render_Model.Needs_Shaping_Backend
            and then Frame.Text_Runs (2).Fallback_Glyphs
            and then Frame.Text_Runs (2).Shaped_Glyph_Count = 0),
         "emoji cluster shaped/fallback state");
      Assert (not Saw_ZWJ, "emoji cluster render should skip ZWJ");
      declare
         Diag : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
      begin
         Assert
           (Diag.Last_Text_Run_Count = Frame.Text_Run_Count,
            "renderer diagnostics should report text run count");
         Assert
           (Diag.Last_Color_Glyph_Count > 0,
            "renderer diagnostics should report emitted color emoji glyphs");
         Assert
           (Diag.Last_Color_Emoji_Fallback_Count = 0,
            "color emoji should not fall back when a color font is available");
         Assert
           (Frame.Colour_Glyph_Count = Diag.Last_Color_Glyph_Count,
            "renderer diagnostics should report emitted color glyphs");
         Assert
           (Frame.Colour_Sheet_Width > 0
              and then Frame.Colour_Sheet_Height > 0
              and then Frame.Colour_Sheet_Pixels /= System.Null_Address,
            "color emoji render should expose a color sheet");
         if Frame.Text_Runs (2).Fallback_Glyphs then
            Assert
              (Diag.Last_Text_Fallback_Run_Count = 1,
               "renderer diagnostics should report emoji fallback run");
            Assert
              (Diag.Last_Shaping_Fallback_Count = 1,
               "renderer diagnostics should report emoji backend need");
         else
            Assert
              (Diag.Last_Text_Fallback_Run_Count = 0,
               "renderer diagnostics should report no emoji fallback run");
            Assert
              (Diag.Last_Shaping_Fallback_Count = 0,
               "renderer diagnostics should report no emoji backend need");
         end if;
      end;
   end;

   Terminal.Core.Initialize (T, 1, 3, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "simple text run core initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes (Character'Val (16#1B#) & "[?25labc"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "simple text run feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "simple text run render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert (Frame.Text_Run_Count = 1, "simple text should coalesce");
      Assert
        (Frame.Text_Runs (1).Codepoint_Count = 3,
         "simple text run codepoint count");
      Assert
        (Frame.Text_Runs (1).Run_Kind =
           Terminal.App.Render_Model.Simple_Text,
         "simple text run class");
      Assert
        (Frame.Text_Runs (1).Shape_Status =
           Terminal.App.Render_Model.Shape_Ok,
         "simple text run shape status");
      Assert
        (Frame.Text_Runs (1).Direction =
           Terminal.App.Render_Model.Direction_Left_To_Right,
         "simple text run direction");
      Assert
        (Frame.Text_Runs (1).Script =
           Terminal.App.Render_Model.Script_Latin,
         "simple text run script");
      Assert
        (Frame.Text_Runs (1).Shaped_Glyph_Count = 3,
         "simple text shaped glyph count");
      Assert
        (Frame.Text_Runs (1).Cell_Span = 3,
         "simple text run should span all cells");
      Assert_Close
        (Frame.Text_Runs (1).Cell_Width,
         Float (Terminal.App.Renderer.Cell_Width (R)),
         "simple text run cell width should be one grid cell");
      Assert
        (Frame.Glyph_Count = Natural (Frame.Text_Runs (1).Shaped_Glyph_Count),
         "simple shaped text should not draw covered fallback cells");
      declare
         Diag : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
      begin
         Assert
           (Diag.Last_Shaped_Glyph_Count = 3,
            "simple text renderer shaped glyph diagnostic count");
      end;
      Assert
        (not Frame.Text_Runs (1).Fallback_Glyphs,
         "simple text should not need glyph fallback");
   end;

   Terminal.Core.Initialize (T, 1, 4, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "neutral latin run core initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes (Character'Val (16#1B#) & "[?25l(ab)"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "neutral latin run feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "neutral latin run render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert
        (Frame.Text_Run_Count = 1,
         "neutral punctuation should join surrounding latin run");
      Assert
        (Frame.Text_Runs (1).Codepoint_Count = 4,
         "neutral latin run codepoint count");
      Assert
        (Frame.Text_Runs (1).Direction =
           Terminal.App.Render_Model.Direction_Left_To_Right,
         "neutral latin run direction");
      Assert
        (Frame.Text_Runs (1).Script =
           Terminal.App.Render_Model.Script_Latin,
         "neutral latin run script");
   end;

   Terminal.Core.Initialize (T, 1, 3, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "neutral mixed run core initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => Byte (Character'Pos ('(')),
       2 => Byte (Character'Pos ('a')),
       3 => 16#D7#,
       4 => 16#90#),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "neutral mixed run feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "neutral mixed run render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert
        (Frame.Text_Run_Count = 2,
         "neutral punctuation must not merge conflicting scripts");
      Assert
        (Frame.Text_Runs (1).Codepoint_Count = 2,
         "neutral mixed first run codepoint count");
      Assert
        (Frame.Text_Runs (1).Script = Terminal.App.Render_Model.Script_Latin,
         "neutral mixed first run script");
      Assert
        (Frame.Text_Runs (2).Script = Terminal.App.Render_Model.Script_Hebrew,
         "neutral mixed second run script");
      Assert
        (Frame.Text_Runs (2).Direction =
           Terminal.App.Render_Model.Direction_Right_To_Left,
         "neutral mixed second run direction");
   end;

   Terminal.Core.Initialize (T, 1, 4, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "RTL digit split core initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => 16#D7#,
       2 => 16#90#,
       3 => Byte (Character'Pos ('1')),
       4 => Byte (Character'Pos ('2')),
       5 => 16#D7#,
       6 => 16#91#),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "RTL digit split feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "RTL digit split render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
      Diag : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
   begin
      Assert
        (Frame.Text_Run_Count = 3,
         "ASCII digits should split from neighboring RTL runs");
      Assert
        (Frame.Text_Runs (1).Direction =
           Terminal.App.Render_Model.Direction_Right_To_Left,
         "RTL digit split first direction");
      Assert
        (Frame.Text_Runs (2).Codepoint_Count = 2,
         "RTL digit split digit run count");
      Assert
        (Frame.Text_Runs (2).Direction =
           Terminal.App.Render_Model.Direction_Left_To_Right,
         "RTL digit split digit direction");
      Assert
        (Frame.Text_Runs (2).Script =
           Terminal.App.Render_Model.Script_Common,
         "RTL digit split digit script");
      Assert
        (Frame.Text_Runs (3).Direction =
           Terminal.App.Render_Model.Direction_Right_To_Left,
         "RTL digit split third direction");
      Assert
        (Frame.Text_Runs (3).X < Frame.Text_Runs (2).X
         and then Frame.Text_Runs (2).X < Frame.Text_Runs (1).X,
         "mixed RTL paragraph should be visually reordered");
      Assert
        (Diag.Last_Paragraph_Bidi_Fallback_Count = 0,
         "mixed LTR/RTL row should not report paragraph BiDi fallback");
   end;

   Terminal.Core.Initialize (T, 1, 4, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "ligature text run core initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes (Character'Val (16#1B#) & "[?25lfile"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "ligature text run feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "ligature text run render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
      Diag  : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
   begin
      Assert (Frame.Text_Run_Count = 1, "ligature text should coalesce");
      Assert
        (Frame.Text_Runs (1).Codepoint_Count = 4,
         "ligature text run codepoint count");
      Assert
        (Frame.Text_Runs (1).Run_Kind =
           Terminal.App.Render_Model.Ligature_Candidate,
         "ligature text run class");
      Assert
        (Frame.Text_Runs (1).Shape_Status =
           Terminal.App.Render_Model.Shape_Ok,
         "ligature text run shape status");
      Assert
        (Frame.Text_Runs (1).Direction =
           Terminal.App.Render_Model.Direction_Left_To_Right,
         "ligature text run direction");
      Assert
        (Frame.Text_Runs (1).Script =
           Terminal.App.Render_Model.Script_Latin,
         "ligature text run script");
      Assert
        (Frame.Text_Runs (1).Shaped_Glyph_Count > 0,
         "ligature text shaped glyph count");
      Assert
        (not Frame.Text_Runs (1).Fallback_Glyphs,
         "ligature text should not use glyph fallback");
      Assert
        (Diag.Last_Shaping_Fallback_Count = 0,
         "ligature fallback diagnostic count");
   end;

   Terminal.Core.Initialize (T, 1, 1, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "missing scalar text run core initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => 16#F4#, 2 => 16#8F#, 3 => 16#BF#, 4 => 16#BF#),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "missing scalar feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "missing scalar render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
      Diag  : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
   begin
      Assert (Frame.Text_Run_Count = 1, "missing scalar text run count");
      Assert
        (Frame.Text_Runs (1).Shape_Status =
           Terminal.App.Render_Model.Shape_Ok,
         "missing scalar should remain renderable");
      Assert
        (Frame.Text_Runs (1).Fallback_Glyphs,
         "missing scalar should use codepoint fallback");
      Assert
        (Frame.Text_Runs (1).Shaped_Glyph_Count = 0,
         "missing scalar should not draw notdef shaped glyph");
      Assert
        (Diag.Last_Text_Fallback_Run_Count = 1,
         "renderer diagnostics should count fallback text run");
      Assert
        (Diag.Last_Shaping_Fallback_Count = 0,
         "simple missing scalar should not count as backend-needed");
   end;

   Terminal.Core.Initialize (T, 1, 3, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "mixed script text run core initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => Byte (Character'Pos ('a')),
       2 => 16#D7#,
       3 => 16#90#,
       4 => Byte (Character'Pos ('b'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "mixed script text run feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "mixed script text run render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert
        (Frame.Text_Run_Count = 3,
         "mixed script row should split shaping runs");
      Assert
        (Frame.Text_Runs (1).Script = Terminal.App.Render_Model.Script_Latin,
         "mixed script first run script");
      Assert
        (Frame.Text_Runs (2).Script = Terminal.App.Render_Model.Script_Hebrew,
         "mixed script second run script");
      Assert
        (Frame.Text_Runs (2).Direction =
           Terminal.App.Render_Model.Direction_Right_To_Left,
         "mixed script second run direction");
      Assert
        (Frame.Text_Runs (3).Script = Terminal.App.Render_Model.Script_Latin,
         "mixed script third run script");
   end;

   Terminal.Core.Initialize (T, 1, 2, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "RTL shaped run core initialize failed");
   Terminal.Core.Feed
     (T,
      (1  => Byte (Character'Pos (Character'Val (16#1B#))),
       2  => Byte (Character'Pos ('[')),
       3  => Byte (Character'Pos ('?')),
       4  => Byte (Character'Pos ('2')),
       5  => Byte (Character'Pos ('5')),
       6  => Byte (Character'Pos ('l')),
       7  => 16#D7#,
       8  => 16#90#,
       9  => 16#D7#,
       10 => 16#91#),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "RTL shaped run feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "RTL shaped run render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert (Frame.Text_Run_Count = 1, "RTL text should coalesce");
      Assert
        (Frame.Text_Runs (1).Direction =
           Terminal.App.Render_Model.Direction_Right_To_Left,
         "RTL text run direction");
      Assert
        (Frame.Text_Runs (1).Shape_Status =
           Terminal.App.Render_Model.Shape_Ok,
         "RTL text run shape status");
      Assert
        (Frame.Text_Runs (1).Cell_Span = 2,
         "RTL text run should span both cells");
      Assert_Close
        (Frame.Text_Runs (1).Cell_Width,
         Float (Terminal.App.Renderer.Cell_Width (R)),
         "RTL text run cell width should be one grid cell");
      Assert
        (Frame.Glyph_Count >= 2,
         "RTL shaped run should draw at least two glyphs");
      Assert
        (Frame.Glyphs (1).X > Frame.Glyphs (2).X,
         "RTL shaped run should place first shaped glyph to the right");
      Assert
        (Frame.Glyphs (1).X >
           Frame.Text_Runs (1).X + Frame.Text_Runs (1).Cell_Width - 1.0,
         "RTL shaped run should start from full run right edge");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "_Ga=d,d=R,x=0,y=4294967295;" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "quota reset feed failed");
   Render_And_Complete_Graphics (T);
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "quota reset render failed");

   for Offset in 0 .. Terminal.App.Renderer.Max_Kitty_Image_Objects + 9 loop
      declare
         ID : constant Natural := 10_000 + Offset;
         Payload : constant String :=
           "Gq=2,a=t,i=" & Trimmed_Natural (ID)
           & ",f=32,s=1,v=1;/wAA/w==";
      begin
         Terminal.Core.Feed
           (T,
            To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
            Feed_Status);
         Assert (Feed_Status = Terminal.Core.Ok, "quota object feed failed");
         Render_And_Complete_Graphics (T);
         Assert
           (Render_Status = Terminal.App.Renderer.Ok,
            "quota object render failed");
      end;
   end loop;

   declare
      Diag : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
   begin
      Assert
        (Diag.Kitty_Image_Object_Count =
           Terminal.App.Renderer.Max_Kitty_Image_Objects,
         "kitty image-object count quota");
      Assert
        (Diag.Kitty_Image_Object_Bytes =
           Terminal.App.Renderer.Max_Kitty_Image_Objects * 4,
         "kitty decoded-image byte accounting");
      Assert
        (Diag.Kitty_Placement_Count = 0,
         "transmit-only quota test should not create placements");
   end;

   Terminal.App.Renderer.Finalize (R);
   Terminal.App.Renderer.Finalize (R);

   declare
      Diag : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
   begin
      Assert (not Diag.Initialized, "finalized renderer initialized flag");
      Assert (Diag.Last_Rectangle_Count = 0, "finalized rectangle count");
      Assert (Diag.Last_Glyph_Count = 0, "finalized glyph count");
   end;

   Terminal.App.Renderer.Initialize_Headless (R, Status);
   Assert (Status = Terminal.App.Renderer.Ok, "renderer reinitialize failed");


   Terminal.App.Renderer.Finalize (R);
   Terminal.App.Renderer.Initialize_Headless (R, Status);
   Assert
     (Status = Terminal.App.Renderer.Ok,
      "renderer post-retry reinitialize failed");

   declare
      T1 : Terminal.Core.Terminal;
      T2 : Terminal.Core.Terminal;
      Tabs : Terminal.App.Tabs.Tab_State;
      Splits : Terminal.App.Splits.Split_State;
      Tab_Status : Terminal.App.Tabs.Tab_Status;
      Split_Status : Terminal.App.Splits.Split_Status;
      S1 : Terminal.Core.Initialize_Status;
      S2 : Terminal.Core.Initialize_Status;
      F1 : Terminal.Core.Feed_Status;
      F2 : Terminal.Core.Feed_Status;
   begin
      Terminal.Core.Initialize (T1, 1, 8, 10, S1);
      Terminal.Core.Initialize (T2, 1, 8, 10, S2);
      Assert
        (S1 = Terminal.Core.Ok and then S2 = Terminal.Core.Ok,
         "composited render core initialize failed");
      Terminal.Core.Feed (T1, To_Bytes ("pane-one"), F1);
      Terminal.Core.Feed (T2, To_Bytes ("pane-two"), F2);
      Assert
        (F1 = Terminal.Core.Ok and then F2 = Terminal.Core.Ok,
         "composited render feed failed");
      Terminal.App.Tabs.Initialize (Tabs);
      Terminal.App.Tabs.Apply (Tabs, Terminal.App.Tabs.New_Tab, Tab_Status);
      Terminal.App.Splits.Initialize (Splits);
      Terminal.App.Splits.Apply
        (Splits, Terminal.App.Splits.Split_Horizontal, Split_Status);
      Assert
        (Tab_Status = Terminal.App.Tabs.Ok
         and then Split_Status = Terminal.App.Splits.Ok,
         "composited render tab/split model failed");

      declare
         Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 2) :=
           (1 => Terminal.Core.Snapshot (T1),
            2 => Terminal.Core.Snapshot (T2));
      begin
         Terminal.App.Renderer.Render_App
           (R,
            Snaps,
            2,
            Terminal.App.Tabs.Snapshot (Tabs),
            Terminal.App.Splits.Snapshot (Splits),
            Render_Status);
         Terminal.Core.Release (Snaps (1));
         Terminal.Core.Release (Snaps (2));
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "composited render failed");

      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Frame.Height >=
            3 * Terminal.App.Renderer.Cell_Height (R)
            + Terminal.App.Renderer.Content_Margin * 4,
            "composited render should include tab strip and two panes");
         Assert
           (Frame.Rectangle_Count > 10,
            "composited render should include pane and tab chrome");
         Assert
           (Frame.Glyph_Count >= 16,
            "composited render should draw both pane labels and tab labels");
      end;
   end;

   declare
      T1 : Terminal.Core.Terminal;
      T2 : Terminal.Core.Terminal;
      S1 : Terminal.Core.Initialize_Status;
      S2 : Terminal.Core.Initialize_Status;
      F1 : Terminal.Core.Feed_Status;
      F2 : Terminal.Core.Feed_Status;
      E1 : Terminal.Core.Graphics_Event;
      E2 : Terminal.Core.Graphics_Event;
      Tabs : Terminal.App.Tabs.Tab_State;
      Splits : Terminal.App.Splits.Split_State;
      Tab_Status : Terminal.App.Tabs.Tab_Status;
      Split_Status : Terminal.App.Splits.Split_Status;
      Objects_Before : constant Natural :=
        Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count;
      Placements_Before : constant Natural :=
        Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count;

      procedure Render_Pair is
         Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 2) :=
           (1 => Terminal.Core.Snapshot (T1),
            2 => Terminal.Core.Snapshot (T2));
      begin
         Terminal.Core.Peek_Graphics_Event (T1, E1);
         Terminal.Core.Peek_Graphics_Event (T2, E2);
         Snaps (1).Graphics := E1;
         Snaps (2).Graphics := E2;
         Terminal.App.Renderer.Render_App
           (R,
            Snaps,
            2,
            Terminal.App.Tabs.Snapshot (Tabs),
            Terminal.App.Splits.Snapshot (Splits),
            Render_Status);
         Terminal.Core.Release (Snaps (1));
         Terminal.Core.Release (Snaps (2));
         Assert
           (Render_Status = Terminal.App.Renderer.Ok,
            "isolated graphics pair render");
      end Render_Pair;
   begin
      Terminal.Core.Initialize (T1, 1, 4, 10, S1);
      Terminal.Core.Initialize (T2, 1, 4, 10, S2);
      Assert
        (S1 = Terminal.Core.Ok and then S2 = Terminal.Core.Ok,
         "isolated graphics cores initialize");
      Terminal.Core.Set_Graphics_Stream_ID (T1, 1_001);
      Terminal.Core.Set_Graphics_Stream_ID (T2, 1_002);
      Terminal.App.Tabs.Initialize (Tabs);
      Terminal.App.Tabs.Apply (Tabs, Terminal.App.Tabs.New_Tab, Tab_Status);
      Terminal.App.Splits.Initialize (Splits);
      Terminal.App.Splits.Apply
        (Splits, Terminal.App.Splits.Split_Horizontal, Split_Status);
      Assert
        (Tab_Status = Terminal.App.Tabs.Ok
         and then Split_Status = Terminal.App.Splits.Ok,
         "isolated graphics pane model");

      Terminal.Core.Feed
        (T1,
         To_Bytes
           (ASCII.ESC
            & "_Gq=2,a=T,i=55,p=1,f=32,s=1,v=1,c=1,r=1,C=1,m=1;/wAA"
            & ASCII.ESC & "\"),
         F1);
      Terminal.Core.Feed
        (T2,
         To_Bytes
           (ASCII.ESC
            & "_Gq=2,a=T,i=55,p=1,f=32,s=1,v=1,c=1,r=1,C=1,m=1;AP8A"
            & ASCII.ESC & "\"),
         F2);
      Assert
        (F1 = Terminal.Core.Ok and then F2 = Terminal.Core.Ok,
         "isolated first chunks feed");
      Render_Pair;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 0,
         "independent first chunks remain incomplete");
      Terminal.Core.Complete_Graphics_Event
        (T1, E1, Terminal.App.Renderer.Graphics_Result (R, E1));
      Terminal.Core.Complete_Graphics_Event
        (T2, E2, Terminal.App.Renderer.Graphics_Result (R, E2));
      Terminal.App.Renderer.Commit_Graphics_Events (R);

      Terminal.Core.Feed
        (T1,
         To_Bytes (ASCII.ESC & "_Gq=2,m=0;/w==" & ASCII.ESC & "\"),
         F1);
      Terminal.Core.Feed
        (T2,
         To_Bytes (ASCII.ESC & "_Gq=2,m=0;/w==" & ASCII.ESC & "\"),
         F2);
      Assert
        (F1 = Terminal.Core.Ok and then F2 = Terminal.Core.Ok,
         "isolated final chunks feed");
      Render_Pair;
      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Frame.Image_Count > 0,
            "isolated streams should render at least one image");
         Assert
           (Frame.Image_Count > 1,
            "same image ID coexists in separate streams");
         Assert
           (Frame.Image_Count = 2,
            "isolated streams should not duplicate placements");
         Assert
           (Natural (Frame.Images (1).Image_ID) = 55
            and then Natural (Frame.Images (2).Image_ID) = 55,
            "isolated images retain their protocol ID");
         Assert
           (Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 0) = 16#FF#
            and then Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 1) = 16#00#
            and then Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (2), 0, 0) = 16#00#
            and then Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (2), 0, 1) = 16#FF#,
            "same-ID stream images retain distinct pixels");
      end;
      Terminal.Core.Complete_Graphics_Event
        (T1, E1, Terminal.App.Renderer.Graphics_Result (R, E1));
      Terminal.Core.Complete_Graphics_Event
        (T2, E2, Terminal.App.Renderer.Graphics_Result (R, E2));
      Terminal.App.Renderer.Commit_Graphics_Events (R);

      Terminal.Core.Feed
        (T1,
         To_Bytes
           (ASCII.ESC & "_Gq=2,a=d,d=I,i=55" & ASCII.ESC & "\"),
         F1);
      declare
         Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 2) :=
           (1 => Terminal.Core.Snapshot (T1),
            2 => Terminal.Core.Snapshot (T2));
      begin
         Terminal.Core.Peek_Graphics_Event (T1, E1);
         Snaps (1).Graphics := E1;
         Snaps (2).Graphics := (others => <>);
         Terminal.App.Renderer.Render_App
           (R,
            Snaps,
            2,
            Terminal.App.Tabs.Snapshot (Tabs),
            Terminal.App.Splits.Snapshot (Splits),
            Render_Status);
         Terminal.Core.Release (Snaps (1));
         Terminal.Core.Release (Snaps (2));
      end;
      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Render_Status = Terminal.App.Renderer.Ok
            and then Frame.Image_Count = 1
            and then Natural (Frame.Images (1).Image_ID) = 55
            and then Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 1) = 16#FF#,
            "deleting one stream preserves same-ID image in another");
      end;
      Terminal.Core.Complete_Graphics_Event
        (T1, E1, Terminal.App.Renderer.Graphics_Result (R, E1));
      Terminal.App.Renderer.Commit_Graphics_Events (R);
      Terminal.App.Renderer.Release_Graphics_Stream (R, 1_001);
      Terminal.App.Renderer.Release_Graphics_Stream (R, 1_002);
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
           Objects_Before
         and then
           Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count =
             Placements_Before,
         "closing streams releases their graphics resources");
      Terminal.Core.Finalize (T1);
      Terminal.Core.Finalize (T2);
   end;

   declare
      Screen_T : Terminal.Core.Terminal;
      Screen_Init : Terminal.Core.Initialize_Status;
      Screen_Feed : Terminal.Core.Feed_Status;
      Event : Terminal.Core.Graphics_Event;
      Objects_Before : constant Natural :=
        Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count;
      Placements_Before : constant Natural :=
        Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count;

      procedure Render_Current is
         Snapshot : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Screen_T);
      begin
         Terminal.Core.Peek_Graphics_Event (Screen_T, Event);
         Snapshot.Graphics := Event;
         Terminal.App.Renderer.Render (R, Snapshot, Render_Status);
         Terminal.Core.Release (Snapshot);
         Assert
           (Render_Status = Terminal.App.Renderer.Ok,
            "screen-owned graphics render");
         if Event.Pending then
            Terminal.Core.Complete_Graphics_Event
              (Screen_T,
               Event,
               Terminal.App.Renderer.Graphics_Result (R, Event));
            Terminal.App.Renderer.Commit_Graphics_Events (R);
         end if;
      end Render_Current;
   begin
      Terminal.Core.Initialize (Screen_T, 2, 4, 10, Screen_Init);
      Assert (Screen_Init = Terminal.Core.Ok, "screen-owned core initialize");
      Terminal.Core.Set_Graphics_Stream_ID (Screen_T, 2_001);

      Terminal.Core.Feed
        (Screen_T,
         To_Bytes
           (ASCII.ESC
            & "_Gq=2,a=T,i=70,p=1,f=32,s=1,v=1,c=1,r=1,C=1;/wAA/w=="
            & ASCII.ESC & "\"),
         Screen_Feed);
      Assert (Screen_Feed = Terminal.Core.Ok, "primary placement feed");
      Render_Current;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1,
         "primary placement visible on primary screen");

      Terminal.Core.Feed
        (Screen_T, To_Bytes (ASCII.ESC & "[?1049h"), Screen_Feed);
      Render_Current;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 0,
         "primary placement hidden on alternate screen");

      Terminal.Core.Feed
        (Screen_T,
         To_Bytes
           (ASCII.ESC
            & "_Gq=2,a=T,i=71,p=1,f=32,s=1,v=1,c=1,r=1,C=1;AP8A/w=="
            & ASCII.ESC & "\"),
         Screen_Feed);
      Assert (Screen_Feed = Terminal.Core.Ok, "alternate placement feed");
      Render_Current;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1
         and then Natural
           (Terminal.App.Renderer.Testing.Last_Frame (R).Images (1).Image_ID) = 71,
         "alternate placement visible only on alternate screen");

      Terminal.Core.Feed
        (Screen_T, To_Bytes (ASCII.ESC & "[?1049l"), Screen_Feed);
      Render_Current;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1
         and then Natural
           (Terminal.App.Renderer.Testing.Last_Frame (R).Images (1).Image_ID) = 70,
         "leaving alternate restores primary placement");

      Terminal.Core.Feed
        (Screen_T, To_Bytes (ASCII.ESC & "[?1049h"), Screen_Feed);
      Render_Current;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 0,
         "alternate re-entry clears its old placements");

      Terminal.Core.Feed
        (Screen_T,
         To_Bytes (ASCII.ESC & "[?1049l" & ASCII.ESC & "[2J"),
         Screen_Feed);
      Render_Current;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 0,
         "full-screen erase clears primary placements");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
           Objects_Before + 2
         and then
           Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count =
             Placements_Before,
         "screen clears retain image data but retire placements");

      Terminal.App.Renderer.Release_Graphics_Stream (R, 2_001);
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
           Objects_Before
         and then
           Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count =
             Placements_Before,
         "screen-owned stream cleanup releases retained image data");
      Terminal.Core.Finalize (Screen_T);
   end;

   declare
      Scroll_T : Terminal.Core.Terminal;
      Scroll_Init : Terminal.Core.Initialize_Status;
      Scroll_Feed : Terminal.Core.Feed_Status;
      Event : Terminal.Core.Graphics_Event;
      Tabs : Terminal.App.Tabs.Tab_State;
      Splits : Terminal.App.Splits.Split_State;
      Initial_Y : Float := 0.0;

      procedure Render_Event is
         Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
         Result : Terminal.Core.Kitty_Graphics_Result;
      begin
         Terminal.Core.Peek_Graphics_Event (Scroll_T, Event);
         Snaps (1) := Terminal.Core.Snapshot (Scroll_T);
         Snaps (1).Graphics := Event;
         Terminal.App.Renderer.Render_App
           (R,
            Snaps,
            1,
            Terminal.App.Tabs.Snapshot (Tabs),
            Terminal.App.Splits.Snapshot (Splits),
            Render_Status);
         Assert
           (Render_Status = Terminal.App.Renderer.Ok,
            "scrolling placement event render");
         Result := Terminal.App.Renderer.Graphics_Result (R, Event);
         Assert
           (Result.Code = Terminal.Core.Kitty_OK,
            "scrolling placement event result");
         Terminal.Core.Complete_Graphics_Event (Scroll_T, Event, Result);
         Terminal.App.Renderer.Commit_Graphics_Events (R);
         Terminal.Core.Release (Snaps (1));
      end Render_Event;

      procedure Render_Live is
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (Scroll_T);
      begin
         Snap.Graphics := (others => <>);
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
         Assert
           (Render_Status = Terminal.App.Renderer.Ok,
            "scrolling placement live render");
      end Render_Live;
   begin
      Terminal.Core.Initialize (Scroll_T, 3, 3, 10, Scroll_Init);
      Assert (Scroll_Init = Terminal.Core.Ok, "scroll graphics initialize");
      Terminal.Core.Set_Graphics_Stream_ID (Scroll_T, 2_050);
      Terminal.App.Tabs.Initialize (Tabs);
      Terminal.App.Splits.Initialize (Splits);
      Terminal.Core.Feed
        (Scroll_T,
         To_Bytes
           (ASCII.ESC & "[2;1H"
            & ASCII.ESC
            & "_Gq=2,a=T,i=80,f=32,s=1,v=2,c=1,r=2,C=1;"
            & "/wAA//8AAP8="
            & ASCII.ESC & "\"),
         Scroll_Feed);
      Assert (Scroll_Feed = Terminal.Core.Ok, "scroll graphics placement feed");
      Render_Event;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1,
         "scrolling placement initially visible");
      Initial_Y := Terminal.App.Renderer.Testing.Last_Frame (R).Images (1).Y;

      Terminal.Core.Feed
        (Scroll_T,
         To_Bytes (ASCII.ESC & "[3;1H" & ASCII.LF),
         Scroll_Feed);
      Render_Live;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1
         and then Terminal.App.Renderer.Testing.Last_Frame (R).Images (1).Y =
           Initial_Y - Float (Terminal.App.Renderer.Cell_Height (R)),
         "full-screen scroll moves conventional placement with text");

      --  Move the placement wholly into history before exercising clears.
      Terminal.Core.Feed
        (Scroll_T, To_Bytes ("" & ASCII.LF), Scroll_Feed);
      Render_Live;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1
         and then Terminal.App.Renderer.Testing.Last_Frame (R).Images (1).Y =
           Float (Terminal.App.Renderer.Content_Margin)
         and then Terminal.App.Renderer.Testing.Last_Frame (R).Images (1).Height <
           Float (Terminal.App.Renderer.Cell_Width (R) * 2),
         "placement crossing the viewport edge is clipped");

      declare
         History : Terminal.Core.Render_Snapshot :=
           Terminal.App.Scrollback_View.Snapshot (Scroll_T, 1);
      begin
         History.Graphics := (others => <>);
         Terminal.App.Renderer.Render (R, History, Render_Status);
         Terminal.Core.Release (History);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok
         and then Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1
         and then Terminal.App.Renderer.Testing.Last_Frame (R).Images (1).Height =
           Float (Terminal.App.Renderer.Cell_Width (R) * 2),
         "scrollback navigation restores the full retained placement");

      Terminal.Core.Feed
        (Scroll_T, To_Bytes ("" & ASCII.LF), Scroll_Feed);
      Render_Live;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 0,
         "fully scrolled placement leaves the live viewport");

      Terminal.Core.Feed
        (Scroll_T, To_Bytes (ASCII.ESC & "[2J"), Scroll_Feed);
      Render_Live;
      declare
         History : Terminal.Core.Render_Snapshot :=
           Terminal.App.Scrollback_View.Snapshot (Scroll_T, 2);
      begin
         History.Graphics := (others => <>);
         Terminal.App.Renderer.Render (R, History, Render_Status);
         Terminal.Core.Release (History);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok
         and then Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1,
         "viewport erase preserves a placement retained in scrollback");

      Terminal.Core.Feed
        (Scroll_T,
         To_Bytes (ASCII.ESC & "_Gq=2,a=d,d=a" & ASCII.ESC & "\"),
         Scroll_Feed);
      Render_Event;
      declare
         History : Terminal.Core.Render_Snapshot :=
           Terminal.App.Scrollback_View.Snapshot (Scroll_T, 2);
      begin
         History.Graphics := (others => <>);
         Terminal.App.Renderer.Render (R, History, Render_Status);
         Terminal.Core.Release (History);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok
         and then Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1,
         "d=a preserves placements that are visible only in scrollback");

      declare
         History_Placements : constant Natural :=
           Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count;
      begin
         Terminal.Core.Feed
           (Scroll_T,
            To_Bytes
              (ASCII.ESC & "[2;1H"
               & ASCII.ESC & "_Gq=2,a=p,i=80,C=1,c=1,r=1"
               & ASCII.ESC & "\"),
            Scroll_Feed);
         Render_Event;
         Assert
           (Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count =
              History_Placements + 1,
            "positional-delete fixture placement is installed");

         Terminal.Core.Feed
           (Scroll_T,
            To_Bytes
              (ASCII.ESC & "[3;1H" & ASCII.LF
               & ASCII.ESC & "_Gq=2,a=d,d=p,x=1,y=1"
               & ASCII.ESC & "\"),
            Scroll_Feed);
         Render_Event;
         Assert
           (Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count =
              History_Placements,
            "positional delete observes scrolling preceding its command");
      end;

      Terminal.App.Renderer.Release_Graphics_Stream (R, 2_050);
      Terminal.Core.Finalize (Scroll_T);
   end;

   Terminal.App.Renderer.Finalize (R);
end Renderer_Metrics_Smoke;
