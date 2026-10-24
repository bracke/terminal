with Ada.Environment_Variables;
with Ada.Real_Time;
with Ada.Text_IO;
with AUnit.Assertions;
with Interfaces;

with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.App.Render_Model;
with Terminal.App.Renderer;
with Terminal.App.Renderer.Testing;

procedure Graphics_Replacement_Benchmark_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Ada.Real_Time.Time;
   use type Interfaces.Unsigned_64;

   function Requested_Iterations return Positive is
   begin
      if not Ada.Environment_Variables.Exists
        ("TERMINAL_GRAPHICS_REPLACEMENT_ITERATIONS")
      then
         return 1_000;
      end if;
      return Positive'Min
        (1_000_000,
         Positive'Value
           (Ada.Environment_Variables.Value
              ("TERMINAL_GRAPHICS_REPLACEMENT_ITERATIONS")));
   exception
      when others =>
         return 1_000;
   end Requested_Iterations;

   Iterations : constant Positive := Requested_Iterations;
   Stream_ID  : constant Terminal.Core.Graphics_Stream_ID := 7_001;

   R : Terminal.App.Renderer.Renderer;
   T : Terminal.Core.Terminal;
   Renderer_Init : Terminal.App.Renderer.Init_Status;
   Core_Init : Terminal.Core.Initialize_Status;
   Feed_Result : Terminal.Core.Feed_Status;
   Render_Result : Terminal.App.Renderer.Render_Status;
   First_Image_Capacity : Natural := 0;
   First_Rectangle_Capacity : Natural := 0;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   procedure Replace (Payload : String) is
      Event : Terminal.Core.Graphics_Event;
      Result : Terminal.Core.Kitty_Graphics_Result;
      Snapshot : Terminal.Core.Render_Snapshot;
      Command : constant String :=
        ASCII.ESC
        & "_Gf=32,a=T,i=600,p=1,q=2,C=1,s=1,v=1,c=1,r=1;"
        & Payload & ASCII.ESC & "\";
   begin
      Terminal.Core.Feed (T, To_Bytes (Command), Feed_Result);
      Assert (Feed_Result = Terminal.Core.Ok, "replacement feed");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Assert (Event.Pending, "replacement event");

      Snapshot := Terminal.Core.Snapshot (T);
      Snapshot.Graphics := Event;
      Terminal.App.Renderer.Render (R, Snapshot, Render_Result);
      Terminal.Core.Release (Snapshot);
      Assert (Render_Result = Terminal.App.Renderer.Ok, "replacement render");
      declare
         D : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
      begin
         if First_Image_Capacity = 0 then
            First_Image_Capacity := D.Image_Command_Capacity;
            First_Rectangle_Capacity := D.Rectangle_Command_Capacity;
         else
            Assert
              (D.Image_Command_Capacity = First_Image_Capacity
               and then
                 D.Rectangle_Command_Capacity = First_Rectangle_Capacity,
               "equal-sized replacement frames retain command storage");
         end if;
      end;

      Result := Terminal.App.Renderer.Graphics_Result (R, Event);
      Terminal.Core.Complete_Graphics_Event (T, Event, Result);
      Terminal.App.Renderer.Commit_Graphics_Events (R);
   end Replace;

   Started : Ada.Real_Time.Time;
   Finished : Ada.Real_Time.Time;
begin
   Terminal.App.Renderer.Initialize_Headless (R, Renderer_Init);
   Assert (Renderer_Init = Terminal.App.Renderer.Ok, "renderer initialize");
   Terminal.Core.Initialize (T, 2, 4, 10, Core_Init);
   Assert (Core_Init = Terminal.Core.Ok, "core initialize");
   Terminal.Core.Set_Graphics_Stream_ID (T, Stream_ID);

   Started := Ada.Real_Time.Clock;
   for I in 1 .. Iterations loop
      Replace ((if I mod 2 = 0 then "/wAA/w==" else "AP8A/w=="));
   end loop;
   Finished := Ada.Real_Time.Clock;

   declare
      D : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
      Elapsed : constant Duration := Ada.Real_Time.To_Duration
        (Finished - Started);
      Rate : constant Natural :=
        (if Elapsed <= 0.0
         then Iterations
         else Natural (Duration (Iterations) / Elapsed));
   begin
      Assert
        (D.Image_Object_Count = 1
         and then D.Placement_Count = 1
         and then D.Image_Object_Bytes = 4,
         "rapid replacement keeps one bounded object and placement");
      Assert
        (D.Image_Install_Count = Interfaces.Unsigned_64 (Iterations),
         "every replacement is accounted for");
      Assert (Frame.Image_Count = 1, "only the newest image remains visible");
      Ada.Text_IO.Put_Line
        ("graphics replacement benchmark:"
         & Positive'Image (Iterations) & " updates in"
         & Duration'Image (Elapsed) & " s ("
         & Natural'Image (Rate) & " updates/s)");
   end;

   Terminal.App.Renderer.Release_Graphics_Stream (R, Stream_ID);
   Terminal.Core.Finalize (T);
end Graphics_Replacement_Benchmark_Smoke;
