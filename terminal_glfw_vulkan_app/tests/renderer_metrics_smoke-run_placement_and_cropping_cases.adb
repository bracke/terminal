separate (Renderer_Metrics_Smoke)
procedure Run_Placement_And_Cropping_Cases (Context : in out Suite_Context) is
   R : Terminal.App.Renderer.Renderer renames Context.Renderer;
   T : Terminal.Core.Terminal renames Context.Core;
   Feed_Status : Terminal.Core.Feed_Status renames Context.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status renames Context.Render_Status;
begin
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
      Render_And_Complete_Graphics (Context, T);
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
      Render_And_Complete_Graphics (Context, T);
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
   Render_And_Complete_Graphics (Context, T);
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

         Render_And_Complete_Graphics (Context, T);
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
      Render_And_Complete_Graphics (Context, T);
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
   Render_And_Complete_Graphics (Context, T);
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
   Render_And_Complete_Graphics (Context, T);
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
   Render_And_Complete_Graphics (Context, T);
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
   Render_And_Complete_Graphics (Context, T);
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
   Render_And_Complete_Graphics (Context, T);
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
   Render_And_Complete_Graphics (Context, T);
   Assert
     (Render_Status = Terminal.App.Renderer.Ok
      and then Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 2,
      "multiple conventional Kitty placements should coexist");
end Run_Placement_And_Cropping_Cases;
