with Terminal.Core.Snapshot_Editing;
with Ada.Real_Time;
with Interfaces;

with Terminal.App.Image_Media;
with Terminal.App.Render_Model;
with Terminal.App.Renderer;
with Terminal.App.Renderer.Layout;
with Terminal.App.Renderer.Graphics;
with Terminal.App.Renderer.Testing;
with Terminal.App.Splits;
with Terminal.App.Tabs;
with Terminal.App.Theme;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Renderer_Animation_Smoke is
   use type Ada.Real_Time.Time;
   use type Interfaces.Unsigned_64;
   use Terminal.Common.Bytes;
   use type Terminal.App.Image_Media.Decode_Status;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.App.Renderer.Graphics.Resource_Limit_Update_Status;
   use type Terminal.App.Renderer.Theme_Update_Status;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Graphics_Completion_Code;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   R : Terminal.App.Renderer.Renderer;
   Renderer_Status : Terminal.App.Renderer.Init_Status;
   Render_Status : Terminal.App.Renderer.Render_Status;
   Limit_Status :
     Terminal.App.Renderer.Graphics.Resource_Limit_Update_Status;
begin
   Terminal.App.Renderer.Initialize_Headless (R, Renderer_Status);
   Assert
     (Renderer_Status = Terminal.App.Renderer.Ok,
      "animation renderer initialize");

   declare
      Animation_T : Terminal.Core.Terminal;
      Animation_Init : Terminal.Core.Initialize_Status;
      Animation_Feed : Terminal.Core.Feed_Status;
      Event : Terminal.Core.Graphics_Event;
      Tabs : Terminal.App.Tabs.Tab_State;
      Splits : Terminal.App.Splits.Split_State;

      procedure Process
        (Command : String;
         Expected : Terminal.Core.Graphics_Completion_Code;
         Label_Text : String)
      is
         Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
         Result : Terminal.Core.Graphics_Completion;
      begin
         Terminal.Core.Feed
           (Animation_T,
            To_Bytes (ASCII.ESC & "_" & Command & ASCII.ESC & "\"),
            Animation_Feed);
         Assert (Animation_Feed = Terminal.Core.Ok, Label_Text & " feed");
         Terminal.Core.Peek_Graphics_Event (Animation_T, Event);
         Terminal.Core.Snapshot (Animation_T, Snaps (1));
         Terminal.Core.Snapshot_Editing.Set_Graphics (Snaps (1), Event);
         Terminal.App.Renderer.Layout.Render_App
           (R,
            Snaps,
            1,
            Terminal.App.Tabs.Snapshot (Tabs),
            Terminal.App.Splits.Snapshot (Splits),
            Render_Status);
         Terminal.Core.Release (Snaps (1));
         Assert (Render_Status = Terminal.App.Renderer.Ok, Label_Text & " render");
         Result := Terminal.App.Renderer.Graphics.Result (R, Event);
         Assert (Result.Code = Expected, Label_Text & " result");
         Terminal.Core.Complete_Graphics_Event (Animation_T, Event, Result);
         Terminal.App.Renderer.Graphics.Commit_Visible_Events (R);
      end Process;

      procedure Process_ITerm2
        (Payload : String;
         Label_Text : String)
      is
         Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
         Result : Terminal.Core.Graphics_Completion;
      begin
         Terminal.Core.Feed
           (Animation_T,
            To_Bytes
              (ASCII.ESC & "]1337;File=inline=1;doNotMoveCursor=1:"
               & Payload & ASCII.BEL),
            Animation_Feed);
         Assert (Animation_Feed = Terminal.Core.Ok, Label_Text & " feed");
         Terminal.Core.Peek_Graphics_Event (Animation_T, Event);
         Terminal.Core.Snapshot (Animation_T, Snaps (1));
         Terminal.Core.Snapshot_Editing.Set_Graphics (Snaps (1), Event);
         Terminal.App.Renderer.Layout.Render_App
           (R,
            Snaps,
            1,
            Terminal.App.Tabs.Snapshot (Tabs),
            Terminal.App.Splits.Snapshot (Splits),
            Render_Status);
         Terminal.Core.Release (Snaps (1));
         Assert (Render_Status = Terminal.App.Renderer.Ok, Label_Text & " render");
         Result := Terminal.App.Renderer.Graphics.Result (R, Event);
         Terminal.Core.Complete_Graphics_Event (Animation_T, Event, Result);
         Terminal.App.Renderer.Graphics.Commit_Visible_Events (R);
      end Process_ITerm2;

      procedure Assert_Pixel
        (X : Natural;
         Component : Natural;
         Expected : Byte;
         Label_Text : String)
      is
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
         Actual : Terminal.Common.Bytes.Byte := 0;
      begin
         Assert (Frame.Image_Count = 1, Label_Text & " image count");
         Actual := Terminal.App.Render_Model.Image_Decoded_Row_Byte
           (Frame.Images (1), 0, X * 4 + Component);
         Assert
           (Actual = Expected,
            Label_Text);
      end Assert_Pixel;

      procedure Render_Animation (Label_Text : String) is
         Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
      begin
         Terminal.Core.Snapshot (Animation_T, Snaps (1));
         Terminal.Core.Snapshot_Editing.Set_Graphics (Snaps (1), (others => <>));
         Terminal.App.Renderer.Layout.Render_App
           (R,
            Snaps,
            1,
            Terminal.App.Tabs.Snapshot (Tabs),
            Terminal.App.Splits.Snapshot (Splits),
            Render_Status);
         Terminal.Core.Release (Snaps (1));
         Assert
           (Render_Status = Terminal.App.Renderer.Ok,
            Label_Text & " render");
      end Render_Animation;
   begin
      Terminal.Core.Initialize (Animation_T, 1, 2, 10, Animation_Init);
      Assert
        (Animation_Init = Terminal.Core.Ok,
         "animation core initialize");
      Terminal.Core.Set_Graphics_Stream_ID (Animation_T, 2_102);
      Terminal.App.Tabs.Initialize (Tabs);
      Terminal.App.Splits.Initialize (Splits);

      Process
        ("Gq=2,a=T,i=90,f=32,s=2,v=1,c=2,r=1,C=1;"
         & "/wAA/wD/AP8=",
         Terminal.Core.Graphics_OK,
         "animation root");
      Assert_Pixel (0, 0, 16#FF#, "animation root red");

      Process
        ("Gq=2,a=f,i=90,f=32,s=2,v=1;AAD/////AP8=",
         Terminal.Core.Graphics_OK,
         "animation frame");
      Process
        ("Gq=2,a=f,i=90,f=32,r=2,s=2,v=1,X=1,o=z;"
         & "eJxjYPgPBAz/ARL1BPw=",
         Terminal.Core.Graphics_OK,
         "compressed animation frame edit");
      Process
        ("Gq=2,a=a,i=90,c=2",
         Terminal.Core.Graphics_OK,
         "animation select frame");
      Assert_Pixel (0, 2, 16#FF#, "animation selected blue frame");

      Process
        ("Gq=2,a=f,i=90,f=32,r=2,x=1,y=0,s=1,v=1,X=1;////gA==",
         Terminal.Core.Graphics_OK,
         "animation partial edit");
      Assert_Pixel (1, 0, 16#FF#, "animation edited red");
      Assert_Pixel (1, 3, 16#80#, "animation edited alpha");

      Process
        ("Gq=2,a=c,i=90,r=2,c=1,X=0,Y=0,x=1,y=0,w=1,h=1,C=1",
         Terminal.Core.Graphics_OK,
         "animation compose");
      Terminal.App.Renderer.Testing.Fail_Image_Allocation_After (R, 1);
      Process
        ("Gq=2,a=c,i=90,r=2,c=1,X=0,Y=0,x=1,y=0,w=1,h=1,C=1",
         Terminal.Core.Graphics_ENOMEM,
         "animation composition allocation failure");
      Process
        ("Gq=2,a=a,i=90,c=1",
         Terminal.Core.Graphics_OK,
         "animation select root");
      Assert_Pixel (0, 0, 16#FF#, "animation composed source red");
      Assert_Pixel (0, 3, 16#80#, "animation composed source alpha");
      Assert_Pixel (1, 1, 16#FF#, "animation preserves destination neighbor");

      Process
        ("Gq=2,a=f,i=90,f=32,r=2,s=2,v=1,m=1;AAD/",
         Terminal.Core.Graphics_No_Response,
         "animation first chunk");
      Process
        ("Gq=2,a=f,m=0;////AP8=",
         Terminal.Core.Graphics_OK,
         "animation final chunk");
      Process
        ("Gq=2,a=a,i=90,c=2",
         Terminal.Core.Graphics_OK,
         "animation select chunked frame");
      Assert_Pixel (1, 0, 16#FF#, "animation chunked yellow frame");

      Process
        ("Gq=2,a=a,i=90,s=3,c=1,v=1",
         Terminal.Core.Graphics_OK,
         "animation zero-gap playback");
      declare
         Hidden_At : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
         Advances : constant Interfaces.Unsigned_64 :=
           Terminal.App.Renderer.Diagnostics (R).Animation_Advance_Count;
      begin
         Terminal.App.Renderer.Testing.Hide_All_Graphics_Views (R);
         Assert
           (not Terminal.App.Renderer.Testing.Animation_Frame_Due_At
              (R, Hidden_At + Ada.Real_Time.Seconds (1)),
            "hidden animation does not request redraws");
         Terminal.App.Renderer.Testing.Advance_Animations_At
           (R, Hidden_At + Ada.Real_Time.Seconds (1));
         Assert
           (Terminal.App.Renderer.Diagnostics (R).Animation_Advance_Count =
              Advances,
            "hidden animation does not advance");
         Render_Animation ("animation view restored");
         Assert
           (Terminal.App.Renderer.Testing.Animation_Frame_Due_At
              (R, Hidden_At + Ada.Real_Time.Seconds (1)),
            "restored animation view requests its initial frame");
      end;
      declare
         Now : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      begin
         Terminal.App.Renderer.Testing.Advance_Animations_At (R, Now);
         declare
            Wait : constant Duration :=
              Terminal.App.Renderer.Testing.Animation_Wait_Duration_At
                (R, Now, 0.5);
         begin
            Assert
              (Wait >= 0.009 and then Wait <= 0.011,
               "animation wait targets its next frame deadline");
         end;
         Assert
           (not Terminal.App.Renderer.Testing.Animation_Frame_Due_At
              (R, Now + Ada.Real_Time.Milliseconds (9)),
            "zero-gap animation waits for its bounded delay");
         Assert
           (Terminal.App.Renderer.Testing.Animation_Frame_Due_At
              (R, Now + Ada.Real_Time.Milliseconds (10)),
            "zero-gap animation becomes due at its bounded delay");
      end;
      Process
        ("Gq=2,a=a,i=90,s=1",
         Terminal.Core.Graphics_OK,
         "animation zero-gap stop");

      Process
        ("Gq=2,a=a,i=90,r=1,z=-1",
         Terminal.Core.Graphics_OK,
         "animation root gap control");
      Process
        ("Gq=2,a=a,i=90,r=2,z=-1",
         Terminal.Core.Graphics_OK,
         "animation frame gap control");
      Process
        ("Gq=2,a=a,i=90,s=3,c=1,v=2",
         Terminal.Core.Graphics_OK,
         "animation finite playback");
      Render_Animation ("animation first advance");
      Assert_Pixel (1, 1, 16#FF#, "animation first loop returns to root");
      Render_Animation ("animation first loop");
      Assert_Pixel (1, 0, 16#FF#, "animation stops on final frame");
      Render_Animation ("animation stopped stability");
      Assert_Pixel (1, 0, 16#FF#, "animation stopped frame remains stable");

      Process
        ("Gq=2,a=a,i=90,s=2,c=1",
         Terminal.Core.Graphics_OK,
         "animation loading playback");
      Render_Animation ("animation loading reaches tail");
      Assert_Pixel (1, 0, 16#FF#, "animation loading tail frame");
      Process
        ("Gq=2,a=f,i=90,f=32,s=2,v=1;AP8A/wD/AP8=",
         Terminal.Core.Graphics_OK,
         "animation append while loading");
      Render_Animation ("animation loading consumes appended frame");
      Assert_Pixel (0, 1, 16#FF#, "animation loading appended green frame");

      declare
         Original : constant Terminal.App.Renderer.Graphics_Resource_Limits :=
           Terminal.App.Renderer.Graphics.Resource_Limits (R);
         Tight_Limits : Terminal.App.Renderer.Graphics_Resource_Limits :=
           Original;
      begin
         Tight_Limits.Animation_Frames := 1;
         Terminal.App.Renderer.Graphics.Set_Resource_Limits
           (R, Tight_Limits, Limit_Status);
         Assert
           (Limit_Status =
              Terminal.App.Renderer.Graphics.Limits_Applied_Overcommitted,
            "lowered limits report retained-resource overcommitment");
         Process_ITerm2
           ("R0lGODlhAQABAPAAAP8AAAAAACH/C05FVFNDQVBFMi4wAwEBAAAh+QQA"
            & "BQAAACwAAAAAAQABAAACAkQBACH5BAAHAAAALAAAAAABAAEAgAAA/wAA"
            & "AAICRAEAOw==",
            "media decode after lowering animation quota below retained use");
         Assert
           (Terminal.App.Renderer.Diagnostics (R).
              Kitty_Animation_Frame_Count = 2,
            "lowered animation quota preserves retained frame accounting");
         Assert
           (Terminal.App.Renderer.Diagnostics (R).
              Last_Media_Decode_Status =
                Terminal.App.Image_Media.Decode_Too_Large,
            "lowered animation quota reports media too large");

         Tight_Limits.Animation_Frames := 2;
         Terminal.App.Renderer.Graphics.Set_Resource_Limits
           (R, Tight_Limits, Limit_Status);
         Process
           ("Gq=2,a=f,i=90,f=32,s=2,v=1;/////wAAAP8=",
            Terminal.Core.Graphics_ENOSPC,
            "animation frame quota");
         Assert
           (Terminal.App.Renderer.Diagnostics (R).
              Kitty_Animation_Frame_Count = 2,
            "animation frame quota accounting");

         Tight_Limits.Animation_Frames := Original.Animation_Frames;
         Tight_Limits.Per_Image_Bytes := 7;
         Terminal.App.Renderer.Graphics.Set_Resource_Limits
           (R, Tight_Limits, Limit_Status);
         Process
           ("Gq=2,a=f,i=90,f=32,r=2,s=2,v=1,X=1;/////wAAAP8=",
            Terminal.Core.Graphics_ENOSPC,
            "animation decoded byte quota");
         Assert
           (Terminal.App.Renderer.Diagnostics (R).
              Kitty_Animation_Frame_Count = 2,
            "rejected animation edit preserves frame accounting");

         Tight_Limits.Per_Image_Bytes := Original.Per_Image_Bytes;
         Terminal.App.Renderer.Graphics.Set_Resource_Limits
           (R, Tight_Limits, Limit_Status);
         Process
           ("Gq=2,a=t,i=91,f=32,s=1,v=1;/wAA/w==",
            Terminal.Core.Graphics_OK,
            "unplaced image retained beside animation");
         Tight_Limits.Image_Bytes := Positive
           (Terminal.App.Renderer.Diagnostics (R).Image_Object_Bytes);
         Terminal.App.Renderer.Graphics.Set_Resource_Limits
           (R, Tight_Limits, Limit_Status);
         Process
           ("Gq=2,a=f,i=90,f=32,s=2,v=1;/////wAAAP8=",
            Terminal.Core.Graphics_ENOSPC,
            "animation persistent byte quota");
         Assert
           (Terminal.App.Renderer.Diagnostics (R).Image_Object_Count = 2,
            "rejected animation update does not evict unrelated images; count="
            & Natural'Image
                (Terminal.App.Renderer.Diagnostics (R).Image_Object_Count));
         Terminal.App.Renderer.Graphics.Set_Resource_Limits
           (R, Original, Limit_Status);
      end;

      Process
        ("Gq=2,a=a,i=90,r=1,z=30",
         Terminal.Core.Graphics_OK,
         "animation redraw deadline gap");
      Process
        ("Gq=2,a=a,i=90,s=3,c=1,v=1",
         Terminal.Core.Graphics_OK,
         "animation redraw deadline playback");
      declare
         Now : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
         Stale : constant Ada.Real_Time.Time :=
           Now + Ada.Real_Time.Milliseconds (200);
      begin
         Assert
           (Terminal.App.Renderer.Testing.Animation_Frame_Due_At (R, Now),
            "new animation schedules deadline initialization");
         Terminal.App.Renderer.Testing.Advance_Animations_At (R, Now);
         Assert
           (not Terminal.App.Renderer.Testing.Animation_Frame_Due_At
              (R, Now + Ada.Real_Time.Milliseconds (29)),
            "animation redraw waits for its frame deadline");
         Assert
           (Terminal.App.Renderer.Testing.Animation_Frame_Due_At
              (R, Now + Ada.Real_Time.Milliseconds (30)),
            "animation becomes due at its frame deadline");
         Terminal.App.Renderer.Testing.Advance_Animations_At
           (R, Now + Ada.Real_Time.Milliseconds (30));
         Assert
           (Terminal.App.Renderer.Testing.Animation_Frame_Due_At (R, Stale),
            "stale animation deadline requests a catch-up redraw");
         Terminal.App.Renderer.Testing.Advance_Animations_At (R, Stale);
         Assert
           (not Terminal.App.Renderer.Testing.Animation_Frame_Due_At
              (R, Stale),
            "animation catch-up leaves a future deadline");

         Process
           ("Gq=2,a=a,i=90,r=2,z=20",
            Terminal.Core.Graphics_OK,
            "animation finite second-frame gap");
         Process
           ("Gq=2,a=a,i=90,r=3,z=10",
            Terminal.Core.Graphics_OK,
            "animation finite third-frame gap");
         Process
           ("Gq=2,a=a,i=90,s=3,c=1,v=2",
            Terminal.Core.Graphics_OK,
            "animation finite stale playback");
         declare
            Finite_Start : constant Ada.Real_Time.Time :=
              Stale + Ada.Real_Time.Seconds (1);
         begin
            Terminal.App.Renderer.Testing.Advance_Animations_At
              (R, Finite_Start);
            Terminal.App.Renderer.Testing.Advance_Animations_At
              (R, Finite_Start + Ada.Real_Time.Milliseconds (90));
            Assert
              (not Terminal.App.Renderer.Testing.Animation_Frame_Due_At
                 (R, Finite_Start + Ada.Real_Time.Milliseconds (109))
               and then Terminal.App.Renderer.Testing.Animation_Frame_Due_At
                 (R, Finite_Start + Ada.Real_Time.Milliseconds (110)),
               "finite catch-up preserves the terminal frame delays");
            Terminal.App.Renderer.Testing.Advance_Animations_At
              (R, Finite_Start + Ada.Real_Time.Milliseconds (110));
            Assert
              (Terminal.App.Renderer.Testing.Animation_Frame_Due_At
                 (R, Finite_Start + Ada.Real_Time.Milliseconds (120)),
               "finite playback reaches its final stop deadline");
            Terminal.App.Renderer.Testing.Advance_Animations_At
              (R, Finite_Start + Ada.Real_Time.Milliseconds (120));
            Assert
              (not Terminal.App.Renderer.Testing.Animation_Frame_Due_At
                 (R, Finite_Start + Ada.Real_Time.Milliseconds (120)),
               "elapsed finite loops stop after the final frame delay");
         end;
      end;

      Process
        ("Gq=2,a=d,d=f,i=90",
         Terminal.Core.Graphics_OK,
         "animation delete frames");
      declare
         Theme_Status : Terminal.App.Renderer.Theme_Update_Status;
      begin
         Terminal.App.Renderer.Set_Theme
           (R,
            Terminal.App.Theme.Built_In (Terminal.App.Theme.Light),
            Theme_Status);
         Assert
           (Theme_Status = Terminal.App.Renderer.Theme_Ok,
            "theme replay accepts deleted dependency frames");
         Render_Animation ("theme replay after frame deletion");
         Assert_Pixel
           (0, 3, 16#80#,
            "deleted dependency still rebuilds composed root");
         Assert_Pixel
           (1, 1, 16#FF#,
            "theme replay preserves composition destination neighbor");
      end;
      Process
        ("Gq=2,a=a,i=90,c=2",
         Terminal.Core.Graphics_ENOENT,
         "animation deleted frame missing");

      Terminal.App.Renderer.Graphics.Release_Stream (R, 2_102);
      Terminal.Core.Finalize (Animation_T);
   end;

   Terminal.App.Renderer.Finalize (R);
end Renderer_Animation_Smoke;
