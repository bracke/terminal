separate (Renderer_Metrics_Smoke)
procedure Run_Large_Payload_Cases (Context : in out Suite_Context) is
   R : Terminal.App.Renderer.Renderer renames Context.Renderer;
   T : Terminal.Core.Terminal renames Context.Core;
   Feed_Status : Terminal.Core.Feed_Status renames Context.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status renames Context.Render_Status;
begin
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
               Assert
                 (Terminal.App.Renderer.Graphics.Stage_Event
                    (R, Event, Terminal.Core.Graphics_Event_Payload (T, Event)) =
                  Terminal.App.Renderer.Graphics.Stage_Stored,
                  Message & " staging failed");
            end;
         end if;

         Render_And_Complete_Graphics (Context, T);
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

   Terminal.App.Renderer.Graphics.Release_Stream (R, 4_103);
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
      Render_And_Complete_Graphics (Context, T);
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

   Terminal.App.Renderer.Graphics.Release_Stream (R, 4_104);
   Terminal.Core.Set_Graphics_Stream_ID (T, 4_105);


end Run_Large_Payload_Cases;
