with AUnit.Assertions;
with Ada.Real_Time;

with Terminal.App.PTY_Write;
with Terminal.App.Queues;
with Terminal.App.Session_Runtime;
with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.PTY.Backend;

procedure Session_Runtime_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.PTY_Write.Write_All_Status;
   use type Terminal.App.Session_Runtime.Runtime_Status;
   use type Terminal.App.Session_Runtime.Start_Status;
   use type Terminal.Common.Bytes.Byte;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Graphics_Stream_ID;
   use type Terminal.Core.Resize_Status;
   use type Terminal.PTY.Backend.Resize_Status;
   use type Ada.Real_Time.Time;

   package Runtime renames Terminal.App.Session_Runtime;

   A : Runtime.Runtime;
   B : Runtime.Runtime;
   Start_Status : Runtime.Start_Status;
   Feed_Status : Terminal.Core.Feed_Status;
   Write_Status : Terminal.App.PTY_Write.Write_All_Status;
   Core_Resize : Terminal.Core.Resize_Status;
   PTY_Resize : Terminal.PTY.Backend.Resize_Status;

   function Chunk_From_String (Text : String) return Terminal.App.Queues.Byte_Chunk
   is
      Result : Terminal.App.Queues.Byte_Chunk := (others => <>);
   begin
      Result.Length := Text'Length;
      for I in Text'Range loop
         Result.Data (I - Text'First + 1) :=
           Terminal.Common.Bytes.Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end Chunk_From_String;

   procedure Drain_For
     (R      : in out Runtime.Runtime;
      Millis : Natural)
   is
      Deadline : constant Ada.Real_Time.Time :=
        Ada.Real_Time.Clock
        + Ada.Real_Time.Milliseconds (Millis);
   begin
      while Ada.Real_Time.Clock < Deadline loop
         Runtime.Poll_Output (R, Feed_Status);
         delay 0.01;
      end loop;
   end Drain_For;
begin
   Runtime.Start (A, 24, 80, 100, Start_Status);
   Assert (Start_Status = Runtime.Ok, "first runtime should start");
   Assert (Runtime.State (A) = Runtime.Active, "first runtime active");
   Assert (Runtime.Is_Alive (A), "first runtime shell alive");
   Assert
     (Runtime.Status_Label (A)'Length <= Runtime.Max_Status_Label_Length,
      "runtime status label bounded");

   Runtime.Start (B, 24, 80, 100, Start_Status);
   Assert (Start_Status = Runtime.Ok, "second runtime should start");
   Assert (Runtime.State (B) = Runtime.Active, "second runtime active");
   Assert (Runtime.Is_Alive (B), "second runtime shell alive");
   Assert
     (Runtime.Graphics_Stream_ID (A) /= 0
      and then Runtime.Graphics_Stream_ID (B) /= 0
      and then Runtime.Graphics_Stream_ID (A) /=
        Runtime.Graphics_Stream_ID (B),
      "active runtimes need distinct graphics stream identities");

   Runtime.Write (A, Chunk_From_String ("printf A-runtime" & ASCII.LF), Write_Status);
   Assert (Write_Status = Terminal.App.PTY_Write.Ok, "write first runtime");
   Runtime.Write (B, Chunk_From_String ("printf B-runtime" & ASCII.LF), Write_Status);
   Assert (Write_Status = Terminal.App.PTY_Write.Ok, "write second runtime");
   Drain_For (A, 100);
   Drain_For (B, 100);

   Runtime.Resize (A, 30, 100, Core_Resize, PTY_Resize);
   Assert (Core_Resize = Terminal.Core.Ok, "runtime core resize");
   Assert (PTY_Resize = Terminal.PTY.Backend.Ok, "runtime pty resize");
   Runtime.Resize (A, 30, 100, Core_Resize, PTY_Resize);
   Assert (Core_Resize = Terminal.Core.Ok, "unchanged runtime core resize");
   Assert (PTY_Resize = Terminal.PTY.Backend.Ok, "unchanged runtime pty resize");

   Runtime.Close (A);
   Runtime.Close (B);
   Assert (Runtime.State (A) = Runtime.Closed, "first runtime closed");
   Assert (Runtime.State (B) = Runtime.Closed, "second runtime closed");
end Session_Runtime_Smoke;
