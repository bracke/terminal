with AUnit.Assertions;
with System;

with Terminal.Common;
with Terminal.Common.Bytes;
with Terminal.App.Queues;
with Terminal.App.Render_Model;
with Terminal.App.Renderer;
with Terminal.App.PTY_Write;
with Terminal.Core;
with Terminal.PTY.Backend;

procedure PTY_Core_Integration_Smoke is
   use AUnit.Assertions;
   use type System.Address;
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.App.PTY_Write.Write_All_Status;
   use type Terminal.PTY.Backend.Read_Status;
   use type Terminal.PTY.Backend.Spawn_Status;

   Rows : constant Positive := 10;
   Cols : constant Positive := 80;
   Marker : constant String := "ADA_PTY_CORE_OK";
   Command : constant String :=
     "printf '\033[2J\033[HADA_PTY_CORE_OK\n'; exit" & Character'Val (13);

   T : Terminal.Core.Terminal;
   Init_Status : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;
   S : Terminal.PTY.Backend.Session;
   Spawn_Status : Terminal.PTY.Backend.Spawn_Status;
   Write_Status : Terminal.App.PTY_Write.Write_All_Status;
   R : Terminal.App.Renderer.Renderer;
   Renderer_Init : Terminal.App.Renderer.Init_Status;
   Renderer_Status : Terminal.App.Renderer.Render_Status;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   function To_Chunk (Text : String) return Terminal.App.Queues.Byte_Chunk is
      Result : Terminal.App.Queues.Byte_Chunk;
      Bytes  : constant Byte_Array := To_Bytes (Text);
   begin
      Result := (others => <>);
      Result.Length := Bytes'Length;
      Result.Data (1 .. Bytes'Length) := Bytes;
      return Result;
   end To_Chunk;

   function Marker_At_Top_Left return Boolean is
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Match : Boolean := True;
   begin
      if Snap.Rows < 1 or else Snap.Cols < Marker'Length then
         Terminal.Core.Release (Snap);
         return False;
      end if;

      for I in Marker'Range loop
         if Terminal.Core.Cell_At (Snap, 1, I - Marker'First + 1).Text.Code_Point /=
           Terminal.Common.Code_Point (Character'Pos (Marker (I)))
         then
            Match := False;
            exit;
         end if;
      end loop;

      Terminal.Core.Release (Snap);
      return Match;
   end Marker_At_Top_Left;

   procedure Drain_For_Marker (Found : out Boolean) is
      Buffer : Byte_Array (1 .. 4096);
      Last : Natural := 0;
      Read_Status : Terminal.PTY.Backend.Read_Status;
   begin
      Found := False;
      for Attempt in 1 .. 300 loop
         Terminal.PTY.Backend.Read (S, Buffer, Last, Read_Status);
         case Read_Status is
            when Terminal.PTY.Backend.Ok =>
               if Last > 0 then
                  Terminal.Core.Feed (T, Buffer (1 .. Last), Feed_Status);
                  Assert
                    (Feed_Status = Terminal.Core.Ok
                     or else Feed_Status = Terminal.Core.Parser_Recovered,
                     "core feed should accept shell output");
               end if;
            when Terminal.PTY.Backend.Would_Block
               | Terminal.PTY.Backend.Interrupted =>
               delay 0.01;
            when Terminal.PTY.Backend.End_Of_File
               | Terminal.PTY.Backend.Failed
               | Terminal.PTY.Backend.Session_Closed =>
               exit;
         end case;

         if Marker_At_Top_Left then
            Found := True;
            exit;
         end if;
      end loop;
   end Drain_For_Marker;
begin
   Assert
     (Terminal.App.PTY_Write.Status_Label (Terminal.App.PTY_Write.Ok) =
      "PTY write complete",
      "ok write status label");
   Assert
     (Terminal.App.PTY_Write.Status_Label
        (Terminal.App.PTY_Write.Incomplete) =
      "PTY write incomplete; retry pending",
      "incomplete write status label");
   Assert
     (Terminal.App.PTY_Write.Status_Label (Terminal.App.PTY_Write.Failed) =
      "PTY write failed",
      "failed write status label");
   Assert
     (Terminal.App.PTY_Write.Status_Label
        (Terminal.App.PTY_Write.Session_Closed) =
      "PTY write skipped; session closed",
      "closed write status label");
   Assert
     (Terminal.App.PTY_Write.Status_Label
        (Terminal.App.PTY_Write.Incomplete)'Length <=
      Terminal.App.PTY_Write.Max_Status_Label_Length,
      "write status label should be bounded");

   Terminal.Core.Initialize (T, Rows, Cols, 100, Init_Status);
   Assert (Init_Status = Terminal.Core.Ok, "core initialize failed");

   Terminal.PTY.Backend.Spawn_Default_Shell (S, Rows, Cols, Spawn_Status);
   Assert (Spawn_Status = Terminal.PTY.Backend.Ok, "pty spawn failed");

   declare
      Data : constant Terminal.App.Queues.Byte_Chunk := To_Chunk (Command);
      Found : Boolean;
   begin
      Terminal.App.PTY_Write.Write_All (S, Data, Write_Status);
      Assert (Write_Status = Terminal.App.PTY_Write.Ok, "pty write failed");

      Drain_For_Marker (Found);
      Assert (Found, "shell output marker should reach core top-left");
   end;

   Terminal.App.Renderer.Initialize_Headless (R, Renderer_Init);
   Assert
     (Renderer_Init = Terminal.App.Renderer.Ok,
      "headless renderer initialize failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Renderer_Status);
      Terminal.Core.Release (Snap);
   end;

   Assert
     (Renderer_Status = Terminal.App.Renderer.Ok,
      "headless renderer should render PTY-fed core snapshot");

   declare
      Diag : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
   begin
      Assert (Diag.Last_Glyph_Count >= Marker'Length, "glyph command count");
      Assert (Diag.Last_Vertex_Count >= Marker'Length * 6, "vertex count");
      Assert (Frame.Atlas_Width > 0, "atlas width should be carried");
      Assert (Frame.Atlas_Height > 0, "atlas height should be carried");
      Assert (Frame.Atlas_Bytes = Frame.Atlas_Width * Frame.Atlas_Height,
              "atlas byte count");
      Assert (Frame.Atlas_Pixels /= System.Null_Address, "atlas pixels");
   end;

   Terminal.App.Renderer.Finalize (R);
   Terminal.PTY.Backend.Close (S);
end PTY_Core_Integration_Smoke;
