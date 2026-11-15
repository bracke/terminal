separate (Renderer_Metrics_Smoke)
procedure Run_Raw_And_ITerm2_Cases (Context : in out Suite_Context) is
   R : Terminal.App.Renderer.Renderer renames Context.Renderer;
   T : Terminal.Core.Terminal renames Context.Core;
   Feed_Status : Terminal.Core.Feed_Status renames Context.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status renames Context.Render_Status;
begin
   declare
      Payload : constant String :=
        "Gf=32,a=T,C=1,s=129,v=128,c=1,r=1;" & Repeat_Char ('A', 88064);
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "over-64KiB raw kitty graphics feed failed");
      Render_And_Complete_Graphics (Context, T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "over-64KiB raw graphics render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 129
            and then Diagnostics.Last_Image_Pixel_Height = 128,
            "over-64KiB raw graphics image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Length =
            Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length,
            "over-64KiB raw graphics decoded preview length");
         Assert
           (Diagnostics.Last_Image_Payload_Preview_Complete,
            "over-64KiB raw graphics payload should fit render buffer");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "over-64KiB raw graphics image should be textured");
         Assert
           (Frame.Images (1).Pixel_Width = 129
            and then Frame.Images (1).Pixel_Height = 128
            and then Frame.Images (1).Decoded_Byte_Length = 129 * 128 * 4
            and then Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Buffer
            and then Frame.Images (1).Encoded_Source_Bytes = null
            and then Frame.Images (1).Decoded_Preview_Length =
              Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length,
            "over-64KiB raw graphics command retained source metadata");
         Assert
           (not Frame.Images (1).Placeholder,
            "over-64KiB raw graphics command should be textured");
      end;
   end;

   Terminal.App.Renderer.Graphics.Release_Stream (R, 4_105);
   Terminal.Core.Set_Graphics_Stream_ID (T, 4_106);

   declare
      Payload : constant String :=
        "Gf=32,a=T,C=1,s=16385,v=1024,c=40,r=20;AAAA";
      Allocation_Failures_Before : constant Interfaces.Unsigned_64 :=
        Terminal.App.Renderer.Diagnostics (R).Allocation_Failure_Count;
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "oversized raw kitty graphics feed failed");
      Render_And_Complete_Graphics (Context, T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "oversized raw graphics render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Frame.Image_Count = 0
            and then Diagnostics.Allocation_Failure_Count =
              Allocation_Failures_Before + 1,
            "oversized raw graphics is rejected before image allocation");
      end;
   end;

   declare
      Payload : constant String :=
        "File=name=pixel.png;size=69;inline=1;doNotMoveCursor=1;width=20px;height=40px;"
        & "preserveAspectRatio=1:"
        & "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "]1337;" & Payload & ASCII.BEL),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "iTerm2 PNG image feed failed");
      Render_And_Complete_Graphics (Context, T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "iTerm2 PNG image render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Protocol =
            Terminal.App.Render_Model.Image_ITerm2,
            "iTerm2 PNG image diagnostic protocol");
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 1
            and then Diagnostics.Last_Image_Pixel_Height = 1,
            "iTerm2 PNG image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Length = 4,
            "iTerm2 PNG image decoded byte length");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Bytes (1) = 16#FF#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (2) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (3) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (4) = 16#FF#,
            "iTerm2 PNG image first RGBA pixel");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "iTerm2 PNG image should be textured");
         Assert
           (Frame.Images (1).Protocol = Terminal.App.Render_Model.Image_ITerm2
            and then Frame.Images (1).Raw_Format = 32
            and then Frame.Images (1).Pixel_Width = 1
            and then Frame.Images (1).Pixel_Height = 1
            and then Frame.Images (1).Decoded_Row_Stride_Bytes = 4
            --  The 20x20 px box of a square image, clipped to the one-cell
            --  viewport, whose size comes from whatever font the host has.
            and then Frame.Images (1).Width =
              Float'Min (20.0, Float (Terminal.App.Renderer.Cell_Width (R)))
            and then Frame.Images (1).Height =
              Float'Min (20.0, Float (Terminal.App.Renderer.Cell_Height (R))),
            "iTerm2 PNG retained command is clipped to the viewport");
         Assert
           (Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Buffer
            and then Frame.Images (1).Encoded_Source_Bytes = null
            and then Frame.Images (1).Encoded_Source_Length = 0,
            "iTerm2 PNG retained command should borrow decoded pixels");
         Assert
           (not Frame.Images (1).Placeholder,
            "iTerm2 PNG image command should be textured");
      end;
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "]1337;File=size=69;inline=1;doNotMoveCursor=1:"
         & "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC"
         & ASCII.BEL),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "iTerm2 size mismatch feed");
   Render_And_Complete_Graphics (Context, T);
   Assert
     (Render_Status = Terminal.App.Renderer.Ok
      and then Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 2,
      "iTerm2 declared size remains a non-binding progress hint");

   declare
      Cursor_T : Terminal.Core.Terminal;
      Cursor_Init : Terminal.Core.Initialize_Status;
      Cursor_Feed : Terminal.Core.Feed_Status;
      Event : Terminal.Core.Graphics_Event;
      Outcome : Terminal.Core.Graphics_Completion;
      Cursor_Tabs : Terminal.App.Tabs.Tab_State;
      Cursor_Splits : Terminal.App.Splits.Split_State;
   begin
      Terminal.Core.Initialize (Cursor_T, 4, 4, 10, Cursor_Init);
      Assert
        (Cursor_Init = Terminal.Core.Ok,
         "iTerm2 cursor renderer initialize");
      Terminal.Core.Set_Graphics_Stream_ID (Cursor_T, 4_107);
      Terminal.Core.Feed
        (Cursor_T,
         To_Bytes
           (ASCII.ESC
            & "]1337;File=inline=1;width=1;height=2;preserveAspectRatio=0:"
            & "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC"
            & ASCII.BEL & "x"),
         Cursor_Feed);
      Assert (Cursor_Feed = Terminal.Core.Ok, "iTerm2 cursor renderer feed");
      Terminal.Core.Peek_Graphics_Event (Cursor_T, Event);
      Terminal.App.Tabs.Initialize (Cursor_Tabs);
      Terminal.App.Splits.Initialize (Cursor_Splits);
      declare
         Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
      begin
         Terminal.Core.Snapshot (Cursor_T, Snaps (1));
         Terminal.App.Renderer.Layout.Render_App
           (R,
            Snaps,
            1,
            Terminal.App.Tabs.Snapshot (Cursor_Tabs),
            Terminal.App.Splits.Snapshot (Cursor_Splits),
            Render_Status);
         Terminal.Core.Release (Snaps (1));
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "iTerm2 cursor renderer render");
      Outcome := Terminal.App.Renderer.Graphics.Result (R, Event);
      Assert
        (Outcome.Code = Terminal.Core.Graphics_OK,
         "iTerm2 successful rendering produces an internal cursor commit result");
      Assert
        (Outcome.Cursor.Move and then Outcome.Cursor.To_Line_Start,
         "iTerm2 default rendering requests next-line cursor movement");
      Assert
        (Outcome.Cursor.Placement_Rows = 2,
         "iTerm2 cursor movement reflects rendered cell height");
      Terminal.Core.Complete_Graphics_Event (Cursor_T, Event, Outcome);
      Terminal.App.Renderer.Graphics.Commit_Visible_Events (R);
      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (Cursor_T);
      begin
         Assert
           (Terminal.Core.Cell_At (Snap, 3, 1).Text.Code_Point = 16#78#,
            "iTerm2 renderer commits cursor movement before trailing input");
         Terminal.Core.Release (Snap);
      end;
      Terminal.App.Renderer.Graphics.Release_Stream (R, 4_107);
      Terminal.Core.Finalize (Cursor_T);
   end;

   Terminal.App.Renderer.Graphics.Release_Stream (R, 4_106);
end Run_Raw_And_ITerm2_Cases;
