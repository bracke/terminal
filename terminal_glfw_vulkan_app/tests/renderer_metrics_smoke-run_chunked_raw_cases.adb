separate (Renderer_Metrics_Smoke)
procedure Run_Chunked_Raw_Cases (Context : in out Suite_Context) is
   R : Terminal.App.Renderer.Renderer renames Context.Renderer;
   T : Terminal.Core.Terminal renames Context.Core;
   Feed_Status : Terminal.Core.Feed_Status renames Context.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status renames Context.Render_Status;
begin
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

      Render_And_Complete_Graphics (Context, T);
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

      Render_And_Complete_Graphics (Context, T);
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

      Render_And_Complete_Graphics (Context, T);
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

end Run_Chunked_Raw_Cases;
