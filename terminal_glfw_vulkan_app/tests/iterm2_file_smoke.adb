with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with AUnit.Assertions;
with GNAT.OS_Lib;

with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.App.ITerm2_Files;
with Terminal.App.Renderer;

procedure ITerm2_File_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.ITerm2_Files.Save_Status;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   package Files renames Terminal.App.ITerm2_Files;
   package SIO renames Ada.Streams.Stream_IO;

   Process_Image : constant String :=
     GNAT.OS_Lib.Process_Id'Image (GNAT.OS_Lib.Current_Process_Id);
   Directory : constant String :=
     "/tmp/terminal-iterm2-files-"
     & Process_Image (Process_Image'First + 1 .. Process_Image'Last);
   Policy : Files.Download_Policy;
   Status : Files.Save_Status;
   Saved_Name : String (1 .. Files.Max_File_Name_Length);
   Saved_Length : Natural;

   function Saved return String is
     (Saved_Name (Saved_Name'First .. Saved_Name'First + Saved_Length - 1));

   function Contents (Path : String) return String is
      File : SIO.File_Type;
      Data : Ada.Streams.Stream_Element_Array (1 .. 64);
      Last : Ada.Streams.Stream_Element_Offset;
   begin
      SIO.Open (File, SIO.In_File, Path);
      SIO.Read (File, Data, Last);
      SIO.Close (File);
      declare
         Result : String (1 .. Natural (Last));
      begin
         for I in Result'Range loop
            Result (I) := Character'Val (Data (Ada.Streams.Stream_Element_Offset (I)));
         end loop;
         return Result;
      end;
   end Contents;

   function To_Bytes (Text : String) return Terminal.Common.Bytes.Byte_Array is
      Result : Terminal.Common.Bytes.Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) :=
           Terminal.Common.Bytes.Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;
begin
   if Ada.Directories.Exists (Directory) then
      Ada.Directories.Delete_Tree (Directory);
   end if;
   Ada.Directories.Create_Directory (Directory);

   Files.Configure (Policy, False, Directory);
   Files.Save
     ("File=name=cmVwb3J0LnR4dA==;size=4;inline=0:QUJDRA==",
      Policy, 1_024, Status, Saved_Name, Saved_Length);
   Assert (Status = Files.Save_Disabled, "downloads require explicit policy");

   Files.Configure (Policy, True, Directory);
   Assert (Policy.Enabled, "absolute download directory policy");
   Files.Save
     ("File=name=cmVwb3J0LnR4dA==;size=4;inline=0:QUJDRA==",
      Policy, 1_024, Status, Saved_Name, Saved_Length);
   Assert (Status = Files.Save_Ok, "valid iTerm2 download");
   Assert (Saved = "report.txt", "decoded iTerm2 file name");
   Assert (Contents (Directory & "/" & Saved) = "ABCD", "download bytes");

   Files.Save
     ("File=name=cmVwb3J0LnR4dA==;size=4:QUJDRA==",
      Policy, 1_024, Status, Saved_Name, Saved_Length);
   Assert (Status = Files.Save_Ok, "duplicate download succeeds safely");
   Assert (Saved = "report.txt.1", "download never overwrites existing file");

   Files.Save
     ("File=name=Li4vZXZpbA==;size=4:QUJDRA==",
      Policy, 1_024, Status, Saved_Name, Saved_Length);
   Assert (Status = Files.Save_Invalid_Name, "path traversal name rejected");
   Files.Save
     ("File=name=bWlzbWF0Y2g=;size=5:QUJDRA==",
      Policy, 1_024, Status, Saved_Name, Saved_Length);
   Assert
     (Status = Files.Save_Ok and then Contents (Directory & "/mismatch") = "ABCD",
      "declared size remains a non-binding progress hint");
   Files.Save
     ("File=name=dG9vLWxhcmdl;size=4:QUJDRA==",
      Policy, 3, Status, Saved_Name, Saved_Length);
   Assert (Status = Files.Save_Too_Large, "download quota checked");
   Files.Save
     ("File=size=0:",
      Policy, 1_024, Status, Saved_Name, Saved_Length);
   Assert
     (Status = Files.Save_Ok
      and then Saved = "Unnamed file"
      and then Contents (Directory & "/Unnamed file") = "",
      "empty unnamed files follow the protocol default");
   Files.Save
     ("File=name=bm9uY2Fub25pY2Fs:/x==",
      Policy, 1_024, Status, Saved_Name, Saved_Length);
   Assert
     (Status = Files.Save_Invalid_Data,
      "non-canonical Base64 padding bits rejected");

   declare
      R : Terminal.App.Renderer.Renderer;
      T : Terminal.Core.Terminal;
      Renderer_Init : Terminal.App.Renderer.Init_Status;
      Core_Init : Terminal.Core.Initialize_Status;
      Feed_Status : Terminal.Core.Feed_Status;
      Render_Status : Terminal.App.Renderer.Render_Status;
      Event : Terminal.Core.Graphics_Event;
      Outcome : Terminal.Core.Kitty_Graphics_Result;
      Snapshot : Terminal.Core.Render_Snapshot;
   begin
      Terminal.App.Renderer.Initialize_Headless (R, Renderer_Init);
      Assert
        (Renderer_Init = Terminal.App.Renderer.Ok,
         "renderer integration initialize");
      Terminal.App.Renderer.Set_ITerm2_Download_Policy (R, Policy);
      Terminal.Core.Initialize (T, 2, 4, 10, Core_Init);
      Assert (Core_Init = Terminal.Core.Ok, "core integration initialize");
      Terminal.Core.Set_Graphics_Stream_ID (T, 8_1337);
      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC
            & "]1337;File=name=aW50ZWdyYXRpb24uYmlu;size=4;inline=0:QUJDRA=="
            & ASCII.BEL),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "iTerm2 FILE event feed");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Assert (Event.Pending, "iTerm2 FILE event queued");
      Snapshot := Terminal.Core.Snapshot (T);
      Snapshot.Graphics := Event;
      Terminal.App.Renderer.Render (R, Snapshot, Render_Status);
      Terminal.Core.Release (Snapshot);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "renderer accepts iTerm2 FILE download");
      Outcome := Terminal.App.Renderer.Graphics_Result (R, Event);
      Terminal.Core.Complete_Graphics_Event (T, Event, Outcome);
      Terminal.App.Renderer.Commit_Graphics_Events (R);
      Assert
        (Contents (Directory & "/integration.bin") = "ABCD",
         "renderer writes the complete FILE payload");

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC
            & "]1337;MultipartFile=name=bXVsdGlwYXJ0LmRhdA==;size=4"
            & ASCII.BEL
            & ASCII.ESC & "]1337;FilePart=QU" & ASCII.BEL
            & ASCII.ESC & "]1337;FilePart=JDRA==" & ASCII.BEL
            & ASCII.ESC & "]1337;FileEnd" & ASCII.BEL),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "multipart FILE event feed");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Assert (Event.Pending, "multipart FILE event queued");
      Snapshot := Terminal.Core.Snapshot (T);
      Snapshot.Graphics := Event;
      Terminal.App.Renderer.Render (R, Snapshot, Render_Status);
      Terminal.Core.Release (Snapshot);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "renderer accepts multipart FILE download");
      Outcome := Terminal.App.Renderer.Graphics_Result (R, Event);
      Terminal.Core.Complete_Graphics_Event (T, Event, Outcome);
      Assert
        (Contents (Directory & "/multipart.dat") = "ABCD",
         "renderer writes assembled multipart FILE payload");
      Terminal.Core.Finalize (T);
      Terminal.App.Renderer.Finalize (R);
   end;

   Ada.Directories.Delete_Tree (Directory);
exception
   when others =>
      if Ada.Directories.Exists (Directory) then
         Ada.Directories.Delete_Tree (Directory);
      end if;
      raise;
end ITerm2_File_Smoke;
