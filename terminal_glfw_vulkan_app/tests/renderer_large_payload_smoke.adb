with Terminal.Core.Snapshot_Editing;
with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.App.Render_Model;
with Terminal.App.Renderer;
with Terminal.App.Renderer.Graphics;
with Terminal.App.Renderer.Testing;
with Terminal.App.Splits;

procedure Renderer_Large_Payload_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Renderer.Graphics.Stage_Event_Status;
   use Terminal.Common.Bytes;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Graphics_ID;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Graphics_Completion_Code;
   use type Terminal.App.Render_Model.Image_Protocol;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;

   R             : Terminal.App.Renderer.Renderer;
   T             : Terminal.Core.Terminal;
   Init_Status   : Terminal.App.Renderer.Init_Status;
   Core_Status   : Terminal.Core.Initialize_Status;
   Feed_Status   : Terminal.Core.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status;
   Event         : Terminal.Core.Graphics_Event;
   Data_Length   : constant Natural :=
     Terminal.Core.Max_Graphics_Preview_Length + 257;
   Red_PNG_Base64 : constant String :=
     "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4"
     & "z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC";
   Padding_Length : constant Natural := Data_Length - Red_PNG_Base64'Length;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   procedure Feed (Text : String) is
   begin
      Terminal.Core.Feed (T, To_Bytes (Text), Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "large graphics payload feed");
   end Feed;
begin
   Terminal.App.Renderer.Initialize_Headless (R, Init_Status);
   Assert (Init_Status = Terminal.App.Renderer.Ok, "renderer initialize");
   Terminal.Core.Initialize (T, 1, 2, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "core initialize");
   Terminal.Core.Set_Graphics_Stream_ID (T, 3_101);

   Feed (ASCII.ESC & "]1337;MultipartFile=inline=1" & ASCII.BEL);
   Feed (ASCII.ESC & "]1337;FilePart=");
   for Chunk in 1 .. Padding_Length / 4_096 loop
      Feed ((1 .. 4_096 => ' '));
   end loop;
   Feed ((1 .. Padding_Length mod 4_096 => ' '));
   Feed (Red_PNG_Base64);
   Feed (ASCII.BEL & ASCII.ESC & "]1337;FileEnd" & ASCII.BEL);

   Terminal.Core.Peek_Graphics_Event (T, Event);
   Assert (Event.Pending, "large graphics event pending");
   declare
      Complete : constant String :=
        Terminal.Core.Graphics_Event_Payload (T, Event);
   begin
      Assert
        (Terminal.App.Renderer.Graphics.Stage_Event
           (R, Event, Complete (Complete'First .. Complete'Last - 1)) =
         Terminal.App.Renderer.Graphics.Stage_Invalid_Event,
         "payload length mismatch must fail staging");
   end;
   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.Core.Snapshot_Editing.Set_Graphics (Snap, Event);
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Invalid_Snapshot,
      "truncated previews are rejected until the complete payload is staged");
   Terminal.App.Renderer.Testing.Fail_Image_Allocation_After (R, 1);
   Assert
     (Terminal.App.Renderer.Graphics.Stage_Event
        (R, Event, Terminal.Core.Graphics_Event_Payload (T, Event)) =
      Terminal.App.Renderer.Graphics.Stage_Allocation_Failed,
      "staging allocation failure is reported");
   Terminal.App.Renderer.Testing.Fail_Image_Allocation_After (R, 2);
   Assert
     (Terminal.App.Renderer.Graphics.Stage_Event
        (R, Event, Terminal.Core.Graphics_Event_Payload (T, Event)) =
      Terminal.App.Renderer.Graphics.Stage_Allocation_Failed,
      "staging node failure releases the allocated payload");
   Terminal.App.Renderer.Testing.Fail_Image_Allocation_After (R, 0);
   Assert
     (Terminal.App.Renderer.Graphics.Stage_Event
        (R, T, Event) =
      Terminal.App.Renderer.Graphics.Stage_Stored,
      "large graphics event staged through borrowed core payload");
   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.Core.Snapshot_Editing.Set_Graphics (Snap, Event);
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   declare
      Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
      Without_Preview : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics
          (R, Include_Image_Preview => False);
   begin
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "large staged payload render status");
      Assert
        (Diagnostics.Last_Image_Protocol =
           Terminal.App.Render_Model.Image_ITerm2,
         "large staged payload image protocol");
      Assert
        (Event.Payload_Length > Terminal.Core.Max_Graphics_Preview_Length,
         "graphics event exceeds the snapshot preview");
      Assert
        (Diagnostics.Last_Image_Payload_Preview_Complete,
         "renderer consumes complete staged payload beyond snapshot preview");
      Assert
        (Diagnostics.Last_Image_Decoded_Preview_Length > 0
         and then Without_Preview.Last_Image_Decoded_Preview_Length = 0
         and then Without_Preview.Last_Image_Decoded_Preview_Bytes =
           (Without_Preview.Last_Image_Decoded_Preview_Bytes'Range => 0),
         "frame diagnostics can omit decoded preview copying");
   end;

   for I in 1 .. Terminal.App.Splits.Max_Panes + 1 loop
      declare
         Staged : Terminal.Core.Graphics_Event :=
           (Pending        => True,
            Stream_ID      => 3_200,
            Sequence       => Terminal.Core.Graphics_Event_Sequence (I),
            Payload_Length => 1,
            others         => <>);
      begin
         Assert
           (Terminal.App.Renderer.Graphics.Stage_Event (R, Staged, "x") =
              Terminal.App.Renderer.Graphics.Stage_Stored,
            "staged graphics event count remains within the pane bound");
      end;
   end loop;
   declare
      Excess : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Stream_ID      => 3_200,
         Sequence       =>
           Terminal.Core.Graphics_Event_Sequence
             (Terminal.App.Splits.Max_Panes + 2),
         Payload_Length => 1,
         others         => <>);
   begin
      Assert
        (Terminal.App.Renderer.Graphics.Stage_Event (R, Excess, "x") =
           Terminal.App.Renderer.Graphics.Stage_Quota_Exceeded,
         "staged graphics events have an aggregate count bound");
   end;
   Terminal.App.Renderer.Graphics.Commit_Visible_Events (R);

   declare
      Visible : constant Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Stream_ID      => 3_301,
         Sequence       => 1,
         Payload_Length => 1,
         others         => <>);
      Hidden : constant Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Stream_ID      => 3_302,
         Sequence       => 1,
         Payload_Length => 1,
         others         => <>);
   begin
      Assert
        (Terminal.App.Renderer.Graphics.Stage_Event (R, Visible, "v") =
           Terminal.App.Renderer.Graphics.Stage_Stored
         and then
           Terminal.App.Renderer.Graphics.Stage_Event (R, Hidden, "h") =
             Terminal.App.Renderer.Graphics.Stage_Stored,
         "visible and hidden event payloads are staged together");
      Terminal.App.Renderer.Graphics.Commit_Offscreen_Event (R, Hidden);
      Assert
        (Terminal.App.Renderer.Graphics.Stage_Event (R, Visible, "v") =
           Terminal.App.Renderer.Graphics.Stage_Already_Stored,
         "offscreen commit preserves visible retry payload");
      Assert
        (Terminal.App.Renderer.Graphics.Stage_Event (R, Hidden, "h") =
           Terminal.App.Renderer.Graphics.Stage_Stored,
         "offscreen commit retires only its own payload");
      Terminal.App.Renderer.Graphics.Commit_Visible_Events (R);
   end;

   declare
      Rejected : Terminal.Core.Graphics_Event :=
        (Pending   => True,
         Protocol  => Terminal.Core.Kitty_Graphics,
         Stream_ID => 3_401,
         Sequence  => 1,
         others    => <>);
      Text : constant String := "Ga=T,q=2,i=77,I=88,p=99;AAAA";
      Result : Terminal.Core.Graphics_Completion;
   begin
      Rejected.Payload_Length := Text'Length;
      Rejected.Preview_Length := Text'Length;
      Rejected.Preview (1 .. Text'Length) := Text;
      Result := Terminal.App.Renderer.Graphics.Rejection_Result
        (Rejected, Terminal.Core.Graphics_ENOSPC);
      Assert
        (Result.Code = Terminal.Core.Graphics_ENOSPC
         and then Result.Kitty_Response.Quiet = 2
         and then Result.Kitty_Response.Image_ID = 77
         and then Result.Kitty_Response.Has_Image_Number
         and then Result.Kitty_Response.Image_Number = 88
         and then Result.Kitty_Response.Has_Placement_ID
         and then Result.Kitty_Response.Placement_ID = 99
         and then Result.Kitty_Response.Respond,
         "direct rejection preserves Kitty response metadata");

      Rejected.Preview := (others => ASCII.NUL);
      Rejected.Preview_Length := 0;
      declare
         Anonymous_Text : constant String := "Ga=T,f=32,s=1,v=1;AAAA";
      begin
         Rejected.Payload_Length := Anonymous_Text'Length;
         Rejected.Preview_Length := Anonymous_Text'Length;
         Rejected.Preview (1 .. Anonymous_Text'Length) := Anonymous_Text;
      end;
      Result := Terminal.App.Renderer.Graphics.Rejection_Result
        (Rejected, Terminal.Core.Graphics_ENOSPC);
      Assert
        (Result.Code = Terminal.Core.Graphics_ENOSPC
         and then not Result.Kitty_Response.Respond,
         "anonymous transmit rejection preserves no-response policy");
   end;

   Terminal.App.Renderer.Graphics.Release_Stream (R, 3_101);
   Terminal.Core.Finalize (T);
   Terminal.App.Renderer.Finalize (R);
end Renderer_Large_Payload_Smoke;
