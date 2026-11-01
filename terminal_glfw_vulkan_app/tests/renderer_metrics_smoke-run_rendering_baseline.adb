separate (Renderer_Metrics_Smoke)
procedure Run_Rendering_Baseline is
begin
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
   Terminal.App.Renderer.Graphics.Release_Stream (R, 0);
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

   Terminal.App.Renderer.Graphics.Release_Stream (R, 4_100);
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

end Run_Rendering_Baseline;
