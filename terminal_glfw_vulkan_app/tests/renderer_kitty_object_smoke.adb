with AUnit.Assertions;
with Interfaces;
with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.App.Render_Model;
with Terminal.App.Renderer;
with Terminal.App.Renderer.Testing;
with Terminal.App.Splits;
with Terminal.App.Tabs;
with Terminal.App.Theme;

procedure Renderer_Kitty_Object_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Kitty_Graphics_Result_Code;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.App.Render_Model.Image_Data_Access;
   use type Interfaces.Unsigned_64;

   R : Terminal.App.Renderer.Renderer;
   T : Terminal.Core.Terminal;
   Init_Status : Terminal.App.Renderer.Init_Status;
   Core_Status : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status;
   Tabs : Terminal.App.Tabs.Tab_State;
   Splits : Terminal.App.Splits.Split_State;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   procedure Process
     (Command    : String;
      Label_Text : String;
      Expected   : Terminal.Core.Kitty_Graphics_Result_Code :=
        Terminal.Core.Kitty_OK)
   is
      Event : Terminal.Core.Graphics_Event;
      Result : Terminal.Core.Kitty_Graphics_Result;
      Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
   begin
      Terminal.Core.Feed
        (T, To_Bytes (ASCII.ESC & "_" & Command & ASCII.ESC & "\"), Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, Label_Text & " feed");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Assert (Event.Pending, Label_Text & " event");
      Snaps (1) := Terminal.Core.Snapshot (T);
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
      Assert (Result.Code = Expected, Label_Text & " protocol result");
      Terminal.Core.Complete_Graphics_Event (T, Event, Result);
      Terminal.App.Renderer.Commit_Graphics_Events (R);
   end Process;

   procedure Render_Retained (Label_Text : String) is
      Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
   begin
      Snaps (1) := Terminal.Core.Snapshot (T);
      Snaps (1).Graphics := (others => <>);
      Terminal.App.Renderer.Render_App
        (R,
         Snaps,
         1,
         Terminal.App.Tabs.Snapshot (Tabs),
         Terminal.App.Splits.Snapshot (Splits),
         Render_Status);
      Terminal.Core.Release (Snaps (1));
      Assert (Render_Status = Terminal.App.Renderer.Ok, Label_Text);
      Terminal.App.Renderer.Commit_Graphics_Events (R);
   end Render_Retained;

   procedure Reset is
   begin
      Terminal.App.Renderer.Release_Graphics_Stream (R, 4_001);
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Bytes = 0,
         "graphics stream release clears indexed and animation accounting");
      Terminal.Core.Initialize (T, 2, 4, 10, Core_Status);
      Assert (Core_Status = Terminal.Core.Ok, "core reset");
      Terminal.Core.Set_Graphics_Stream_ID (T, 4_001);
   end Reset;
begin
   Terminal.App.Renderer.Initialize_Headless (R, Init_Status);
   Assert (Init_Status = Terminal.App.Renderer.Ok, "renderer initialize");
   Terminal.App.Tabs.Initialize (Tabs);
   Terminal.App.Splits.Initialize (Splits);
   Reset;

   Process
     ("Gf=8,a=T,i=230,s=1,v=1,C=1,c=1,r=1;AQ==",
      "indexed opaque image");
   Render_Retained ("indexed opaque retained render");
   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert
        (Frame.Image_Count = 1
         and then Frame.Images (1).Raw_Format = 32
         and then Frame.Images (1).Decoded_Bytes /= null
         and then Frame.Images (1).Decoded_Bytes (1) = 16#CC#
         and then Frame.Images (1).Decoded_Bytes (2) = 16#2E#
         and then Frame.Images (1).Decoded_Bytes (3) = 16#2E#
         and then Frame.Images (1).Decoded_Bytes (4) = 16#FF#,
         "f=8 maps through the active terminal palette");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Bytes = 5,
         "indexed source and expanded texture are quota-accounted");
   end;
   Terminal.App.Renderer.Set_Theme
     (R, Terminal.App.Theme.Built_In (Terminal.App.Theme.Light));
   Render_Retained ("indexed image theme refresh");
   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert
        (Frame.Images (1).Decoded_Bytes (1) = 16#BF#
         and then Frame.Images (1).Decoded_Bytes (2) = 16#1A#
         and then Frame.Images (1).Decoded_Bytes (3) = 16#21#,
         "indexed image is regenerated after a theme change");
   end;

   Process
     ("Gq=2,a=f,i=230,f=8,s=1,v=1;Ag==",
      "indexed animation frame",
      Terminal.Core.Kitty_OK);
   Process
     ("Gq=2,a=a,i=230,c=2",
      "select indexed animation frame",
      Terminal.Core.Kitty_OK);
   Render_Retained ("indexed animation light theme");
   declare
      Light_Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
      Light_Red : constant Byte := Light_Frame.Images (1).Decoded_Bytes (1);
      Light_Green : constant Byte := Light_Frame.Images (1).Decoded_Bytes (2);
      Light_Blue : constant Byte := Light_Frame.Images (1).Decoded_Bytes (3);
   begin
      Terminal.App.Renderer.Set_Theme
        (R, Terminal.App.Theme.Built_In (Terminal.App.Theme.Default_Dark));
      Render_Retained ("indexed animation dark theme refresh");
      declare
         Dark_Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Dark_Frame.Images (1).Decoded_Bytes (1) /= Light_Red
            or else Dark_Frame.Images (1).Decoded_Bytes (2) /= Light_Green
            or else Dark_Frame.Images (1).Decoded_Bytes (3) /= Light_Blue,
            "indexed animation frame is replayed against the new palette");
      end;
   end;

   Process
     ("Gq=2,a=f,i=230,f=8,r=1,s=1,v=1;Ag==",
      "indexed animation root edit",
      Terminal.Core.Kitty_OK);
   Process
     ("Gq=2,a=a,i=230,c=1",
      "select edited indexed root",
      Terminal.Core.Kitty_OK);
   Process
     ("Gq=2,a=d,d=f,i=230",
      "delete indexed animation frames",
      Terminal.Core.Kitty_OK);
   Render_Retained ("indexed root retained after frame deletion");
   declare
      Dark_Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
      Dark_Red : constant Byte := Dark_Frame.Images (1).Decoded_Bytes (1);
      Dark_Green : constant Byte := Dark_Frame.Images (1).Decoded_Bytes (2);
      Dark_Blue : constant Byte := Dark_Frame.Images (1).Decoded_Bytes (3);
   begin
      Terminal.App.Renderer.Set_Theme
        (R, Terminal.App.Theme.Built_In (Terminal.App.Theme.Light));
      Render_Retained ("deleted-frame indexed root theme refresh");
      declare
         Light_Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Light_Frame.Images (1).Decoded_Bytes (1) /= Dark_Red
            or else Light_Frame.Images (1).Decoded_Bytes (2) /= Dark_Green
            or else Light_Frame.Images (1).Decoded_Bytes (3) /= Dark_Blue,
            "frame deletion preserves palette replay for the root image");
      end;
   end;

   declare
      Root_Only_Bytes : constant Natural :=
        Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Bytes;
   begin
      Process
        ("Gq=2,a=f,i=230,f=32,s=1,v=1;/wAA/w==",
         "temporary animation frame after deletion",
         Terminal.Core.Kitty_OK);
      Process
        ("Gq=2,a=d,d=f,i=230",
         "delete unrelated temporary animation frame",
         Terminal.Core.Kitty_OK);
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Bytes =
           Root_Only_Bytes,
         "frame deletion compacts replay data unrelated to the root");
   end;

   Reset;
   Terminal.App.Renderer.Set_Theme
     (R, Terminal.App.Theme.Built_In (Terminal.App.Theme.Default_Dark));
   Process
     ("Gf=16,a=T,i=231,s=1,v=1,C=1,c=1,r=1;+IA=",
      "indexed alpha image");
   Render_Retained ("indexed alpha retained render");
   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert
        (Frame.Image_Count = 1
         and then Frame.Images (1).Raw_Format = 32
         and then Frame.Images (1).Decoded_Bytes (1) = 16#08#
         and then Frame.Images (1).Decoded_Bytes (2) = 16#09#
         and then Frame.Images (1).Decoded_Bytes (3) = 16#0A#
         and then Frame.Images (1).Decoded_Bytes (4) = 16#80#,
         "f=16 maps special palette colors and preserves alpha");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Bytes = 6,
         "indexed alpha source and expanded texture are quota-accounted");
   end;

   Reset;

   Process ("Gf=32,a=t,i=91,s=1,v=1;/wAA/w==", "explicit store");
   Process ("Ga=p,i=91,C=1,c=1,r=1;", "first implicit placement");
   Process ("Ga=p,i=91,C=1,c=1,r=1;", "second implicit placement");
   Render_Retained ("implicit placement retained render");
   declare
      Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert
        (Diagnostics.Kitty_Placement_Count = 2 and then Frame.Image_Count = 2,
         "each p=0 command creates a distinct placement");
   end;

   Reset;
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "_Gf=32,a=T,i=93,s=1,v=1,m=1;/wAA" & ASCII.ESC & "\"),
      Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok
      and then Terminal.Core.Pending_Graphics_Event_Count (T) = 0,
      "core retains cancelled chunk first part");
   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "_Gm=0;/w==" & ASCII.CAN & "x"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "cancelled chunk feed");
   declare
      Event : Terminal.Core.Graphics_Event;
      Result : Terminal.Core.Kitty_Graphics_Result;
      Snap : Terminal.Core.Render_Snapshot;
   begin
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Assert
        (Event.Pending and then Event.Cancelled,
         "CAN queues an ordered Kitty chunk cancellation");
      Snap := Terminal.Core.Snapshot (T);
      Snap.Graphics := Event;
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "cancelled chunk renderer cleanup");
      Result := Terminal.App.Renderer.Graphics_Result (R, Event);
      Terminal.Core.Complete_Graphics_Event (T, Event, Result);
      Terminal.App.Renderer.Commit_Graphics_Events (R);
   end;
   Process
     ("Gf=32,a=T,i=94,s=1,v=1,C=1;/wAA/w==",
      "fresh image after CAN cancellation");
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count = 1,
      "cancelled encoded chunks do not poison the next transmission");

   Reset;
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "_Gf=32,a=T,i=95,s=1,v=1,m=1;/wAA" & ASCII.ESC & "\"),
      Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok
      and then Terminal.Core.Pending_Graphics_Event_Count (T) = 0,
      "core retains reset chunk first part");
   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "c"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "RIS during chunk feed");
   Render_Retained ("RIS synchronizes renderer chunk generation");
   Process
     ("Gf=32,a=T,i=96,s=1,v=1,C=1;/wAA/w==",
      "fresh image after RIS");
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count = 1,
      "terminal reset discards core-owned encoded chunks");

   Reset;
   Process
     ("Gf=32,a=T,i=4294967295,s=1,v=1,C=1;/wAA/w==",
      "maximum image id");
   Process
     ("Ga=d,d=R,x=4294967295,y=4294967295;",
      "maximum image id range deletion");
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count = 0
      and then Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count = 0,
      "range deletion preserves the full unsigned image-id width");

   Reset;
   Process ("Gf=32,a=T,s=1,v=1,C=1;/wAA/w==", "first anonymous image");
   Process ("Gf=32,a=T,s=1,v=1,C=1;AP8A/w==", "second anonymous image");
   Render_Retained ("anonymous images retained render");
   declare
      Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert
        (Diagnostics.Kitty_Image_Object_Count = 2
         and then Diagnostics.Kitty_Placement_Count = 2
         and then Frame.Image_Count = 2,
         "anonymous transmit-and-display images coexist persistently");
   end;
   Process ("Ga=d,d=R,x=0,y=0;", "anonymous range delete all");
   declare
      Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
   begin
      Assert
        (Diagnostics.Kitty_Image_Object_Count = 0
         and then Diagnostics.Kitty_Placement_Count = 0,
         "uppercase screen delete releases anonymous objects");
   end;

   Reset;
   declare
      Placeholder : constant String :=
        Character'Val (16#F4#) & Character'Val (16#8E#)
        & Character'Val (16#BB#) & Character'Val (16#AE#);
      Row_Zero : constant String :=
        Character'Val (16#CC#) & Character'Val (16#85#);
   begin
      Process
        ("Gf=32,a=T,i=92,p=7,U=1,s=1,v=1,c=1,r=1;/wAA/w==",
         "virtual placement");
      Process
        ("Ga=p,i=92,U=1,C=1,c=1,r=1;",
         "first implicit virtual placement");
      Process
        ("Ga=p,i=92,U=1,C=1,c=1,r=1;",
         "second implicit virtual placement");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count = 3,
         "each virtual p=0 command creates a distinct prototype");
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "[38;5;92m" & Placeholder & Row_Zero & Row_Zero),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "zero placement-id placeholder feed");
   end;
   Render_Retained ("zero placement-id placeholder render");
   Assert
     (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1,
      "zero placeholder placement id selects the image virtual placement");

   Reset;
   Process ("Gf=32,a=t,i=210,s=1,v=1;/wAA/w==", "screen identity store");
   Process
     ("Ga=p,i=210,p=9,C=1,c=1,r=1;",
      "primary addressed placement");
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count = 1,
      "primary addressed placement count");
   Terminal.Core.Feed
     (T, To_Bytes (ASCII.ESC & "[?1049h"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "enter alternate screen");
   Render_Retained ("alternate screen synchronization");
   Process
     ("Ga=p,i=210,p=9,C=1,c=1,r=1;",
      "alternate addressed placement replacement");
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count = 1,
      "image and placement ID pair stays unique across screens");
   Terminal.Core.Feed
     (T, To_Bytes (ASCII.ESC & "[?1049l"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "leave alternate screen");
   Render_Retained ("primary after cross-screen placement replacement");
   Assert
     (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 0,
      "cross-screen replacement moves rather than duplicates placement");

   Reset;
   Process ("Gf=32,a=t,i=220,s=1,v=1;/wAA/w==", "relative parent store");
   Process ("Gf=32,a=t,i=221,s=1,v=1;AP8A/w==", "relative child store");
   Process
     ("Ga=p,i=220,p=1,C=1,c=1,r=1;",
      "primary relative parent placement");
   Process
     ("Ga=p,i=221,p=2,P=220,Q=1,H=1,V=0,C=1,c=1,r=1;",
      "primary relative child placement");
   Terminal.Core.Feed
     (T, To_Bytes (ASCII.ESC & "[?1049h"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "relative enter alternate screen");
   Render_Retained ("relative alternate screen synchronization");
   Process
     ("Ga=p,i=220,p=1,C=1,c=1,r=1;",
      "alternate relative parent replacement");
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count = 2
      and then Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 2,
      "relative descendants follow an addressed parent across screens");

   Reset;
   Process ("Gf=32,a=t,i=211,s=1,v=1;/wAA/w==", "virtual identity store");
   Process
     ("Ga=p,i=211,p=10,U=1,C=1,c=1,r=1;",
      "primary addressed virtual placement");
   Terminal.Core.Feed
     (T, To_Bytes (ASCII.ESC & "[?1049h"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "virtual enter alternate screen");
   Render_Retained ("virtual alternate screen synchronization");
   Process
     ("Ga=p,i=211,p=10,U=1,C=1,c=1,r=1;",
      "alternate addressed virtual replacement");
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count = 1,
      "virtual image and placement ID pair stays unique across screens");

   Reset;
   Process
     ("Gf=32,a=t,i=300,s=1,v=1;/wAA/w==",
      "unrelated reusable image store");
   Process
     ("Gf=32,a=t,i=301,s=1,v=1;AP8A/w==",
      "selected z-index image store");
   Process
     ("Ga=p,i=301,p=1,C=1,c=1,r=1,z=-1;",
      "selected z-index placement");
   Process ("Ga=d,d=Z,z=-1;", "capital z-index deletion");
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count = 1
      and then Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count = 0,
      "capital selector deletes only data belonging to matched placements");
   Process
     ("Ga=p,i=300,p=2,C=1,c=1,r=1;",
      "unrelated reusable image survives capital selector");
   Assert
     (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1,
      "preserved transmit-only image remains displayable");

   Reset;
   Process
     ("Gf=32,a=t,i=310,s=1,v=1;/wAA/w==",
      "relative deletion parent store");
   Process
     ("Gf=32,a=t,i=311,s=1,v=1;AP8A/w==",
      "relative deletion child store");
   Terminal.Core.Feed
     (T, To_Bytes (ASCII.ESC & "[1;2H"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "relative deletion cursor feed");
   Process
     ("Ga=p,i=310,p=1,C=1,c=1,r=1;",
      "relative deletion parent placement");
   Process
     ("Ga=p,i=311,p=2,P=310,Q=1,H=2,V=0,C=1,c=1,r=1;",
      "relative deletion child placement");
   Process
     ("Ga=d,d=p,x=4,y=1;",
      "relative placement positional deletion");
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count = 1
      and then Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count = 2,
      "positional deletion uses resolved relative coordinates and retains data");
   Process
     ("Ga=p,i=311,p=2,C=1,c=1,r=1;",
      "soft-deleted relative image data remains reusable");

   Reset;
   declare
      Installs_Before : constant Interfaces.Unsigned_64 :=
        Terminal.App.Renderer.Diagnostics (R).Image_Install_Count;
   begin
      for Iteration in 1 .. 128 loop
         Process
           ("Gq=2,f=32,a=T,i=200,s=1,v=1,C=1,c=1,r=1;"
            & (if Iteration mod 2 = 0 then "/wAA/w==" else "AP8A/w=="),
            "rapid thumbnail replacement",
            Terminal.Core.Kitty_OK);
      end loop;
      Render_Retained ("rapid replacement retained render");
      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
      begin
         Assert
           (Diagnostics.Kitty_Image_Object_Count = 1
            and then Diagnostics.Kitty_Image_Object_Bytes = 4
            and then Diagnostics.Kitty_Placement_Count = 1
            and then Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1,
            "rapid replacements remain bounded and leave no stale previews");
         Assert
           (Diagnostics.Image_Install_Count - Installs_Before = 128,
            "rapid replacement diagnostic count");
      end;
   end;

   Reset;
   declare
      Original : constant Terminal.App.Renderer.Graphics_Resource_Limits :=
        Terminal.App.Renderer.Graphics_Resource_Limit (R);
      Tight : Terminal.App.Renderer.Graphics_Resource_Limits := Original;
   begin
      Tight.Per_Image_Bytes := 4;
      Terminal.App.Renderer.Set_Graphics_Resource_Limits (R, Tight);
      Process
        ("Gq=2,f=32,a=t,i=240,s=1,v=1;AP8A/w==",
         "bounded explicit image install",
         Terminal.Core.Kitty_OK);
      Process
        ("Gq=2,f=32,a=t,i=240,s=2,v=1;AP8A/wD/AP8=",
         "oversized explicit image replacement",
         Terminal.Core.Kitty_ENOMEM);
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count = 1
         and then
           Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Bytes = 4,
         "failed explicit replacement preserves the prior bounded object");
      Terminal.App.Renderer.Set_Graphics_Resource_Limits (R, Original);
   end;

   declare
      Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
   begin
      Assert
        (Diagnostics.Graphics_Event_Count > 0
         and then Diagnostics.Kitty_Command_Count > 0
         and then Diagnostics.Kitty_Success_Count > 0
         and then Diagnostics.Image_Install_Count > 0
         and then Diagnostics.Image_Installed_Bytes > 0
         and then Diagnostics.Placement_Create_Count > 0
         and then Diagnostics.Chunk_Cancel_Count > 0,
         "cumulative graphics diagnostics cover protocol and resources");
   end;

   Terminal.App.Renderer.Release_Graphics_Stream (R, 4_001);
   Terminal.Core.Finalize (T);
   Terminal.App.Renderer.Finalize (R);
end Renderer_Kitty_Object_Smoke;
