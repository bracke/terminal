separate (Renderer_Metrics_Smoke)
procedure Run_Relative_Placement_Cases (Context : in out Suite_Context) is
   R : Terminal.App.Renderer.Renderer renames Context.Renderer;
   T : Terminal.Core.Terminal renames Context.Core;
   Feed_Status : Terminal.Core.Feed_Status renames Context.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status renames Context.Render_Status;
   Core_Status : Terminal.Core.Initialize_Status renames Context.Core_Status;
begin
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
end Run_Relative_Placement_Cases;
