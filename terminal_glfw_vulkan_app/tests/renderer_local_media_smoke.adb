with AUnit.Assertions;
with GNAT.OS_Lib;

with Terminal.App.Graphics_Transport;
with Terminal.App.Render_Model;
with Terminal.App.Renderer;
with Terminal.App.Renderer.Testing;
with Terminal.App.Splits;
with Terminal.App.Tabs;
with Terminal.Common.Bytes;
with Terminal.Core;
with Test_Support;

procedure Renderer_Local_Media_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type GNAT.OS_Lib.File_Descriptor;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
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
   Renderer_Status : Terminal.App.Renderer.Init_Status :=
     Terminal.App.Renderer.Failed;
   Render_Status : Terminal.App.Renderer.Render_Status;
   Fixture : Test_Support.Temporary_File;
begin
   Test_Support.Reserve (Fixture, "terminal-renderer-local-graphics.bin");
   Terminal.App.Renderer.Initialize_Headless (R, Renderer_Status);
   Assert
     (Renderer_Status = Terminal.App.Renderer.Ok,
      "local-media renderer initialize");

   declare
      Path : constant String := Test_Support.Path (Fixture);
      Encoded_Path : constant String := Test_Support.Base64 (Path);
      Local_T : Terminal.Core.Terminal;
      Local_Init : Terminal.Core.Initialize_Status := Terminal.Core.Invalid_Size;
      Local_Feed : Terminal.Core.Feed_Status;
      Event : Terminal.Core.Graphics_Event;
      Tabs : Terminal.App.Tabs.Tab_State;
      Splits : Terminal.App.Splits.Split_State;
      Pixels : aliased Byte_Array :=
        (1 => 16#FF#, 2 => 0, 3 => 0, 4 => 16#FF#);
      Compressed_PNG : aliased Byte_Array :=
        (16#78#, 16#9C#, 16#EB#, 16#0C#, 16#F0#, 16#73#, 16#E7#,
         16#E5#, 16#92#, 16#E2#, 16#62#, 16#60#, 16#60#, 16#E0#,
         16#F5#, 16#F4#, 16#70#, 16#09#, 16#02#, 16#D2#, 16#8C#,
         16#20#, 16#CC#, 16#C1#, 16#04#, 16#24#, 16#27#, 16#94#,
         16#07#, 16#DF#, 16#03#, 16#4B#, 16#B8#, 16#38#, 16#86#,
         16#54#, 16#CC#, 16#49#, 16#FE#, 16#71#, 16#FE#, 16#00#,
         16#03#, 16#03#, 16#33#, 16#23#, 16#23#, 16#C3#, 16#49#,
         16#86#, 16#63#, 16#53#, 16#1E#, 16#01#, 16#25#, 16#18#,
         16#3C#, 16#5D#, 16#FD#, 16#5C#, 16#D6#, 16#39#, 16#25#,
         16#34#, 16#01#, 16#00#, 16#D5#, 16#D6#, 16#10#, 16#4B#);
      FD : GNAT.OS_Lib.File_Descriptor;
      Written : Integer;
      Deleted : Boolean;

      procedure Process
        (Command : String;
         Expected : Terminal.Core.Kitty_Graphics_Result_Code;
         Label_Text : String)
      is
         Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
         Result : Terminal.Core.Kitty_Graphics_Result;
      begin
         Terminal.Core.Feed
           (Local_T,
            To_Bytes (ASCII.ESC & "_" & Command & ASCII.ESC & "\"),
            Local_Feed);
         Assert (Local_Feed = Terminal.Core.Ok, Label_Text & " feed");
         Terminal.Core.Peek_Graphics_Event (Local_T, Event);
         Snaps (1) := Terminal.Core.Snapshot (Local_T);
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
         Terminal.Core.Complete_Graphics_Event (Local_T, Event, Result);
         Terminal.App.Renderer.Commit_Graphics_Events (R);
      end Process;

   begin
      FD := GNAT.OS_Lib.Create_File (Path, GNAT.OS_Lib.Binary);
      Assert (FD /= GNAT.OS_Lib.Invalid_FD, "local graphics fixture create");
      Written := GNAT.OS_Lib.Write (FD, Pixels (1)'Address, Pixels'Length);
      GNAT.OS_Lib.Close (FD);
      Assert (Written = Pixels'Length, "local graphics fixture write");

      Terminal.Core.Initialize (Local_T, 1, 2, 10, Local_Init);
      Assert (Local_Init = Terminal.Core.Ok, "local graphics core initialize");
      Terminal.Core.Set_Graphics_Stream_ID (Local_T, 2_101);
      Terminal.App.Renderer.Set_Graphics_Access_Policy
        (R, Terminal.App.Graphics_Transport.Trusted_Access_Policy);
      Terminal.App.Tabs.Initialize (Tabs);
      Terminal.App.Splits.Initialize (Splits);
      Process
        ("Gq=2,a=T,t=f,i=81,f=32,s=1,v=1,c=1,r=1,C=1;"
         & Encoded_Path,
         Terminal.Core.Kitty_OK,
         "regular-file graphics");
      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Frame.Image_Count = 1
            and then Natural (Frame.Images (1).Image_ID) = 81
            and then Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 0) = 16#FF#
            and then Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 3) = 16#FF#,
            "regular-file graphics decoded pixels");
      end;
      Process
        ("Gq=2,a=t,t=f,i=82,f=32,s=1,v=1;L2Rldi9udWxs",
         Terminal.Core.Kitty_EBADF,
         "uniform local-file failure");
      FD := GNAT.OS_Lib.Create_File (Path, GNAT.OS_Lib.Binary);
      Assert
        (FD /= GNAT.OS_Lib.Invalid_FD,
         "compressed local PNG fixture create");
      Written :=
        GNAT.OS_Lib.Write
          (FD, Compressed_PNG (1)'Address, Compressed_PNG'Length);
      GNAT.OS_Lib.Close (FD);
      Assert
        (Written = Compressed_PNG'Length,
         "compressed local PNG fixture write");
      Process
        ("Ga=q,t=f,i=83,f=100,o=z;" & Encoded_Path,
         Terminal.Core.Kitty_OK,
         "local compressed PNG query self-sizes inflated data");
      GNAT.OS_Lib.Delete_File (Path, Deleted);
      Terminal.App.Renderer.Release_Graphics_Stream (R, 2_101);
      Terminal.App.Renderer.Set_Graphics_Access_Policy
        (R, Terminal.App.Graphics_Transport.Default_Access_Policy);
      Terminal.Core.Finalize (Local_T);
   exception
      when others =>
         Test_Support.Delete_If_Present (Path);
         if Local_Init = Terminal.Core.Ok then
            Terminal.Core.Finalize (Local_T);
         end if;
         Terminal.App.Renderer.Set_Graphics_Access_Policy
           (R, Terminal.App.Graphics_Transport.Default_Access_Policy);
         raise;
   end;

   Terminal.App.Renderer.Finalize (R);
exception
   when others =>
      if Renderer_Status = Terminal.App.Renderer.Ok then
         Terminal.App.Renderer.Finalize (R);
      end if;
      raise;
end Renderer_Local_Media_Smoke;
