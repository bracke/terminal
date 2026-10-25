with AUnit.Assertions;

with Terminal.App.Image_Media;
with Terminal.App.Render_Model;
with Terminal.App.Renderer;
with Terminal.App.Renderer.Testing;
with Terminal.App.Splits;
with Terminal.App.Tabs;
with Terminal.App.Theme;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Renderer_Animation_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.App.Image_Media.Decode_Status;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.App.Renderer.Theme_Update_Status;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Kitty_Graphics_Result_Code;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   R : Terminal.App.Renderer.Renderer;
   Renderer_Status : Terminal.App.Renderer.Init_Status;
   Render_Status : Terminal.App.Renderer.Render_Status;
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
         Expected : Terminal.Core.Kitty_Graphics_Result_Code;
         Label_Text : String)
      is
         Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
         Result : Terminal.Core.Kitty_Graphics_Result;
      begin
         Terminal.Core.Feed
           (Animation_T,
            To_Bytes (ASCII.ESC & "_" & Command & ASCII.ESC & "\"),
            Animation_Feed);
         Assert (Animation_Feed = Terminal.Core.Ok, Label_Text & " feed");
         Terminal.Core.Peek_Graphics_Event (Animation_T, Event);
         Snaps (1) := Terminal.Core.Snapshot (Animation_T);
         Snaps (1).Graphics := Event;
         Terminal.App.Renderer.Render_App
           (R,
            Snaps,
            1,
            Terminal.App.Tabs.Snapshot (Tabs),
            Terminal.App.Splits.Snapshot (Splits),
            Render_Status);
         Terminal.Core.Release (Snaps (1));
         Assert (Render_Status = Terminal.App.Renderer.Ok, Label_Text & " render");
         Result := Terminal.App.Renderer.Graphics_Result (R, Event);
         Assert (Result.Code = Expected, Label_Text & " result");
         Terminal.Core.Complete_Graphics_Event (Animation_T, Event, Result);
         Terminal.App.Renderer.Commit_Graphics_Events (R);
      end Process;

      procedure Process_ITerm2
        (Payload : String;
         Label_Text : String)
      is
         Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
         Result : Terminal.Core.Kitty_Graphics_Result;
      begin
         Terminal.Core.Feed
           (Animation_T,
            To_Bytes
              (ASCII.ESC & "]1337;File=inline=1;doNotMoveCursor=1:"
               & Payload & ASCII.BEL),
            Animation_Feed);
         Assert (Animation_Feed = Terminal.Core.Ok, Label_Text & " feed");
         Terminal.Core.Peek_Graphics_Event (Animation_T, Event);
         Snaps (1) := Terminal.Core.Snapshot (Animation_T);
         Snaps (1).Graphics := Event;
         Terminal.App.Renderer.Render_App
           (R,
            Snaps,
            1,
            Terminal.App.Tabs.Snapshot (Tabs),
            Terminal.App.Splits.Snapshot (Splits),
            Render_Status);
         Terminal.Core.Release (Snaps (1));
         Assert (Render_Status = Terminal.App.Renderer.Ok, Label_Text & " render");
         Result := Terminal.App.Renderer.Graphics_Result (R, Event);
         Terminal.Core.Complete_Graphics_Event (Animation_T, Event, Result);
         Terminal.App.Renderer.Commit_Graphics_Events (R);
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
         Snaps (1) := Terminal.Core.Snapshot (Animation_T);
         Snaps (1).Graphics := (others => <>);
         Terminal.App.Renderer.Render_App
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
         Terminal.Core.Kitty_OK,
         "animation root");
      Assert_Pixel (0, 0, 16#FF#, "animation root red");

      Process
        ("Gq=2,a=f,i=90,f=32,s=2,v=1;AAD/////AP8=",
         Terminal.Core.Kitty_OK,
         "animation frame");
      Process
        ("Gq=2,a=f,i=90,f=32,r=2,s=2,v=1,X=1,o=z;"
         & "eJxjYPgPBAz/ARL1BPw=",
         Terminal.Core.Kitty_OK,
         "compressed animation frame edit");
      Process
        ("Gq=2,a=a,i=90,c=2",
         Terminal.Core.Kitty_OK,
         "animation select frame");
      Assert_Pixel (0, 2, 16#FF#, "animation selected blue frame");

      Process
        ("Gq=2,a=f,i=90,f=32,r=2,x=1,y=0,s=1,v=1,X=1;////gA==",
         Terminal.Core.Kitty_OK,
         "animation partial edit");
      Assert_Pixel (1, 0, 16#FF#, "animation edited red");
      Assert_Pixel (1, 3, 16#80#, "animation edited alpha");

      Process
        ("Gq=2,a=c,i=90,r=2,c=1,X=0,Y=0,x=1,y=0,w=1,h=1,C=1",
         Terminal.Core.Kitty_OK,
         "animation compose");
      Process
        ("Gq=2,a=a,i=90,c=1",
         Terminal.Core.Kitty_OK,
         "animation select root");
      Assert_Pixel (1, 2, 16#FF#, "animation composed blue root");

      Process
        ("Gq=2,a=f,i=90,f=32,r=2,s=2,v=1,m=1;AAD/",
         Terminal.Core.Kitty_No_Response,
         "animation first chunk");
      Process
        ("Gq=2,a=f,m=0;////AP8=",
         Terminal.Core.Kitty_OK,
         "animation final chunk");
      Process
        ("Gq=2,a=a,i=90,c=2",
         Terminal.Core.Kitty_OK,
         "animation select chunked frame");
      Assert_Pixel (1, 0, 16#FF#, "animation chunked yellow frame");

      Process
        ("Gq=2,a=a,i=90,r=1,z=-1",
         Terminal.Core.Kitty_OK,
         "animation root gap control");
      Process
        ("Gq=2,a=a,i=90,r=2,z=-1",
         Terminal.Core.Kitty_OK,
         "animation frame gap control");
      Process
        ("Gq=2,a=a,i=90,s=3,c=1,v=2",
         Terminal.Core.Kitty_OK,
         "animation finite playback");
      Render_Animation ("animation first advance");
      Assert_Pixel (1, 2, 16#FF#, "animation first loop returns to root");
      Render_Animation ("animation first loop");
      Assert_Pixel (1, 0, 16#FF#, "animation stops on final frame");
      Render_Animation ("animation stopped stability");
      Assert_Pixel (1, 0, 16#FF#, "animation stopped frame remains stable");

      Process
        ("Gq=2,a=a,i=90,s=2,c=1",
         Terminal.Core.Kitty_OK,
         "animation loading playback");
      Render_Animation ("animation loading reaches tail");
      Assert_Pixel (1, 0, 16#FF#, "animation loading tail frame");
      Process
        ("Gq=2,a=f,i=90,f=32,s=2,v=1;AP8A/wD/AP8=",
         Terminal.Core.Kitty_OK,
         "animation append while loading");
      Render_Animation ("animation loading consumes appended frame");
      Assert_Pixel (0, 1, 16#FF#, "animation loading appended green frame");

      declare
         Original : constant Terminal.App.Renderer.Graphics_Resource_Limits :=
           Terminal.App.Renderer.Graphics_Resource_Limit (R);
         Tight_Limits : Terminal.App.Renderer.Graphics_Resource_Limits :=
           Original;
      begin
         Tight_Limits.Animation_Frames := 1;
         Terminal.App.Renderer.Set_Graphics_Resource_Limits (R, Tight_Limits);
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
         Terminal.App.Renderer.Set_Graphics_Resource_Limits (R, Tight_Limits);
         Process
           ("Gq=2,a=f,i=90,f=32,s=2,v=1;/////wAAAP8=",
            Terminal.Core.Kitty_ENOSPC,
            "animation frame quota");
         Assert
           (Terminal.App.Renderer.Diagnostics (R).
              Kitty_Animation_Frame_Count = 2,
            "animation frame quota accounting");

         Tight_Limits.Animation_Frames := Original.Animation_Frames;
         Tight_Limits.Per_Image_Bytes := 7;
         Terminal.App.Renderer.Set_Graphics_Resource_Limits (R, Tight_Limits);
         Process
           ("Gq=2,a=f,i=90,f=32,r=2,s=2,v=1,X=1;/////wAAAP8=",
            Terminal.Core.Kitty_ENOSPC,
            "animation decoded byte quota");
         Assert
           (Terminal.App.Renderer.Diagnostics (R).
              Kitty_Animation_Frame_Count = 2,
            "rejected animation edit preserves frame accounting");
         Terminal.App.Renderer.Set_Graphics_Resource_Limits (R, Original);
      end;

      Process
        ("Gq=2,a=d,d=f,i=90",
         Terminal.Core.Kitty_OK,
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
           (1, 2, 16#FF#,
            "deleted dependency still rebuilds composed root");
      end;
      Process
        ("Gq=2,a=a,i=90,c=2",
         Terminal.Core.Kitty_ENOENT,
         "animation deleted frame missing");

      Terminal.App.Renderer.Release_Graphics_Stream (R, 2_102);
      Terminal.Core.Finalize (Animation_T);
   end;

   Terminal.App.Renderer.Finalize (R);
end Renderer_Animation_Smoke;
