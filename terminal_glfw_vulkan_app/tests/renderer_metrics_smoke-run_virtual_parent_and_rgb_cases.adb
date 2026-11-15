separate (Renderer_Metrics_Smoke)
procedure Run_Virtual_Parent_And_RGB_Cases (Context : in out Suite_Context) is
   R : Terminal.App.Renderer.Renderer renames Context.Renderer;
   T : Terminal.Core.Terminal renames Context.Core;
   Feed_Status : Terminal.Core.Feed_Status renames Context.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status renames Context.Render_Status;
   Core_Status : Terminal.Core.Initialize_Status renames Context.Core_Status;
begin
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
      Render_And_Complete_Graphics (Context, T);
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
   Render_And_Complete_Graphics (Context, T);
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
   Render_And_Complete_Graphics (Context, T);
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 1,
      "coordinate-delete setup placement failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "_Ga=d,d=q,x=1,y=1,z=4;" & ASCII.ESC & "\"),
      Feed_Status);
   Render_And_Complete_Graphics (Context, T);
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 1,
      "coordinate delete with another z-index must preserve placement");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "_Ga=d,d=Q,x=1,y=1,z=5;" & ASCII.ESC & "\"),
      Feed_Status);
   Render_And_Complete_Graphics (Context, T);
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
      Render_And_Complete_Graphics (Context, T);
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
end Run_Virtual_Parent_And_RGB_Cases;
