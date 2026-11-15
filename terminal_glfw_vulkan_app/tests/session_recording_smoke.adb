with Ada.Directories;
with Ada.Text_IO;
with AUnit.Assertions;
with Terminal.App.Queues;
with Terminal.App.Session_Recording;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Session_Recording_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Session_Recording.IO_Status;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Graphics_Stream_ID;

   Recording_Path : constant String := "/tmp/ada_terminal_recording_smoke.arec";
   Transcript_Path : constant String := "/tmp/ada_terminal_recording_smoke.txt";
   Hello : constant String := "hello";
   State : Terminal.App.Session_Recording.State;
   Status : Terminal.App.Session_Recording.IO_Status;
   Chunk : Terminal.App.Queues.Byte_Chunk;
   Replayed : Natural := 0;
   procedure Receive
     (Stream  : Terminal.Core.Graphics_Stream_ID;
      Value   : Terminal.App.Queues.Byte_Chunk) is
   begin
      Assert (Stream = 7, "recording preserves stable stream identity");
      Assert
        (Value.Length = 5
         and then Character'Val (Value.Data (1)) = 'h'
         and then Character'Val (Value.Data (5)) = 'o',
         "recording preserves output bytes");
      Replayed := Replayed + 1;
   end Receive;
   Core : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
   Feed : Terminal.Core.Feed_Status;
begin
   Terminal.App.Session_Recording.Start
     (State, Recording_Path, 2, 8, Status);
   Assert (Status = Terminal.App.Session_Recording.Ok, "recording starts");
   Chunk.Length := 5;
   for I in 1 .. 5 loop
      Chunk.Data (I) := Terminal.Common.Bytes.Byte
        (Character'Pos (Hello (I)));
   end loop;
   Terminal.App.Session_Recording.Record_Output (State, 7, Chunk);
   Terminal.App.Session_Recording.Stop (State, Status);
   Assert (Status = Terminal.App.Session_Recording.Ok, "recording stops");
   Terminal.App.Session_Recording.Replay
     (Recording_Path, Receive'Access, Status);
   Assert
     (Status = Terminal.App.Session_Recording.Ok and then Replayed = 1,
      "recording replays all events");
   declare
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Recording_Path);
      Ada.Text_IO.Put_Line (File, "ADA_TERMINAL_RECORDING 1 2 8");
      Ada.Text_IO.Put_Line (File, "invalid|1|00");
      Ada.Text_IO.Close (File);
   end;
   Terminal.App.Session_Recording.Replay
     (Recording_Path, Receive'Access, Status);
   Assert
     (Status = Terminal.App.Session_Recording.Invalid_Format,
      "recording rejects malformed event metadata");

   Terminal.Core.Initialize (Core, 2, 8, 10, Init);
   Assert (Init = Terminal.Core.Ok, "transcript core initializes");
   Terminal.Core.Feed
     (Core, Chunk.Data (1 .. Chunk.Length), Feed);
   Assert (Feed = Terminal.Core.Ok, "transcript fixture feeds");
   Terminal.App.Session_Recording.Export_Transcript
     (Core, Transcript_Path, Status);
   Assert (Status = Terminal.App.Session_Recording.Ok, "transcript exports");
   declare
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Transcript_Path);
      Assert (Ada.Text_IO.Get_Line (File) = "hello", "transcript contains text");
      Ada.Text_IO.Close (File);
   end;
   Ada.Directories.Delete_File (Recording_Path);
   Ada.Directories.Delete_File (Transcript_Path);
end Session_Recording_Smoke;
