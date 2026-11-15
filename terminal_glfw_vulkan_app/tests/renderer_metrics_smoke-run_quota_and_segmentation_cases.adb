with Terminal.Core.Snapshot_Editing;
separate (Renderer_Metrics_Smoke)
procedure Run_Quota_And_Segmentation_Cases (Context : in out Suite_Context) is
   R : Terminal.App.Renderer.Renderer renames Context.Renderer;
   T : Terminal.Core.Terminal renames Context.Core;
   Feed_Status : Terminal.Core.Feed_Status renames Context.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status renames Context.Render_Status;
   Core_Status : Terminal.Core.Initialize_Status renames Context.Core_Status;
begin
   declare
      Quota_R : Terminal.App.Renderer.Renderer;
      Quota_Status : Terminal.App.Renderer.Init_Status;
      Quota_T : Terminal.Core.Terminal;
      Quota_Init : Terminal.Core.Initialize_Status;
      Quota_Feed : Terminal.Core.Feed_Status;
      Event : Terminal.Core.Graphics_Event;
      Result : Terminal.Core.Graphics_Completion;
      Tabs : Terminal.App.Tabs.Tab_State;
      Splits : Terminal.App.Splits.Split_State;
      Limit_Status :
        Terminal.App.Renderer.Graphics.Resource_Limit_Update_Status;

      procedure Feed_Quota
        (Text : String;
         Expected : Terminal.Core.Graphics_Completion_Code;
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
         Terminal.Core.Snapshot (Quota_T, Snapshots (1));
         Terminal.Core.Snapshot_Editing.Set_Graphics (Snapshots (1), Event);
         Terminal.App.Renderer.Layout.Render_App
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
         Result := Terminal.App.Renderer.Graphics.Result (Quota_R, Event);
         Assert (Result.Code = Expected, Message & " result");
         Terminal.Core.Complete_Graphics_Event (Quota_T, Event, Result);
         Terminal.App.Renderer.Graphics.Commit_Visible_Events (Quota_R);
      end Feed_Quota;
   begin
      Terminal.App.Renderer.Initialize_Headless (Quota_R, Quota_Status);
      Assert (Quota_Status = Terminal.App.Renderer.Ok, "quota renderer init");
      Terminal.App.Renderer.Graphics.Set_Resource_Limits
        (Quota_R,
         (Image_Objects => 2,
          Image_Bytes   => 8,
          Placements    => 2,
          Animation_Frames => 2,
          others => <>),
         Limit_Status);
      Assert
        (Limit_Status = Terminal.App.Renderer.Graphics.Limits_Applied,
         "fresh renderer accepts configurable graphics quotas");
      Assert
        (Terminal.App.Renderer.Graphics.Resource_Limits (Quota_R) =
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
         Terminal.Core.Graphics_OK,
         "quota first image");
      Feed_Quota
        ("Gq=2,a=t,i=2,N=1,f=32,s=1,v=1;AP8A/w==",
         Terminal.Core.Graphics_OK,
         "quota transient image");
      Feed_Quota
        ("Gq=2,a=t,i=3,N=0,f=32,s=1,v=1;AAD//w==",
         Terminal.Core.Graphics_OK,
         "quota eviction image");
      Assert
        (Terminal.App.Renderer.Diagnostics (Quota_R).Kitty_Image_Object_Count = 2
         and then
           Terminal.App.Renderer.Diagnostics (Quota_R).Kitty_Image_Object_Bytes = 8,
         "quota accounting after eviction");
      Feed_Quota
        ("Gq=2,a=p,i=2,p=1,c=1,r=1,C=1",
         Terminal.Core.Graphics_ENOENT,
         "transient image evicted first");
      Feed_Quota
        ("Gq=2,a=p,i=1,p=1,c=1,r=1,C=1",
         Terminal.Core.Graphics_OK,
         "older persistent-hint image retained");
      Feed_Quota
        ("Gq=2,a=p,i=3,p=1,c=1,r=1,C=1",
         Terminal.Core.Graphics_OK,
         "new image retained");
      Feed_Quota
        ("Gq=2,a=t,i=4,N=0,f=32,s=1,v=1;/////w==",
         Terminal.Core.Graphics_ENOMEM,
         "image quota response when all objects are placed");
      Feed_Quota
        ("Gq=2,a=p,i=1,p=2,c=1,r=1,C=1",
         Terminal.Core.Graphics_ENOMEM,
         "placement quota response");

      Terminal.App.Renderer.Graphics.Release_Stream (Quota_R, 3_002);
      Terminal.Core.Finalize (Quota_T);
      Terminal.App.Renderer.Finalize (Quota_R);
   end;

   Terminal.App.Renderer.Graphics.Release_Stream (R, 4_101);
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

   Terminal.App.Renderer.Graphics.Release_Stream (R, 4_102);
   Terminal.Core.Initialize (T, 1, 1, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "large chunked raw core reinitialize failed");
   Terminal.Core.Set_Graphics_Stream_ID (T, 4_103);
end Run_Quota_And_Segmentation_Cases;
