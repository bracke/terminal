separate (Renderer_Metrics_Smoke)
procedure Run_Encoded_And_Sixel_Cases (Context : in out Suite_Context) is
   R : Terminal.App.Renderer.Renderer renames Context.Renderer;
   T : Terminal.Core.Terminal renames Context.Core;
   Feed_Status : Terminal.Core.Feed_Status renames Context.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status renames Context.Render_Status;
begin
   declare
      Payload : constant String :=
        "Gf=100,a=T,C=1,c=1,r=1;iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "kitty PNG image feed failed");
      Render_And_Complete_Graphics (Context, T);
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

   Terminal.App.Renderer.Graphics.Release_Stream (R, 4_106);
   Terminal.Core.Set_Graphics_Stream_ID (T, 4_107);

   declare
      First_Chunk : constant String :=
        "Gf=100,a=T,C=1,c=1,r=1,m=1;iVBORw0KGgoAAAANSUhEUgAA";
      Middle_Chunk : constant String :=
        "Gm=1;AAEAAAABCAIAAACQd1PeAAAA";
      Last_Chunk : constant String :=
        "Gm=0;DElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & First_Chunk & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "chunked kitty PNG first chunk feed failed");

      Render_And_Complete_Graphics (Context, T);
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

      Render_And_Complete_Graphics (Context, T);
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

      Render_And_Complete_Graphics (Context, T);
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
            and then Frame.Images (1).Encoded_Source_Bytes = null
            and then Frame.Images (1).Encoded_Source_Length = 0,
            "chunked kitty PNG command should retain decoded pixels");
         Assert
           (not Frame.Images (1).Placeholder,
            "chunked kitty PNG command should be textured");
      end;
   end;

   Terminal.App.Renderer.Graphics.Release_Stream (R, 4_107);
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
end Run_Encoded_And_Sixel_Cases;
