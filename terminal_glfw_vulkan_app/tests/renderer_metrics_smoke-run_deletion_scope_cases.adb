with Terminal.Core.Snapshot_Editing;
separate (Renderer_Metrics_Smoke)
procedure Run_Deletion_Scope_Cases (Context : in out Suite_Context) is
   R : Terminal.App.Renderer.Renderer renames Context.Renderer;
   T : Terminal.Core.Terminal renames Context.Core;
   Feed_Status : Terminal.Core.Feed_Status renames Context.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status renames Context.Render_Status;
begin
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
      Terminal.Core.Snapshot_Editing.Set_Graphics (Snap, (others => <>));
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
   Render_And_Complete_Graphics (Context, T);
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


end Run_Deletion_Scope_Cases;
