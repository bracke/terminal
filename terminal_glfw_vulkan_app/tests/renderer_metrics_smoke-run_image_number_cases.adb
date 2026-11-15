separate (Renderer_Metrics_Smoke)
procedure Run_Image_Number_Cases (Context : in out Suite_Context) is
   R : Terminal.App.Renderer.Renderer renames Context.Renderer;
   T : Terminal.Core.Terminal renames Context.Core;
   Feed_Status : Terminal.Core.Feed_Status renames Context.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status renames Context.Render_Status;
   Core_Status : Terminal.Core.Initialize_Status renames Context.Core_Status;
begin
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
end Run_Image_Number_Cases;
