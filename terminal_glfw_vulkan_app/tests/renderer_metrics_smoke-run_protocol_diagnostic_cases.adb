with Terminal.Core.Snapshot_Editing;
separate (Renderer_Metrics_Smoke)
procedure Run_Protocol_Diagnostic_Cases (Context : in out Suite_Context) is
   R : Terminal.App.Renderer.Renderer renames Context.Renderer;
   T : Terminal.Core.Terminal renames Context.Core;
   Feed_Status : Terminal.Core.Feed_Status renames Context.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status renames Context.Render_Status;
begin
   declare
      Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert
        (Diagnostics.Last_Image_Protocol =
         Terminal.App.Render_Model.Image_Sixel,
         "sixel graphics image diagnostic protocol");
      Assert
        (Diagnostics.Last_Image_Raw_Format = 32
         and then Diagnostics.Last_Image_Pixel_Width = 1
         and then Diagnostics.Last_Image_Pixel_Height = 6,
         "sixel graphics image diagnostic pixel metadata");
      Assert
        (Diagnostics.Last_Image_Decoded_Preview_Length = 24,
         "sixel graphics image decoded byte length");
      Assert
        (Diagnostics.Last_Image_Decoded_Preview_Bytes (1) = 16#FF#
         and then Diagnostics.Last_Image_Decoded_Preview_Bytes (2) = 16#FF#
         and then Diagnostics.Last_Image_Decoded_Preview_Bytes (3) = 16#FF#
         and then Diagnostics.Last_Image_Decoded_Preview_Bytes (4) = 16#FF#,
         "sixel graphics first RGBA pixel");
      Assert
        (not Diagnostics.Last_Image_Placeholder,
         "sixel graphics image should be textured");
      Assert
        (Frame.Images (1).Protocol = Terminal.App.Render_Model.Image_Sixel
         and then Frame.Images (1).Raw_Format = 32
         and then Frame.Images (1).Pixel_Width = 1
         and then Frame.Images (1).Pixel_Height = 6
         and then Frame.Images (1).Decoded_Row_Stride_Bytes = 4,
         "sixel graphics command pixel metadata");
      Assert
         (Frame.Images (1).Decoded_Bytes /= null
         and then Frame.Images (1).Decoded_Source =
           Terminal.App.Render_Model.Image_Decoded_Source_Buffer
         and then Frame.Images (1).Encoded_Source_Bytes = null,
         "sixel retained command should borrow resolved palette pixels");
      Assert
        (not Frame.Images (1).Placeholder,
         "sixel graphics command should be textured");
      Assert
        (Terminal.App.Renderer.Image_Status_Label (Diagnostics) =
         Bounded_Image_Label
           ("image sixel size="
         & "1"
         & "x"
         & "6"
         & " pixels=1x6 format=32 payload=0 payload-complete preview=24/0 bytes=FFFFFFFF textured decoded"),
         "sixel graphics image diagnostic status label");
   end;

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.Core.Snapshot_Editing.Set_Graphics (Snap, (others => <>));
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "retained sixel render failed");
   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert
        (Frame.Image_Count = 1
         and then Frame.Images (1).Protocol =
           Terminal.App.Render_Model.Image_Sixel,
         "sixel image should persist after its graphics event is consumed");
   end;

   Terminal.App.Renderer.Graphics.Release_Stream (R, 4_108);

   declare
      Aux_T : Terminal.Core.Terminal;
      Aux_Init : Terminal.Core.Initialize_Status;
      Aux_Feed : Terminal.Core.Feed_Status;
      Aux_Objects_Before : constant Natural :=
        Terminal.App.Renderer.Diagnostics (R).Image_Object_Count;
      Aux_Placements_Before : constant Natural :=
        Terminal.App.Renderer.Diagnostics (R).Placement_Count;

      procedure Feed_Render_And_Discard (Text : String; Label_Text : String) is
         Event : Terminal.Core.Graphics_Event;
         Snap : Terminal.Core.Render_Snapshot;
      begin
         Terminal.Core.Feed (Aux_T, To_Bytes (Text), Aux_Feed);
         Assert (Aux_Feed = Terminal.Core.Ok, Label_Text & " feed");
         Terminal.Core.Peek_Graphics_Event (Aux_T, Event);
         Assert (Event.Pending, Label_Text & " event");
         Terminal.Core.Snapshot (Aux_T, Snap);
         Terminal.Core.Snapshot_Editing.Set_Graphics (Snap, Event);
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Assert (Render_Status = Terminal.App.Renderer.Ok, Label_Text & " render");
         Terminal.Core.Release (Snap);
         Terminal.Core.Discard_Graphics_Event (Aux_T);
      end Feed_Render_And_Discard;
   begin
      Terminal.Core.Initialize (Aux_T, 4, 10, 100, Aux_Init);
      Assert (Aux_Init = Terminal.Core.Ok, "auxiliary coexist terminal initialize");
      Terminal.Core.Set_Graphics_Stream_ID (Aux_T, 4_109);
      Feed_Render_And_Discard
        (ASCII.ESC & "Pq~" & ASCII.ESC & "\",
         "coexisting sixel image");
      Feed_Render_And_Discard
        (ASCII.ESC & "]1337;File=inline=1;doNotMoveCursor=1;width=1;height=1:"
         & "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC"
         & ASCII.BEL,
         "coexisting iTerm2 image");
      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (Aux_T);
      begin
         Terminal.Core.Snapshot_Editing.Set_Graphics (Snap, (others => <>));
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "coexisting auxiliary retained render");
      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
         Aux_Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Saw_Sixel : Boolean := False;
         Saw_ITerm2 : Boolean := False;
      begin
         for I in 1 .. Frame.Image_Count loop
            Saw_Sixel := Saw_Sixel
              or else Frame.Images (I).Protocol =
                Terminal.App.Render_Model.Image_Sixel;
            Saw_ITerm2 := Saw_ITerm2
              or else Frame.Images (I).Protocol =
                Terminal.App.Render_Model.Image_ITerm2;
         end loop;
         Assert
           (Frame.Image_Count = 2 and then Saw_Sixel and then Saw_ITerm2,
            "retained Sixel and iTerm2 images should coexist");
         Assert
           (Aux_Diagnostics.Image_Object_Count = Aux_Objects_Before + 2
            and then Aux_Diagnostics.Placement_Count =
              Aux_Placements_Before + 2
            and then Aux_Diagnostics.Kitty_Image_Object_Count =
              Aux_Diagnostics.Image_Object_Count
            and then Aux_Diagnostics.Kitty_Placement_Count =
              Aux_Diagnostics.Placement_Count,
            "shared graphics-store diagnostics are protocol-neutral");
      end;
      Terminal.App.Renderer.Graphics.Release_Stream (R, 4_109);
      Terminal.Core.Finalize (Aux_T);
   end;

   declare
      Retry_T : Terminal.Core.Terminal;
      Retry_Init : Terminal.Core.Initialize_Status;
      Retry_Feed : Terminal.Core.Feed_Status;
      Retry_Tabs : Terminal.App.Tabs.Tab_State;
      Retry_Splits : Terminal.App.Splits.Split_State;

      procedure Retry_Event (Text : String; Label_Text : String) is
         Event : Terminal.Core.Graphics_Event;
         Snapshots : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
         Objects_Before : constant Natural :=
           Terminal.App.Renderer.Diagnostics (R).Image_Object_Count;
         Placements_Before : constant Natural :=
           Terminal.App.Renderer.Diagnostics (R).Placement_Count;
      begin
         Terminal.Core.Feed (Retry_T, To_Bytes (Text), Retry_Feed);
         Assert (Retry_Feed = Terminal.Core.Ok, Label_Text & " feed");
         Terminal.Core.Peek_Graphics_Event (Retry_T, Event);
         Assert (Event.Pending, Label_Text & " event");
         Terminal.Core.Snapshot (Retry_T, Snapshots (1));
         Terminal.Core.Snapshot_Editing.Set_Graphics (Snapshots (1), Event);
         for Attempt in 1 .. 2 loop
            Terminal.App.Renderer.Layout.Render_App
              (R,
               Snapshots,
               1,
               Terminal.App.Tabs.Snapshot (Retry_Tabs),
               Terminal.App.Splits.Snapshot (Retry_Splits),
               Render_Status);
            Assert
              (Render_Status = Terminal.App.Renderer.Ok,
               Label_Text & " retry render");
            Assert
              (Terminal.App.Renderer.Diagnostics (R).Image_Object_Count =
                 Objects_Before + 1
               and then
                 Terminal.App.Renderer.Diagnostics (R).Placement_Count =
                   Placements_Before + 1,
               Label_Text & " retry does not duplicate resources");
         end loop;
         Terminal.Core.Release (Snapshots (1));
         Terminal.Core.Discard_Graphics_Event (Retry_T);
         Terminal.App.Renderer.Graphics.Commit_Visible_Events (R);
      end Retry_Event;
   begin
      Terminal.Core.Initialize (Retry_T, 4, 10, 100, Retry_Init);
      Assert (Retry_Init = Terminal.Core.Ok, "auxiliary retry initialize");
      Terminal.Core.Set_Graphics_Stream_ID (Retry_T, 4_110);
      Terminal.App.Tabs.Initialize (Retry_Tabs);
      Terminal.App.Splits.Initialize (Retry_Splits);
      Retry_Event
        (ASCII.ESC & "Pq~" & ASCII.ESC & "\",
         "Sixel presentation");
      Retry_Event
        (ASCII.ESC & "]1337;File=inline=1;doNotMoveCursor=1;width=1;height=1:"
         & "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC"
         & ASCII.BEL,
         "iTerm2 presentation");
      Terminal.App.Renderer.Graphics.Release_Stream (R, 4_110);
      Terminal.Core.Finalize (Retry_T);
   end;

end Run_Protocol_Diagnostic_Cases;
